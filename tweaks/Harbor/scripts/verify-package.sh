#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
package="$PWD/packages/com.chasedavis.harbor_0.1.0~beta1_iphoneos-arm64e.deb"
stage="$(mktemp -d /tmp/harbor-verify.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
dpkg-deb -x "$package" "$stage"
dpkg-deb -I "$package"
python3 - "$stage" <<'PY'
import pathlib, plistlib, sys
root = pathlib.Path(sys.argv[1])
expected = {
    'Library/MobileSubstrate/DynamicLibraries/Harbor.dylib',
    'Library/MobileSubstrate/DynamicLibraries/Harbor.plist',
    'Library/PreferenceBundles/HarborPrefs.bundle/HarborPrefs',
    'Library/PreferenceBundles/HarborPrefs.bundle/Info.plist',
    'Library/PreferenceBundles/HarborPrefs.bundle/Root.plist',
    'Library/PreferenceLoader/Preferences/Harbor.plist',
}
actual = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
assert actual == expected, (actual - expected, expected - actual)
with (root / 'Library/MobileSubstrate/DynamicLibraries/Harbor.plist').open('rb') as f:
    assert plistlib.load(f)['Filter']['Bundles'] == ['com.apple.springboard']
print('PASS: exact package manifest and SpringBoard-only injection filter')
PY
lipo "$stage/Library/MobileSubstrate/DynamicLibraries/Harbor.dylib" -verify_arch arm64 arm64e
lipo "$stage/Library/PreferenceBundles/HarborPrefs.bundle/HarborPrefs" -verify_arch arm64 arm64e
otool -L "$stage/Library/MobileSubstrate/DynamicLibraries/Harbor.dylib"
shasum -a 256 "$package"
