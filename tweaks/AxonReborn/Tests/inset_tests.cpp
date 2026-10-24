// SPDX-License-Identifier: GPL-3.0-only
#include "../Core/InsetReservation.hpp"
#include <cassert>
#include <iostream>
int main() {
    axon::InsetReservation inset;
    double value = inset.update(24, 106);
    assert(value == 130);
    for (int i = 0; i < 10000; ++i) {
        value = inset.update(value, 106);
        assert(value == 130); // repeated layouts never accumulate padding
    }
    assert(inset.update(value, 150) == 174); // Dynamic Type
    assert(inset.update(40, 150) == 190); // native rotation/layout replaces inset
    assert(inset.update(190, 0) == 40); // disable/disappear removes only our space
    assert(inset.update(40, 0) == 40);
    assert(inset.update(40, 106) == 146); // re-enable
    assert(inset.update(12, 0) == 12); // native rewrite before disable survives
    std::cout << "PASS: selector inset lifecycle, native rewrites and 10,000 layout passes\n";
}
