#include "vm/bigmul_unit.h"

namespace bigmul_unit {
    bool bigmul_done_;
    bool ldbm_done_;
    uint8_t cacheA[512];
    uint8_t cacheB[512];
    uint8_t resultCache[1024];

    void reset(){
        bigmul_done_ = false;
        ldbm_done_ = false;
    }

    bool GetBigmulDone(){
        return bigmul_done_;
    }

    bool GetLdbmDone(){
        return ldbm_done_;
    }

    void loadcache(const std::vector<uint8_t>& bufA, const std::vector<uint8_t>& bufB){

    }

    void executeBigmul(){

    }

    std::size_t getResultSize(){

    }

    void invalidateCaches(){

    }
}