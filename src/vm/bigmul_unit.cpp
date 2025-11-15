#include <algorithm>
#include <cstdint>
#include <cmath>
#include <iostream>
#include "vm/bigmul_unit.h"
#pragma GCC diagnostic ignored "-Wpedantic"


namespace bigmul_unit {
    bool bigmul_done_ = true;
    bool ldbm_done_ = true;
    size_t ldbm_offset = 0;
    size_t bigmul_prog = 0;
    size_t write_offset = 0;
    bool write_done = true;
    uint64_t base_addr_A = 0;
    uint64_t base_addr_B = 0;
    uint64_t base_addr_res = 0;
    uint64_t cacheA[64] = {0};
    uint64_t cacheB[64] = {0};
    uint64_t resultCache[128] = {0};

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

    struct DelayItem {
        MulBatch mb;    // value to retire to accumulator
        int      remain; // number of CSA "stages" still to wait
        bool     valid;
    };

    static GenBatch  pGEN;
    static LoadBatch pLOAD;
    static MulBatch  pMUL;
    static DelayItem dq[5];
    static int dq_len;

    static uint64_t acc0, acc1, acc2;

    static int pending_depth_for_pMUL;

    static inline GenBatch  make_empty_gen()  { GenBatch b{}; b.count=0; b.valid=false; return b; }
    static inline LoadBatch make_empty_load() { LoadBatch b{}; b.count=0; b.valid=false; return b; }
    static inline MulBatch  make_empty_mul()  { return MulBatch{0,0,0,false}; }
    static inline DelayItem make_empty_item() { return DelayItem{make_empty_mul(), 0, false}; }

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

    static inline int csa_depth_for_count(int count) {
        if (count <= 1) return 0;
        double lg = std::log2((double)count);
        int d = (int)std::ceil(lg) - 1;
        if (d < 0) d = 0;
        if (d > 4) d = 4; // hard cap (we only keep a tiny queue)
        return d;
    }

    static inline void dq_pop_front() {
        if (dq_len == 0) return;
        for (int i = 1; i < dq_len; ++i) dq[i-1] = dq[i];
        dq[--dq_len] = make_empty_item();
    }

    static inline void dq_push(const MulBatch &mb, int remain) {
        if (remain <= 0) return;        // should not queue zero-remaining
        if (dq_len >= 5) return;        // protect against overflow (shouldn’t happen)
        dq[dq_len++] = DelayItem{mb, remain, true};
    }

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
        for (int i=0;i<5;++i) dq[i] = make_empty_item();
        dq_len = 0;

        pending_depth_for_pMUL = 0;
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
        for (int i=0;i<5;++i) dq[i] = make_empty_item();
        dq_len = 0;
        // Carry-in for s=0 is 0
        acc_clear();

        // Mark bigmul running
        // ldbm_offset = 0;
        // write_offset = 0;
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

         // If nothing to do, return
    if (bigmul_done_) return;

    // First call after BIGMUL start
    if (bigmul_prog == 0) {
        start_bigmul();
    }

    // ---- Single-cycle GEN + LOAD + MUL + CSA for this cycle ----
    // We process up to 25 (i,j) pairs on the current diagonal s_diag
    const int BATCH = 25;
    int processed = 0;

    // Local 192-bit batch sum (like your old pMUL + CSA tree)
    uint64_t b0 = 0;  // low 64 bits
    uint64_t b1 = 0;  // middle 64 bits
    uint64_t b2 = 0;  // high 64 bits

