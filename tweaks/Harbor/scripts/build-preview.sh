#!/bin/bash
# Builds a simulator-only harness from the same UIKit sources. Does not install it.
set -euo pipefail
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
app="${HARBOR_PREVIEW_APP:-$PWD/.build/HarborPreview.app}"
mkdir -p "$app" .build/SimulatorModules
xcrun clang -target arm64-apple-ios17.0-simulator -isysroot "$sdk" -fobjc-arc -fmodules \
    -fmodules-cache-path="$PWD/.build/SimulatorModules" -Wall -Wextra -Wno-unused-parameter \
    tests/PreviewMain.m HBSession.m HBDashboardController.m HBMediaProvider.m HBPreferences.m HBPolicy.c \
    -framework UIKit -framework Foundation -framework QuartzCore -framework MediaPlayer -framework ImageIO -framework AVKit \
    -o "$app/HarborPreview"
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.chasedavis.harbor.preview</string>
<key>CFBundleExecutable</key><string>HarborPreview</string>
<key>CFBundleName</key><string>Harbor Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>MinimumOSVersion</key><string>17.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer></array>
<key>UILaunchScreen</key><dict/>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
</dict></plist>
PLIST
xattr -cr "$app"
codesign --force --sign - "$app"
printf '%s\n' "$app"
