#!/usr/bin/env python3
"""Validate Harbor's published metadata and the existing repo's artifact hashes."""
import bz2
import gzip
import hashlib
import lzma
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT / "repo"

def fields(text):
    result = {}
    for line in text.splitlines():
        if not line or line[0].isspace():
            continue
        key, value = line.split(":", 1)
        assert key not in result, f"Duplicate field {key}"
        result[key] = value.strip()
    return result

raw = (REPO / "Packages").read_bytes()
entries = [fields(s) for s in raw.decode().strip().split("\n\n")]
harbor = [e for e in entries if e["Package"] == "com.chasedavis.harbor"]
assert len(harbor) == 1, "Exactly one Harbor beta must be published"
entry = harbor[0]
source = fields((ROOT / "tweaks/Harbor/control").read_text())
for key, value in source.items():
    assert entry.get(key) == value, f"Harbor {key} differs from its source control file"
assert entry["Version"] == "0.1.0~beta3"
assert entry["Architecture"] == "iphoneos-arm64e"
assert "Beta" in entry["Name"] and "physical-device testing is pending" in entry["Description"]
assert "firmware (>= 17.0)" in entry["Depends"] and "firmware (<< 17.1)" in entry["Depends"]
assert entry["Filename"] == f"debs/com.chasedavis.harbor_{entry['Version']}_iphoneos-arm64e.deb"

filenames = set()
for item in entries:
    name = item["Filename"]
    assert name.startswith("debs/") and ".." not in Path(name).parts and name not in filenames
    filenames.add(name)
    data = (REPO / name).read_bytes()
    assert len(data) == int(item["Size"]), name
    for field, algorithm in [("MD5sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256")]:
        assert hashlib.new(algorithm, data).hexdigest() == item[field], (name, field)
assert filenames == {f"debs/{p.name}" for p in (REPO / "debs").glob("*.deb")}
control = fields(subprocess.check_output(["dpkg-deb", "-f", str(REPO / entry["Filename"])], text=True))
for key, value in source.items():
    assert control[key] == value, f"Packaged {key} differs"

# Preserve the established flat + two-suite/two-architecture index layout.
index_names = ["Packages", "Packages.gz", "Packages.xz", "Packages.zst", "Packages.bz2", "Packages.lzma"]
for suffix, decompress in [("gz", gzip.decompress), ("xz", lzma.decompress), ("bz2", bz2.decompress), ("lzma", lzma.decompress)]:
    assert decompress((REPO / f"Packages.{suffix}").read_bytes()) == raw
for suite in ["stable", "ios17"]:
    for arch in ["iphoneos-arm64", "iphoneos-arm64e"]:
        for name in index_names:
            assert (REPO / "dists" / suite / "main" / f"binary-{arch}" / name).read_bytes() == (REPO / name).read_bytes()
for release in [REPO / "Release", REPO / "dists/stable/Release", REPO / "dists/ios17/Release"]:
    algorithm = None
    counts = {"md5": 0, "sha1": 0, "sha256": 0}
    for line in release.read_text().splitlines():
        if line in ["MD5Sum:", "SHA1:", "SHA256:"]:
            algorithm = {"MD5Sum:": "md5", "SHA1:": "sha1", "SHA256:": "sha256"}[line]
        elif line.startswith(" ") and algorithm:
            digest, size, name = line.split()
            data = (release.parent / name).read_bytes()
            assert len(data) == int(size) and hashlib.new(algorithm, data).hexdigest() == digest, (release, name)
            counts[algorithm] += 1
        else:
            algorithm = None
    expected = 6 if release.parent == REPO else 12
    assert all(count == expected for count in counts.values()), (release, counts)
assert (REPO / "assets/harbor/icon.png").is_file()
assert (REPO / "assets/harbor/preview.png").is_file()
depiction = (REPO / "depiction/harbor/index.html").read_text()
assert "Physical-device testing is pending" in depiction
assert entry["Version"] in depiction and entry["Version"] in (REPO / "index.html").read_text()
print(f"PASS: {len(entries)} package artifacts; Harbor beta metadata/control; compressed and suite indexes; all Release checksums")
print(f"Harbor SHA256: {entry['SHA256']}")
