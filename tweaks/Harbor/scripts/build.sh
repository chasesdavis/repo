#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_root="$PWD"
export THEOS="${THEOS:-/Users/chase/theos}"
build_dir="$(mktemp -d /tmp/harbor-build.XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
# Theos/make cannot reliably handle the spaces in "Jailbreak Tweak Repo".
rsync -a --exclude .theos --exclude .build --exclude packages --exclude docs "$source_root/" "$build_dir/"
cd "$build_dir"
mkdir -p .build/ModuleCache
export CLANG_MODULE_CACHE_PATH="$build_dir/.build/ModuleCache"
make package FINALPACKAGE=1 DEBUG=0 THEOS_PACKAGE_SCHEME=roothide "$@"
mkdir -p "$source_root/packages"
cp packages/com.chasedavis.harbor_*.deb "$source_root/packages/"
# Intentionally no install, respring, repo/debs copy, or index/publish step.
