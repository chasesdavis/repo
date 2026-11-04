#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/policy_test.c HBPolicy.c -o .build/policy-test
.build/policy-test
python3 tests/integration_contract_test.py
while IFS= read -r -d '' file; do
    plutil -lint "$file"
done < <(find . \( -name .theos -o -name .build \) -prune -o -name '*.plist' -print0)
