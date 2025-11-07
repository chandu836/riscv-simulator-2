#ifndef BIGMUL_UNIT_H
#define BIGMUL_UNIT_H

#include <vector>
#include <cstddef>
#include <cstdint>

namespace bigmul_unit {
    extern bool bigmul_done_;
    extern bool ldbm_done_;
    extern uint8_t cacheA[512];
    extern uint8_t cacheB[512];
    extern uint8_t resultCache[1024];

    void reset();
    [[nodiscard]] bool GetBigmulDone();
    [[nodiscard]] bool GetLdbmDone();

    void loadcache(const std::vector<uint8_t>& bufA, const std::vector<uint8_t>& bufB);
    void executeBigmul();
    [[nodiscard]] std::size_t getResultSize();
    void invalidateCaches();
    
}
#endif // BIGMUL_UNIT_H