#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation SpoofyPolicy.m tests/policy.m -o build/policy-tests
./build/policy-tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation SpoofyPolicy.m SpoofyConfig.m tests/config.m -o build/config-tests
./build/config-tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
