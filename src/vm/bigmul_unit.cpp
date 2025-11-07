#include "vm/bigmul_unit.h"

namespace bigmul_unit {
    bool bigmul_done_;
    bool ldbm_done_;
    size_t ldbm_offset;
    uint64_t base_addr_A;
    uint64_t base_addr_B;
    uint8_t cacheA[512];
    uint8_t cacheB[512];
    uint8_t resultCache[1024];

    void reset(){
        ldbm_done_ = true;
        ldbm_offset = 0;

        bigmul_done_ = true;

        base_addr_A = 0;
        base_addr_B = 0;

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

    // void loadcache(const std::vector<uint8_t>& bufA, const std::vector<uint8_t>& bufB){

    // }

    void executeBigmul(){

    }

    std::size_t getResultSize(){

    }

    // void invalidateCaches(){

    // }
}