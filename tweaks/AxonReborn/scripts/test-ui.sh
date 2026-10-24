#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
app="$work/AxonMountTest.app"
mkdir -p "$app"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
arch="$(uname -m)"
device="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for k,a in d["devices"].items() if "iOS" in k for v in a if v.get("isAvailable") and "iPhone" in v["name"]))')"
xcrun clang++ -arch "$arch" -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -fobjc-arc -std=gnu++17 -x objective-c++ \
  Tests/mount_app.mm Tests/runtime_tests.mm Tests/preferences_tests.mm Tests/rail_features.mm Tweak/AXNListMount.mm Tweak/AXNListResolver.m Tweak/AXNNativeFilter.m Tweak/AXNRailView.m Shared/AXNPreferences.m \
  -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -framework CoreFoundation -o "$app/AxonMountTest"
python3 - "$app/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'wb') as f:
 plistlib.dump({'CFBundleIdentifier':'com.chasesdavis.axonmounttest','CFBundleExecutable':'AxonMountTest',
               'CFBundleName':'AxonMountTest','CFBundlePackageType':'APPL','CFBundleVersion':'1',
               'CFBundleShortVersionString':'1.0','MinimumOSVersion':'15.0','LSRequiresIPhoneOS':True,
               'UIDeviceFamily':[1],'UILaunchScreen':{}},f)
PY
codesign --force --sign - "$app"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
echo "AXN_UI_STAGE: installing test application"
xcrun simctl install "$device" "$app"
echo "AXN_UI_STAGE: launching test application"
xcrun simctl launch --console --terminate-running-process "$device" com.chasesdavis.axonmounttest 2>&1 | tee "$work/result.txt"
grep -q 'AXN_PREFERENCES_TEST_PASS' "$work/result.txt"
grep -q 'AXN_RAIL_FEATURE_TEST_PASS' "$work/result.txt"
grep -q 'AXN_UI_TEST_PASS' "$work/result.txt"
