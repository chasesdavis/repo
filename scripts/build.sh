#!/usr/bin/env bash
# Builds tweaks and copies the resulting packages into the static repo.
# Preserves the original Lumen-only behavior; StayOn17 added as a second target.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export THEOS="${THEOS:-/Users/chase/theos}"

BUILD_DIR="$(mktemp -d)"
trap 'command rm -rf "$BUILD_DIR"' EXIT

# Tweaks to build, in order. Add new tweaks here.
TWEAKS=(Lumen StayOn17)

build_tweak() {
  local name="$1"
  local pkg_id
  pkg_id="$(sed -n 's/^Package: //p' "$ROOT/tweaks/$name/control")"

  rsync -a --exclude .theos --exclude packages "$ROOT/tweaks/$name/" "$BUILD_DIR/$name/"
  cd "$BUILD_DIR/$name"
  make clean >/dev/null 2>&1 || true
  make package FINALPACKAGE=1 DEBUG=0 THEOS_PACKAGE_SCHEME=roothide

  mkdir -p "$ROOT/repo/debs"
  # Only this tweak's debs are replaced; other packages in debs must survive.
  command rm -f "$ROOT"/repo/debs/"${pkg_id}"_*.deb
  cp "$BUILD_DIR/$name"/packages/*.deb "$ROOT/repo/debs/"
  echo "Built $(cd "$ROOT/repo/debs" && ls "${pkg_id}"_*.deb)"
}

for t in "${TWEAKS[@]}"; do
  build_tweak "$t"
done
