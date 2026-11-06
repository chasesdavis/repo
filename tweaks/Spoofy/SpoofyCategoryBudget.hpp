#ifndef SPOOFY_CATEGORY_BUDGET_HPP
#define SPOOFY_CATEGORY_BUDGET_HPP
#include <atomic>
// Six fixed flags; at most one queued update per flag per process.
class SpoofyCategoryBudget {
    std::atomic<unsigned> seen{0};
public:
    bool claim(unsigned bit) {
        if (!bit || (bit & (bit - 1)) || (bit & ~63u)) return false;
        return (seen.fetch_or(bit, std::memory_order_relaxed) & bit) == 0;
    }
};
#endif
