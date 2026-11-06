#include "../SpoofyDiagnosticGuard.h"
#include "../SpoofyCategoryBudget.hpp"
#include <atomic>
#include <cassert>
#include <thread>
#include <vector>
#include <cstdio>

// Simulate a diagnostic operation that synchronously re-enters the hook.
// This deliberately exercises the worst case without an actual iOS process.
static void simulateHook(SpoofyCategoryBudget &budget, unsigned &depth, unsigned &updates) {
    assert(++depth <= 3);
    unsigned bit = SpoofyGuardIsActive() ? 1 : 2;
    if (budget.claim(bit)) {
        ++updates;
        SpoofyGuardEnter();
        simulateHook(budget, depth, updates);
        assert(SpoofyGuardLeave());
    }
    --depth;
}

int main() {
    assert(!SpoofyGuardIsActive() && !SpoofyGuardLeave());
    SpoofyGuardEnter(); SpoofyGuardEnter();
    assert(SpoofyGuardIsActive() && SpoofyGuardLeave() && SpoofyGuardIsActive());
    std::thread worker([] {
        assert(!SpoofyGuardIsActive());
        SpoofyGuardEnter(); assert(SpoofyGuardIsActive()); assert(SpoofyGuardLeave());
    });
    worker.join();
    assert(SpoofyGuardIsActive() && SpoofyGuardLeave() && !SpoofyGuardIsActive());
    SpoofyCategoryBudget budget;
    assert(!budget.claim(0) && !budget.claim(3) && !budget.claim(64));
    std::atomic<unsigned> successes{0};
    std::vector<std::thread> threads;
    for (unsigned n = 0; n < 8; ++n) threads.emplace_back([&] {
        for (unsigned i = 0; i < 10000; ++i)
            for (unsigned bit = 1; bit <= 32; bit <<= 1)
                if (budget.claim(bit)) ++successes;
    });
    for (auto &thread : threads) thread.join();
    assert(successes == 6);
    SpoofyCategoryBudget recursiveBudget;
    unsigned depth = 0, updates = 0;
    simulateHook(recursiveBudget, depth, updates);
    assert(depth == 0 && updates == 2 && !SpoofyGuardIsActive());
    puts("Diagnostic context and six-update concurrency bound passed");
}
