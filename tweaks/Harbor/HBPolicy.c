#include "HBPolicy.h"
#include <math.h>

bool HBShouldPresent(int osMajor, bool enabled, bool phone, double width, double height,
                     bool validNativeHierarchy, bool nativeRequested, bool expanded) {
    return osMajor == 17 && enabled && phone && isfinite(width) && isfinite(height) &&
           width >= 300 && height >= 480 && height > width &&
           validNativeHierarchy && !nativeRequested && !expanded;
}

double HBUnitValue(double value, double fallback) {
    if (!isfinite(value)) value = isfinite(fallback) ? fallback : 0.5;
    return fmax(0.0, fmin(1.0, value));
}

bool HBValidMediaCommand(int command) { return command == 2 || command == 4 || command == 5; }
