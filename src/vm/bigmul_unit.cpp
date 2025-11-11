#include <algorithm>
#include <cstdint>
#include "vm/bigmul_unit.h"

namespace bigmul_unit {
    bool bigmul_done_;
    bool ldbm_done_;
    size_t ldbm_offset;
    size_t bigmul_prog;
    size_t write_offset;
    bool write_done;
    uint64_t base_addr_A;
    uint64_t base_addr_B;
    uint64_t base_addr_res;
    uint64_t cacheA[64];
    uint64_t cacheB[64];
    uint64_t resultCache[128];

    static int s_diag;          // current diagonal 0..126
    static int i_min, i_max;    // bounds for s_diag
    static int k_iter;          // next i to generate in this diagonal
    static bool gen_done_this_diag;

    struct GenBatch {
        int  count;             // 0..5
        int  i[25];
        int  j[25];
        bool valid;
    };

    struct LoadBatch {
        int       count;        // 0..5
        uint64_t  Ai[25];
        uint64_t  Bj[25];
        bool      valid;
    };

    struct MulBatch {
        uint64_t lo;    // low 64 bits of batch sum
        uint64_t hi;    // high 64 bits of batch sum
        uint64_t hi2;
        bool     valid;
    };

    static GenBatch  pGEN;
    static LoadBatch pLOAD;
    static MulBatch  pMUL;
    static MulBatch  pCSA1, pCSA2, pCSA3, pCSA4, pCSA5, pCSA6, pCSA7;

    static uint64_t acc0, acc1, acc2;

    static inline GenBatch  make_empty_gen()  { GenBatch b{}; b.count=0; b.valid=false; return b; }
    static inline LoadBatch make_empty_load() { LoadBatch b{}; b.count=0; b.valid=false; return b; }
    static inline MulBatch  make_empty_mul()  { return MulBatch{0,0,0,false}; }

    static inline void acc_clear() { acc0 = acc1 = acc2 = 0; }

    static inline void acc_add_u128(uint64_t lo, uint64_t hi) {
        unsigned __int128 t0 = (unsigned __int128)acc0 + lo;
        acc0 = (uint64_t)t0;
        uint64_t c0 = (uint64_t)(t0 >> 64);

        unsigned __int128 t1 = (unsigned __int128)acc1 + hi + c0;
        acc1 = (uint64_t)t1;
        uint64_t c1 = (uint64_t)(t1 >> 64);

        acc2 += c1;
    }

    static inline void acc_add_u192(uint64_t lo, uint64_t hi, uint64_t hi2) {
        acc_add_u128(lo, hi);
        acc2 += hi2;
    }

    static inline void acc_shr_64() {
        acc0 = acc1;
        acc1 = acc2;
        acc2 = 0;
    }

    static inline uint64_t acc_low64() { return acc0; }


    void reset(){
        ldbm_done_ = true;
        ldbm_offset = 0;

        bigmul_done_ = true;
        bigmul_prog = 0;

        write_done = true;
        write_offset = 0;

        base_addr_A = 0;
        base_addr_B = 0;
        base_addr_res = 0;

        std::fill(std::begin(cacheA), std::end(cacheA), 0);
        std::fill(std::begin(cacheB), std::end(cacheB), 0);
        std::fill(std::begin(resultCache), std::end(resultCache), 0);

        s_diag = 0; i_min = 0; i_max = 0; k_iter = 0;
        gen_done_this_diag = false;

        pGEN  = make_empty_gen();
        pLOAD = make_empty_load();
        pMUL  = make_empty_mul();
        pCSA1 = pCSA2 = pCSA3 = pCSA4 = pCSA5 = pCSA6 = pCSA7 = make_empty_mul();

        acc_clear();
    }

    void start_bigmul(){
        // Initialize first diagonal
        s_diag = 0;
        i_min  = 0;
        i_max  = 0;        // for s=0, only (0,0)
        k_iter = i_min;
        gen_done_this_diag = false;

        // Clear pipeline
        pGEN  = make_empty_gen();
        pLOAD = make_empty_load();
        pMUL  = make_empty_mul();
        pCSA1 = pCSA2 = pCSA3 = pCSA4 = pCSA5 = pCSA6 = pCSA7 = make_empty_mul();

        // Carry-in for s=0 is 0
        acc_clear();

        // Mark bigmul running
        bigmul_done_ = false;
        bigmul_prog  = 1; // just a “running” marker you already had
        write_done   = true;
    }

