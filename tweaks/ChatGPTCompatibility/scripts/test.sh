#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .test-build
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
  -Wno-deprecated-declarations -framework Foundation -I. \
  CompatPolicy.m MethodTypes.m Tests/PolicyTests.m -o .test-build/policy-tests
.test-build/policy-tests
xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror -Wno-unused-parameter \
  -Wno-deprecated-declarations -framework Foundation -I. -ITests/include \
  CompatPolicy.m MethodTypes.m Tests/HookTests.m -o .test-build/hook-tests
.test-build/hook-tests
plutil -lint ChatGPTCompatibility.plist Preferences/entry.plist Preferences/Resources/Info.plist
