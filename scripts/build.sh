#!/usr/bin/env bash
# Builds Lumen and copies the resulting package into the static repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export THEOS="${THEOS:-/Users/chase/theos}"

BUILD_DIR="$(mktemp -d)"
trap 'command rm -rf "$BUILD_DIR"' EXIT

rsync -a --exclude .theos --exclude packages "$ROOT/tweaks/Lumen/" "$BUILD_DIR/Lumen/"

cd "$BUILD_DIR/Lumen"
make clean >/dev/null 2>&1 || true
make package FINALPACKAGE=1 DEBUG=0 THEOS_PACKAGE_SCHEME=roothide

mkdir -p "$ROOT/repo/debs"
command rm -f "$ROOT"/repo/debs/*.deb
cp "$BUILD_DIR"/Lumen/packages/*.deb "$ROOT/repo/debs/"

echo "Built $(basename "$ROOT"/repo/debs/*.deb)"
