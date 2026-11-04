#include "../HBPolicy.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    assert(HBShouldPresent(17, true, true, 393, 759, true, false, false));
    assert(HBShouldPresent(17, true, true, 320, 568, true, false, false));
    assert(!HBShouldPresent(18, true, true, 393, 759, true, false, false));
    assert(!HBShouldPresent(16, true, true, 393, 759, true, false, false));
    assert(!HBShouldPresent(17, false, true, 393, 759, true, false, false));
    assert(!HBShouldPresent(17, true, false, 768, 1024, true, false, false));
    assert(!HBShouldPresent(17, true, true, 759, 393, true, false, false));
    assert(!HBShouldPresent(17, true, true, 393, 759, false, false, false));
    assert(!HBShouldPresent(17, true, true, 393, 759, true, true, false));
    assert(!HBShouldPresent(17, true, true, 393, 759, true, false, true));
    assert(!HBShouldPresent(17, true, true, NAN, 759, true, false, false));
    assert(!HBShouldPresent(17, true, true, 299, 759, true, false, false));
    assert(!HBShouldPresent(17, true, true, 393, INFINITY, true, false, false));
    assert(HBUnitValue(-1, 0.5) == 0);
    assert(HBUnitValue(2, 0.5) == 1);
    assert(HBUnitValue(NAN, 0.5) == 0.5);
    assert(HBUnitValue(INFINITY, NAN) == 0.5);
    assert(HBUnitValue(0.4, 0.5) == 0.4);
    assert(HBValidMediaCommand(2) && HBValidMediaCommand(4) && HBValidMediaCommand(5));
    assert(!HBValidMediaCommand(-1) && !HBValidMediaCommand(0) && !HBValidMediaCommand(99));
    puts("PASS: 20 presentation, numeric-boundary, and command-policy assertions");
    return 0;
}
