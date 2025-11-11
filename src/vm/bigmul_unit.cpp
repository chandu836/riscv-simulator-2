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

    }

    // std::size_t getResultSize(){

    // }

    // void invalidateCaches(){

    // }
}