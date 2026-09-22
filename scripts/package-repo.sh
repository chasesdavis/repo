#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$ROOT/repo"
DEBS="$REPO/debs"
PACKAGES="$REPO/Packages"

mkdir -p "$DEBS"
: > "$PACKAGES"

extract_control() {
  local deb="$1"
  local tmp="$2"
  (cd "$tmp" && ar -x "$deb")
  local control_archive
  control_archive="$(find "$tmp" -maxdepth 1 -type f -name 'control.tar*' | head -1)"
  [[ -n "$control_archive" ]] || return 1
  mkdir -p "$tmp/control"
  tar -xf "$control_archive" -C "$tmp/control"
  local control_file
  control_file="$(find "$tmp/control" -type f -name control | head -1)"
  [[ -n "$control_file" ]] || return 1
  cat "$control_file"
}

checksum_md5() {
  md5 -q "$1"
}

checksum_sha() {
  shasum -a "$1" "$2" | awk '{print $1}'
}

while IFS= read -r -d '' deb; do
  tmp="$(mktemp -d)"
  rel="debs/$(basename "$deb")"
  if control="$(extract_control "$deb" "$tmp")"; then
    {
      printf "%s\n" "$control"
      printf "Filename: %s\n" "$rel"
      printf "Size: %s\n" "$(stat -f %z "$deb")"
      printf "MD5sum: %s\n" "$(checksum_md5 "$deb")"
      printf "SHA1: %s\n" "$(checksum_sha 1 "$deb")"
      printf "SHA256: %s\n" "$(checksum_sha 256 "$deb")"
      printf "\n"
    } >> "$PACKAGES"
  else
    echo "Failed to extract control metadata from $deb" >&2
    rm -rf "$tmp"
    exit 1
  fi
  rm -rf "$tmp"
done < <(find "$DEBS" -maxdepth 1 -type f -name '*.deb' -print0 | sort -z)

gzip -c "$PACKAGES" > "$REPO/Packages.gz"
xz -c "$PACKAGES" > "$REPO/Packages.xz"
zstd -c -19 "$PACKAGES" > "$REPO/Packages.zst"
bzip2 -c "$PACKAGES" > "$REPO/Packages.bz2"
lzma -c -9 "$PACKAGES" > "$REPO/Packages.lzma"

INDEX_FILES=(Packages Packages.gz Packages.xz Packages.zst Packages.bz2 Packages.lzma)

cat > "$REPO/Release" <<EOF
Origin: Chase Davis
Label: iOS 17 Roothide Tweak Lab
Suite: ./
Codename: ios17
Architectures: iphoneos-arm64 iphoneos-arm64e
Components: main
Description: Local roothide Bootstrap tweak repo
Date: $(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S UTC")
EOF

{
  echo "MD5Sum:"
  for file in "${INDEX_FILES[@]}"; do
    printf " %s %16s %s\n" "$(checksum_md5 "$REPO/$file")" "$(stat -f %z "$REPO/$file")" "$file"
  done
  echo "SHA1:"
  for file in "${INDEX_FILES[@]}"; do
    printf " %s %16s %s\n" "$(checksum_sha 1 "$REPO/$file")" "$(stat -f %z "$REPO/$file")" "$file"
  done
  echo "SHA256:"
  for file in "${INDEX_FILES[@]}"; do
    printf " %s %16s %s\n" "$(checksum_sha 256 "$REPO/$file")" "$(stat -f %z "$REPO/$file")" "$file"
  done
} >> "$REPO/Release"

# Sileo also requests the Debian dists layout when a source was saved with a suite.
for suite in stable ios17; do
  for arch in iphoneos-arm64 iphoneos-arm64e; do
    dest="$REPO/dists/$suite/main/binary-$arch"
    mkdir -p "$dest"
    for file in "${INDEX_FILES[@]}"; do
      cp "$REPO/$file" "$dest/$file"
    done
  done
  dist_release="$REPO/dists/$suite/Release"
  cat > "$dist_release" <<EOF
Origin: Chase Davis
Label: iOS 17 Roothide Tweak Lab
Suite: $suite
Codename: ios17
Architectures: iphoneos-arm64 iphoneos-arm64e
Components: main
Description: Local roothide Bootstrap tweak repo
Date: $(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S UTC")
EOF
  {
    echo "MD5Sum:"
    for arch in iphoneos-arm64 iphoneos-arm64e; do
      for file in "${INDEX_FILES[@]}"; do
        path="$REPO/dists/$suite/main/binary-$arch/$file"
        printf " %s %16s main/binary-%s/%s\n" "$(checksum_md5 "$path")" "$(stat -f %z "$path")" "$arch" "$file"
      done
    done
    echo "SHA1:"
    for arch in iphoneos-arm64 iphoneos-arm64e; do
      for file in "${INDEX_FILES[@]}"; do
        path="$REPO/dists/$suite/main/binary-$arch/$file"
        printf " %s %16s main/binary-%s/%s\n" "$(checksum_sha 1 "$path")" "$(stat -f %z "$path")" "$arch" "$file"
      done
    done
    echo "SHA256:"
    for arch in iphoneos-arm64 iphoneos-arm64e; do
      for file in "${INDEX_FILES[@]}"; do
        path="$REPO/dists/$suite/main/binary-$arch/$file"
        printf " %s %16s main/binary-%s/%s\n" "$(checksum_sha 256 "$path")" "$(stat -f %z "$path")" "$arch" "$file"
      done
    done
  } >> "$dist_release"
done

echo "Wrote $PACKAGES"
