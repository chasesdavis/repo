#!/usr/bin/env bash
# Builds only Harbor. Existing published package binaries are left untouched.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/tweaks/Harbor/scripts/check.sh"
bash "$ROOT/tweaks/Harbor/scripts/build.sh"
bash "$ROOT/tweaks/Harbor/scripts/verify-package.sh"
version="$(sed -n 's/^Version: //p' "$ROOT/tweaks/Harbor/control")"
name="com.chasedavis.harbor_${version}_iphoneos-arm64e.deb"
mkdir -p "$ROOT/repo/debs"
cp "$ROOT/tweaks/Harbor/packages/$name" "$ROOT/repo/debs/$name"
printf 'Built repo/debs/%s\nRun scripts/index-repo.sh before committing.\n' "$name"