    // Generate indices (GEN), load from cache (LOAD), multiply and sum (MUL+CSA)
    while (processed < BATCH && k_iter <= i_max) {
        int ii = k_iter;
        int jj = s_diag - ii;
        ++k_iter;
        ++processed;

        // LOAD
        uint64_t Ai = cacheA[ii];
        uint64_t Bj = cacheB[jj];

        // MUL: 64x64 -> 128
        __uint128_t p = ( (__uint128_t)Ai * (__uint128_t)Bj );
        uint64_t lo = (uint64_t)p;
        uint64_t hi = (uint64_t)(p >> 64);

        // Local 192-bit sum b2:b1:b0 += (hi:lo)
        unsigned __int128 t0 = (unsigned __int128)b0 + lo;
        b0 = (uint64_t)t0;
        uint64_t c0 = (uint64_t)(t0 >> 64);

        unsigned __int128 t1 = (unsigned __int128)b1 + hi + c0;
        b1 = (uint64_t)t1;
        uint64_t c1 = (uint64_t)(t1 >> 64);

        b2 += c1;
    }

    // Add this batch’s 192-bit sum into the running diagonal accumulator
    if (processed > 0) {
        acc_add_u192(b0, b1, b2);
    }

    // ---- Check if we finished this diagonal ----
    if (k_iter > i_max) {
        // All partial products for diagonal s_diag are accumulated in acc0/1/2.
        // Emit the low 64 bits to resultCache[s_diag], then shift accumulator.
        resultCache[s_diag] = acc_low64();
        acc_shr_64();  // carry into next word

        // Last diagonal?
        if (s_diag == 126) {
            // Final word (s=127) from remaining accumulator
            resultCache[127] = acc_low64();

            // Mark compute phase done; VM will now enter writeback phase
            bigmul_prog = 0;
            write_done  = false;
            return;
        }

        // Move to next diagonal s_diag + 1
        ++s_diag;
        i_min = (s_diag > 63) ? (s_diag - 63) : 0;
        i_max = (s_diag < 63) ?  s_diag       : 63;
        k_iter = i_min;

        // We KEEP acc0/1/2 (already shifted) as carry for next diagonal.
        // No need to clear acc here.
    }
        // //std::cout << "[BIGMUL EXEC] prog=" << bigmul_prog << std::endl;
        // if (bigmul_done_) return;

        // if(bigmul_prog == 0)start_bigmul();

        // if (dq_len > 0 && dq[0].valid && dq[0].remain == 0) {
        //     const MulBatch& mb = dq[0].mb;
        //     acc_add_u192(mb.lo, mb.hi, mb.hi2);
        //     dq_pop_front();
        // }

        // for (int i = 0; i < dq_len; ++i) {
        //     if (dq[i].valid && dq[i].remain > 0)
        //         dq[i].remain -= 1;
        // }

        // if (pMUL.valid) {
        //     if (pending_depth_for_pMUL <= 0) {
        //         // No CSA latency needed: retire immediately
        //         acc_add_u192(pMUL.lo, pMUL.hi, pMUL.hi2);
        //     } else {
        //         // Queue with countdown = depth
        //         dq_push(pMUL, pending_depth_for_pMUL);
        //     }
        // }

        // pMUL = make_empty_mul();
        // pending_depth_for_pMUL = 0;
        // if (pLOAD.valid) {
        //     uint64_t b0=0, b1=0, b2=0; // 192-bit local sum
        //     for (int t=0; t<pLOAD.count; ++t) {
        //         // for(int l=0; l<pLOAD.count;++l){
        //         // NOTE: pairwise product only (NO nested loop!)
        //         __uint128_t p = ( (__uint128_t)pLOAD.Ai[t] * (__uint128_t)pLOAD.Bj[t] );
        //         uint64_t lo = (uint64_t)p;
        //         uint64_t hi = (uint64_t)(p >> 64);

        //         unsigned __int128 t0 = (unsigned __int128)b0 + lo;
        //         b0 = (uint64_t)t0;
        //         uint64_t c0 = (uint64_t)(t0 >> 64);

        //         unsigned __int128 t1 = (unsigned __int128)b1 + hi + c0;
        //         b1 = (uint64_t)t1;
        //         uint64_t c1 = (uint64_t)(t1 >> 64);

        //         b2 += c1;
        //         // }
        //     }
        //     pMUL.lo = b0;
        //     pMUL.hi = b1;
        //     pMUL.hi2 = b2;
        //     pMUL.valid = (pLOAD.count > 0);

