#!/usr/bin/env bash
# decrypt-app.sh — dump a *decrypted* IPA from an app already on your iPhone
# for personal TrollStore install (bypasses App Store installd).
#
# HOW IT WORKS
#   App Store binaries are FairPlay-encrypted on disk. While the app is
#   running, iOS has the decrypted code in memory. bagbak + Frida dump
#   that memory and repackage a decrypted IPA.
#
# REQUIREMENTS (Mac)
#   - brew: libimobiledevice (idevice_id), node (for bagbak)
#   - npm i -g bagbak
#   - pip/pipx: frida-tools  (frida / frida-ps)
#   - USB trust between Mac and iPhone
#
# REQUIREMENTS (iPhone — RootHide Bootstrap / jailbreak)
#   - Frida on-device (Sileo: search "Frida" / re.frida.server — rootless build)
#   - Target app installed and able to launch on THIS iOS version
#   - Bootstrap App List: enable injection for that app (and for Frida if needed)
#   - App must actually run (encrypted iOS-18-only apps that won't launch
#     cannot be dumped this way — chicken and egg)
#
# USAGE
#   ./scripts/decrypt-app.sh                     # list apps
#   ./scripts/decrypt-app.sh com.example.app     # dump decrypted IPA
#   ./scripts/decrypt-app.sh com.example.app 15.0  # dump + patch min OS
#
# ETHICS / LEGAL
#   Only decrypt apps you own / are licensed to use. Do not redistribute
#   decrypted IPAs. This is for personal backup / TrollStore on your device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-$PWD/decrypted-ipas}"
BUNDLE_ID="${1:-}"
PATCH_MINOS="${2:-}"

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
inf()  { printf '==> %s\n' "$*"; }

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    red "Missing dependency: $1"
    echo "  $2"
    MISSING=1
  fi
}

MISSING=0
need idevice_id "brew install libimobiledevice"
need node       "brew install node"
need npm        "brew install node"
need frida      "pipx install frida-tools   # or: pip3 install frida-tools"
need frida-ps   "pipx install frida-tools"

if ! command -v bagbak >/dev/null 2>&1; then
  ylw "bagbak not found — will try: npm install -g bagbak"
  if [[ "${AUTO_INSTALL_BAGBAK:-1}" == "1" ]]; then
    npm install -g bagbak
  else
    red "Install bagbak: npm install -g bagbak"
    MISSING=1
  fi
fi

if [[ "$MISSING" == "1" ]]; then
  exit 1
fi

# --- device present? ---
inf "Looking for USB device…"
if ! DEVICE="$(idevice_id -l 2>/dev/null | head -1)" || [[ -z "$DEVICE" ]]; then
  red "No device via USB. Unlock phone, tap Trust, try again."
  exit 1
fi
grn "Device: $DEVICE"

# --- frida talking to phone? ---
inf "Checking Frida on device…"
if ! frida-ps -U >/dev/null 2>&1; then
  red "Frida cannot talk to the device."
  echo ""
  echo "On iPhone (RootHide Bootstrap):"
  echo "  1. Sileo → install Frida (re.frida.server) for rootless"
  echo "  2. Bootstrap → App List → enable the target app (for dump inject)"
  echo "  3. Reboot or restart frida-server if needed"
  echo "  4. USB connected, phone unlocked"
  echo ""
  echo "Test:  frida-ps -U"
  exit 1
fi
grn "Frida is up."

# --- list mode ---
if [[ -z "$BUNDLE_ID" || "$BUNDLE_ID" == "-l" || "$BUNDLE_ID" == "--list" ]]; then
  inf "Installed apps (bagbak -l):"
  bagbak -l || true
  echo ""
  echo "Usage: $0 <bundle.id> [minOS-to-patch]"
  echo "Example: $0 com.burbn.instagram 15.0"
  exit 0
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

inf "Decrypting $BUNDLE_ID (leave the app open / allow it to launch)…"
ylw "If bagbak says it cannot attach: open the app on the phone first, enable it in Bootstrap App List, retry."

# bagbak writes IPA into CWD
set +e
bagbak "$BUNDLE_ID"
BAG_EC=$?
set -e

# Find newest ipa matching bundle
IPA="$(ls -t "${BUNDLE_ID}"*.ipa 2>/dev/null | head -1 || true)"
if [[ -z "$IPA" ]]; then
  IPA="$(ls -t ./*.ipa 2>/dev/null | head -1 || true)"
fi

if [[ "$BAG_EC" -ne 0 || -z "$IPA" || ! -f "$IPA" ]]; then
  red "Dump failed (exit $BAG_EC) or no IPA produced."
  echo ""
  echo "Common fixes on Bootstrap:"
  echo "  • App must launch on this iOS (can't dump what won't run)"
  echo "  • Bootstrap App List → enable the app"
  echo "  • Frida installed and frida-ps -U works"
  echo "  • Open the app, leave it in foreground, re-run"
  echo "  • Try: DEBUG=1 bagbak $BUNDLE_ID"
  exit 1
fi

grn "Decrypted IPA: $OUT_DIR/$IPA"

# Optional min-OS patch for TrollStore
FINAL="$IPA"
if [[ -n "$PATCH_MINOS" ]]; then
  PATCHER="$SCRIPT_DIR/patch-ipa-minos.sh"
  if [[ ! -x "$PATCHER" ]]; then
    chmod +x "$PATCHER" 2>/dev/null || true
  fi
  if [[ -x "$PATCHER" ]]; then
    inf "Patching MinimumOSVersion → $PATCH_MINOS"
    "$PATCHER" "$OUT_DIR/$IPA" "$PATCH_MINOS"
    FINAL="$(ls -t "$OUT_DIR"/*-minos${PATCH_MINOS}.ipa 2>/dev/null | head -1 || true)"
    [[ -n "$FINAL" ]] || FINAL="$IPA"
  else
    ylw "patch-ipa-minos.sh not found; skipping min-OS patch"
  fi
fi

echo ""
grn "Done."
echo "  Decrypted: $OUT_DIR/$IPA"
[[ "$FINAL" != "$IPA" && -n "$FINAL" ]] && echo "  Patched:    $FINAL"
echo ""
echo "On iPhone:"
echo "  1. AirDrop the IPA to the phone"
echo "  2. Share → TrollStore → Install"
echo "  3. If it installs but crashes on launch, that build needs newer OS APIs"
echo "     (decrypt/install cannot invent iOS 18 frameworks)."
echo ""
echo "Personal use only — do not redistribute decrypted IPAs."
