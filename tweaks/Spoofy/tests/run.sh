#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation SpoofyPolicy.m tests/policy.m -o build/policy-tests
./build/policy-tests
xcrun clang -fobjc-arc -Wall -Wextra -Werror -framework Foundation SpoofyPolicy.m SpoofyConfig.m tests/config.m -o build/config-tests
./build/config-tests
xcrun clang -std=c11 -Wall -Wextra -Werror -c SpoofyDiagnosticGuard.c -o build/diagnostic-guard.o
xcrun clang++ -std=c++17 -Wall -Wextra -Werror -pthread tests/category_guard.cpp build/diagnostic-guard.o -o build/category-guard-tests
./build/category-guard-tests
python3 -m unittest discover -s tests -p 'test_*.py' -v