        //     pending_depth_for_pMUL = csa_depth_for_count(pLOAD.count);
        // }

        // pLOAD = make_empty_load();
        // if (pGEN.valid) {
        //     pLOAD.count = pGEN.count;
        //     for (int t=0; t<pGEN.count; ++t) {
        //         pLOAD.Ai[t] = cacheA[pGEN.i[t]];
        //         pLOAD.Bj[t] = cacheB[pGEN.j[t]];
        //     }
        //     pLOAD.valid = (pGEN.count > 0);
        // }

        // pGEN = make_empty_gen();
        // if (!gen_done_this_diag) {
        //     int produced = 0;
        //     for (; produced < 25 && k_iter <= i_max; ++k_iter, ++produced) {
        //         int ii = k_iter;
        //         int jj = s_diag - ii;
        //         pGEN.i[produced] = ii;
        //         pGEN.j[produced] = jj;
        //     }
        //     pGEN.count = produced;
        //     pGEN.valid = (produced > 0);

        //     if (k_iter > i_max) {
        //         gen_done_this_diag = true; // no more GEN for this diagonal
        //     }
        // }

        // const bool pipe_empty = !pGEN.valid && !pLOAD.valid && !pMUL.valid && (dq_len == 0);

        // if (gen_done_this_diag && pipe_empty) {
        //     resultCache[s_diag] = acc_low64();
        //     acc_shr_64();

        //     if (s_diag == 126) {
        //         resultCache[127] = acc_low64();
        //         bigmul_prog  = 0;
        //         write_done   = false;
        //         //std::cout << "[BIGMUL DONE] finishing compute phase" << std::endl;
        //         return;
        //     }

        //     s_diag++;
        //     i_min = (s_diag > 63) ? (s_diag - 63) : 0;
        //     i_max = (s_diag < 63) ?  s_diag       : 63;
        //     k_iter = i_min;
        //     pGEN  = make_empty_gen();
        //     pLOAD = make_empty_load();
        //     pMUL  = make_empty_mul();
        //     for (int i=0;i<8;++i) dq[i] = make_empty_item();
        //     dq_len = 0;

        //     gen_done_this_diag = false;
        // }

    }

    // std::size_t getResultSize(){

    // }

    // void invalidateCaches(){

    // }

    BigmulState snapshot() {
    BigmulState s;
    s.bigmul_done   = bigmul_done_;
    s.ldbm_done     = ldbm_done_;
    s.write_done    = write_done;
    s.ldbm_offset   = ldbm_offset;
    s.bigmul_prog   = bigmul_prog;
    s.write_offset  = write_offset;
    s.base_addr_A   = base_addr_A;
    s.base_addr_B   = base_addr_B;
    s.base_addr_res = base_addr_res;

    for (int i=0;i<64;i++){
        s.cacheA[i] = cacheA[i];
        s.cacheB[i] = cacheB[i];
    }
    for (int i=0;i<128;i++){
        s.resultCache[i] = resultCache[i];
    }

    return s;
}

void restore(const BigmulState &s) {
    bigmul_done_   = s.bigmul_done;
    ldbm_done_     = s.ldbm_done;
    write_done     = s.write_done;
    ldbm_offset    = s.ldbm_offset;
    bigmul_prog    = s.bigmul_prog;
    write_offset   = s.write_offset;
    base_addr_A    = s.base_addr_A;
    base_addr_B    = s.base_addr_B;
    base_addr_res  = s.base_addr_res;

    for (int i=0;i<64;i++){
        cacheA[i] = s.cacheA[i];
        cacheB[i] = s.cacheB[i];
    }
    for (int i=0;i<128;i++){
        resultCache[i] = s.resultCache[i];
    }
    // We DO NOT restore pipeline.
    // Step() always finishes a whole LDBM/BIGMUL and reset() clears caches.
}
}