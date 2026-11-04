#pragma once
#include <stdbool.h>

// Kept UIKit-free so the fail-open policy can be exercised on the build host.
bool HBShouldPresent(int osMajor, bool enabled, bool phone, double width, double height,
                     bool validNativeHierarchy, bool nativeRequested, bool expanded);
double HBUnitValue(double value, double fallback);
bool HBValidMediaCommand(int command);
