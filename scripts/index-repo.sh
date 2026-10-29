#!/usr/bin/env bash
# Regenerates Packages/Release plus the Debian dists layout for Pages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$ROOT/repo"
DEBS="$REPO/debs"
PACKAGES="$REPO/Packages"
SUITES=(stable ios17)
ARCHES=(iphoneos-arm64 iphoneos-arm64e)
INDEXES=(Packages Packages.gz Packages.xz Packages.zst Packages.bz2 Packages.lzma)

md5_of() { md5 -q "$1"; }
sha1_of() { shasum -a 1 "$1" | awk '{print $1}'; }
sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

mkdir -p "$DEBS"
: > "$PACKAGES"

shopt -s nullglob
debs=("$DEBS"/*.deb)
[[ ${#debs[@]} -gt 0 ]] || { echo "No packages in $DEBS" >&2; exit 1; }

for deb in "${debs[@]}"; do
  name="$(basename "$deb")"
  control="$(dpkg-deb -f "$deb")"
  {
    printf '%s\n' "$control"
    printf 'Filename: debs/%s\n' "$name"
    printf 'Size: %s\n' "$(stat -f %z "$deb")"
    printf 'MD5sum: %s\n' "$(md5_of "$deb")"
    printf 'SHA1: %s\n' "$(sha1_of "$deb")"
    printf 'SHA256: %s\n' "$(sha256_of "$deb")"
    printf '\n'
  } >> "$PACKAGES"
done

gzip -9 -c "$PACKAGES" > "$REPO/Packages.gz"
xz -9 -c "$PACKAGES" > "$REPO/Packages.xz"
zstd -19 -q -c "$PACKAGES" > "$REPO/Packages.zst"
bzip2 -9 -c "$PACKAGES" > "$REPO/Packages.bz2"
lzma -9 -c "$PACKAGES" > "$REPO/Packages.lzma"

release_header() {
  local suite="$1"
  cat <<EOF
Origin: Chase Davis
Label: Lumen
Suite: $suite
Codename: ios17
Architectures: ${ARCHES[*]}
Components: main
Description: Lumen - free status bar pill
Date: $(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S UTC")
EOF
}

checksum_block() {
  local base="$1" prefix="$2"
  echo "MD5Sum:"
  for arch in "${ARCHES[@]}"; do
    for file in "${INDEXES[@]}"; do
      local path="$base/main/binary-$arch/$file"
      printf ' %s %16s %s%s/%s\n' "$(md5_of "$path")" "$(stat -f %z "$path")" "$prefix" "main/binary-$arch" "$file"
    done
  done
  echo "SHA1:"
  for arch in "${ARCHES[@]}"; do
    for file in "${INDEXES[@]}"; do
      local path="$base/main/binary-$arch/$file"
      printf ' %s %16s %s%s/%s\n' "$(sha1_of "$path")" "$(stat -f %z "$path")" "$prefix" "main/binary-$arch" "$file"
    done
  done
  echo "SHA256:"
  for arch in "${ARCHES[@]}"; do
    for file in "${INDEXES[@]}"; do
      local path="$base/main/binary-$arch/$file"
      printf ' %s %16s %s%s/%s\n' "$(sha256_of "$path")" "$(stat -f %z "$path")" "$prefix" "main/binary-$arch" "$file"
    done
  done
}

{ release_header "./"; echo "MD5Sum:"; for f in "${INDEXES[@]}"; do printf ' %s %16s %s\n' "$(md5_of "$REPO/$f")" "$(stat -f %z "$REPO/$f")" "$f"; done
  echo "SHA1:"; for f in "${INDEXES[@]}"; do printf ' %s %16s %s\n' "$(sha1_of "$REPO/$f")" "$(stat -f %z "$REPO/$f")" "$f"; done
  echo "SHA256:"; for f in "${INDEXES[@]}"; do printf ' %s %16s %s\n' "$(sha256_of "$REPO/$f")" "$(stat -f %z "$REPO/$f")" "$f"; done; } > "$REPO/Release"

for suite in "${SUITES[@]}"; do
  for arch in "${ARCHES[@]}"; do
    dest="$REPO/dists/$suite/main/binary-$arch"
    mkdir -p "$dest"
    for file in "${INDEXES[@]}"; do cp "$REPO/$file" "$dest/$file"; done
  done
  { release_header "$suite"; checksum_block "$REPO/dists/$suite" ""; } > "$REPO/dists/$suite/Release"
done

echo "Indexed ${#debs[@]} package(s)"
