#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/policy_test.c HBPolicy.c -o .build/policy-test
.build/policy-test
clang -fobjc-arc -Wall -Wextra -Werror -fsanitize=address,undefined -I. tests/profile_model_test.m HBProfileModel.m -framework Foundation -o .build/profile-model-test
.build/profile-model-test
clang -fobjc-arc -Wall -Wextra -Werror -Wno-unused-parameter -fsanitize=address,undefined -I. tests/focus_monitor_test.m HBFocusMonitor.m HBProfileModel.m -framework Foundation -o .build/focus-monitor-test
.build/focus-monitor-test
python3 tests/integration_contract_test.py
while IFS= read -r -d '' file; do
    plutil -lint "$file"
done < <(find . \( -name .theos -o -name .build \) -prune -o -name '*.plist' -print0)