    bool GetBigmulDone(){
        return bigmul_done_;
    }

    bool GetLdbmDone(){
        return ldbm_done_;
    }

    bool GetWriteDone(){
        return write_done;
    }

    // void loadcache(const std::vector<uint8_t>& bufA, const std::vector<uint8_t>& bufB){

    // }

    void executeBigmul(){
        if (bigmul_done_) return;

        if(bigmul_prog == 0)start_bigmul();

        if (pCSA7.valid) {
            acc_add_u192(pCSA7.lo, pCSA7.hi,pCSA7.hi2);
        }

        pCSA7 = pCSA6;
        pCSA6 = pCSA5;
        pCSA5 = pCSA4;
        pCSA4 = pCSA3;
        pCSA3 = pCSA2;
        pCSA2 = pCSA1;

        pCSA1 = make_empty_mul();
        if (pMUL.valid) {
            pCSA1 = pMUL;
            pCSA1.valid = true;
        }

        pMUL = make_empty_mul();
        if (pLOAD.valid) {
            uint64_t b0=0, b1=0, b2=0; // 192-bit local sum
            for (int t=0; t<pLOAD.count; ++t) {
                // NOTE: pairwise product only (NO nested loop!)
                __uint128_t p = ( (__uint128_t)pLOAD.Ai[t] * (__uint128_t)pLOAD.Bj[t] );
                uint64_t lo = (uint64_t)p;
                uint64_t hi = (uint64_t)(p >> 64);

                unsigned __int128 t0 = (unsigned __int128)b0 + lo;
                b0 = (uint64_t)t0;
                uint64_t c0 = (uint64_t)(t0 >> 64);

                unsigned __int128 t1 = (unsigned __int128)b1 + hi + c0;
                b1 = (uint64_t)t1;
                uint64_t c1 = (uint64_t)(t1 >> 64);

                b2 += c1;
            }
            pMUL.lo = b0;
            pMUL.hi = b1;
            pMUL.hi2 = b2;
            pMUL.valid = (pLOAD.count > 0);
        }

        pLOAD = make_empty_load();
        if (pGEN.valid) {
            pLOAD.count = pGEN.count;
            for (int t=0; t<pGEN.count; ++t) {
                pLOAD.Ai[t] = cacheA[pGEN.i[t]];
                pLOAD.Bj[t] = cacheB[pGEN.j[t]];
            }
            pLOAD.valid = (pGEN.count > 0);
        }

        pGEN = make_empty_gen();
        if (!gen_done_this_diag) {
            int produced = 0;
            for (; produced < 25 && k_iter <= i_max; ++k_iter, ++produced) {
                int ii = k_iter;
                int jj = s_diag - ii;
                pGEN.i[produced] = ii;
                pGEN.j[produced] = jj;
            }
            pGEN.count = produced;
            pGEN.valid = (produced > 0);

            if (k_iter > i_max) {
                gen_done_this_diag = true; // no more GEN for this diagonal
            }
        }

        const bool pipe_empty = 
            !pGEN.valid && !pLOAD.valid && !pMUL.valid &&
            !pCSA1.valid && !pCSA2.valid && !pCSA3.valid &&
            !pCSA4.valid && !pCSA5.valid && !pCSA6.valid && !pCSA7.valid;

        if (gen_done_this_diag && pipe_empty) {
            resultCache[s_diag] = acc_low64();
            acc_shr_64();

            if (s_diag == 126) {
                resultCache[127] = acc_low64();
                bigmul_prog  = 0;
                write_done   = false;
                return;
            }

            s_diag++;
            i_min = (s_diag > 63) ? (s_diag - 63) : 0;
            i_max = (s_diag < 63) ?  s_diag        : 63;
            k_iter = i_min;
            pGEN  = make_empty_gen();
            pLOAD = make_empty_load();
            pMUL  = make_empty_mul();
            pCSA1 = pCSA2 = pCSA3 = pCSA4 = pCSA5 = pCSA6 = pCSA7 = make_empty_mul();

            gen_done_this_diag = false;
        }
    }

    // std::size_t getResultSize(){

    // }

    // void invalidateCaches(){

    // }
}