#ifndef BIGMUL_UNIT_H
#define BIGMUL_UNIT_H

#include <vector>
#include <cstddef>
#include <cstdint>

namespace bigmul_unit {
    extern bool bigmul_done_;
    extern bool ldbm_done_;
    extern size_t ldbm_offset;
    extern size_t bigmul_prog;
    extern size_t write_offset;
    extern bool write_done;
    extern uint64_t base_addr_A;
    extern uint64_t base_addr_B;
    extern int64_t base_addr_res;
    extern uint64_t cacheA[64];
    extern uint64_t cacheB[64];
    extern uint64_t resultCache[128];

    void reset();
    [[nodiscard]] bool GetBigmulDone();
    [[nodiscard]] bool GetLdbmDone();
    [[nodiscard]] bool GetWriteDone()

    //void loadcache(const std::vector<uint8_t>& bufA, const std::vector<uint8_t>& bufB);
    void executeBigmul();
    // [[nodiscard]] std::size_t getResultSize();
    //void invalidateCaches();

}
#endif // BIGMUL_UNIT_H