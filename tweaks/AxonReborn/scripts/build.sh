#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:-roothide}"
case "$variant" in rootful|rootless|roothide) ;; *) echo 'Usage: build.sh rootful|rootless|roothide' >&2; exit 2;; esac
: "${THEOS:?Set THEOS to a configured Theos checkout (roothide/theos for RootHide).}"
if ! command -v xcrun >/dev/null 2>&1; then
  echo 'A macOS/Xcode build host is required by this project for the modern arm64e ABI.' >&2
  exit 1
fi
xcrun --sdk iphoneos --show-sdk-path >/dev/null
# Cleaning between package variants is required; never re-label an existing .deb.
make clean AXON_VARIANT="$variant"
make package AXON_VARIANT="$variant"
