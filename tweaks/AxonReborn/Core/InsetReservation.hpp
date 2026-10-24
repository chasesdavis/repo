// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cmath>

namespace axon {
// Track only our contribution. A native absolute rewrite replaces the baseline;
// repeated layout passes must not keep adding the selector height.
class InsetReservation {
    double base_ = 0, last_ = 0;
    bool applied_ = false;
public:
    double update(double observed, double height) {
        if (!applied_ || std::abs(observed - last_) > 0.25) base_ = observed;
        last_ = base_ + height;
        applied_ = height > 0;
        return last_;
    }
};
}
