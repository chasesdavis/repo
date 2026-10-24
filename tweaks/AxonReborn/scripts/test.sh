#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary="$(mktemp "${TMPDIR:-/tmp}/axon-core-test.XXXXXX")"
trap 'rm -f "$test_binary"' EXIT
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror -pedantic Tests/index_tests.cpp -o "$test_binary"
"$test_binary"
python3 scripts/validate.py
