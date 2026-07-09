#!/usr/bin/env bash
# patch-ipa-minos.sh — lower CFBundle MinimumOSVersion inside an IPA you own
# so TrollStore (or similar) can install it without going through App Store installd.
#
# Usage:
#   ./scripts/patch-ipa-minos.sh /path/to/App.ipa [targetOS]
# Example:
#   ./scripts/patch-ipa-minos.sh ~/Downloads/SomeApp.ipa 15.0
#
# Notes:
# - Only use with IPAs for apps you own / are allowed to install.
# - Info.plist patch is necessary but not always sufficient: some binaries
#   also encode min OS in Mach-O LC_BUILD_VERSION. Those may still fail to
#   launch on older iOS even after a successful TrollStore install.
# - Requires: unzip, zip, plutil (macOS) or plistutil

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <app.ipa> [minimumOS e.g. 15.0]" >&2
  exit 1
fi

IPA="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
TARGET_OS="${2:-15.0}"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/ipa-patch.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

if [[ ! -f "$IPA" ]]; then
  echo "IPA not found: $IPA" >&2
  exit 1
fi

echo "==> Extracting $(basename "$IPA")"
unzip -q "$IPA" -d "$WORKDIR"

APP_DIR="$(find "$WORKDIR/Payload" -maxdepth 1 -name '*.app' -type d | head -1)"
if [[ -z "$APP_DIR" ]]; then
  echo "No .app found in Payload/" >&2
  exit 1
fi

PLIST="$APP_DIR/Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "Missing Info.plist" >&2
  exit 1
fi

# Convert binary plist to XML if needed
if ! plutil -p "$PLIST" >/dev/null 2>&1; then
  echo "Cannot read Info.plist" >&2
  exit 1
fi

OLD="$(plutil -extract MinimumOSVersion raw "$PLIST" 2>/dev/null || echo '(none)')"
echo "==> MinimumOSVersion: $OLD -> $TARGET_OS"

# Set / replace MinimumOSVersion
if plutil -extract MinimumOSVersion raw "$PLIST" >/dev/null 2>&1; then
  plutil -replace MinimumOSVersion -string "$TARGET_OS" "$PLIST"
else
  plutil -insert MinimumOSVersion -string "$TARGET_OS" "$PLIST"
fi

# Some packages also carry LSMinimumSystemVersion
if plutil -extract LSMinimumSystemVersion raw "$PLIST" >/dev/null 2>&1; then
  plutil -replace LSMinimumSystemVersion -string "$TARGET_OS" "$PLIST"
fi

OUT="${IPA%.ipa}-minos${TARGET_OS}.ipa"
rm -f "$OUT"
(
  cd "$WORKDIR"
  zip -qr "$OUT" Payload
)

echo "==> Wrote $OUT"
echo ""
echo "Next on device:"
echo "  1. AirDrop/copy that IPA to the iPhone"
echo "  2. Open with TrollStore → Install"
echo "  3. If it installs but crashes on launch, the binary minos is still too new"
echo "     (Mach-O LC_BUILD_VERSION) — spoof/install alone cannot fix that app."
