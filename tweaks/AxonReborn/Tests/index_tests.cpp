#include "../Core/NotificationIndex.hpp"
#include <cassert>
#include <iostream>
#include <random>

int main() {
    using namespace axon;
    NotificationIndex index;
    assert(!index.upsert({{"", "1"}, 1}));
    assert(!index.upsert({{"app", ""}, 1}));
    index.upsert({{"mail", "same-id"}, 10});
    index.upsert({{"messages", "same-id"}, 20});
    index.upsert({{"mail", "same-id"}, 30});
    assert(index.size() == 2); // updates replace; IDs are scoped by app
    assert(index.groups()[0].app == "mail");
    index.select("mail");
    assert(index.visibleKeys().size() == 1);
    assert(!index.includes({"messages", "new"}));
    index.upsert({{"messages", "new"}, 40});
    assert(index.visibleKeys().size() == 1); // background arrival preserves selection
    assert(index.groups(Sort::Count)[0].count == 2);
    assert(index.erase({"mail", "same-id"}));
    assert(!index.selection()); // deleting selected app's last item shows everything
    assert(index.visibleKeys().size() == 2);
    assert(!index.erase({"missing", "missing"}));
    index.select("missing");
    assert(!index.selection());
    index.reset();
    index.upsert({{"a", "1"}, 10});
    index.upsert({{"b", "1"}, 10});
    assert(index.groups()[0].app == "a"); // deterministic ties
    index.upsert({{"a", "2"}, 50});
    index.erase({"a", "2"});
    assert(index.groups()[0].latest == 10); // newest timestamp recalculated on removal
    index.reset();
    assert(index.size() == 0 && !index.selection());

    // Random event sequences: compare group totals/visibility against a reference map.
    std::mt19937 rng(20261023);
    std::map<Key, double> reference;
    for (int i = 0; i < 20000; ++i) {
        Key key{"app" + std::to_string(rng() % 12), std::to_string(rng() % 80)};
        if (rng() % 3 == 0) { index.erase(key); reference.erase(key); }
        else { index.upsert({key, double(i)}); reference[key] = i; }
        if (rng() % 9 == 0) index.select(key.first);
        if (rng() % 11 == 0) index.select(std::nullopt);
        assert(index.size() == reference.size());
        size_t sum = 0;
        for (const auto &group : index.groups()) sum += group.count;
        assert(sum == reference.size());
        std::set<Key> expected;
        for (const auto &item : reference)
            if (!index.selection() || item.first.first == *index.selection()) expected.insert(item.first);
        assert(index.visibleKeys() == expected);
    }
    std::cout << "PASS: index edge cases and 20,000 randomized notification events\n";
}
