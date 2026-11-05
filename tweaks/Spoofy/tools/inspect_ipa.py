#!/usr/bin/env python3
"""Read IPA bundle metadata without extracting, modifying, or installing anything."""
import argparse
import json
import plistlib
import re
import zipfile


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,3}(\.[0-9]{1,3}){0,2}", value):
        return None
    parts = tuple(map(int, value.split(".")))
    return parts + (0,) * (3 - len(parts))


def inspect(path, target="17.0"):
    target_version = version(target)
    if target_version is None:
        raise ValueError("Invalid target OS version")
    bundles = []
    with zipfile.ZipFile(path) as archive:
        names = set()
        total = 0
        for entry in archive.infolist():
            name = entry.filename
            if not re.fullmatch(r"Payload/[^/]+\.app/(?:.*/)?Info\.plist", name):
                continue
            if name in names:
                raise ValueError("Duplicate Info.plist entry")
            names.add(name)
            total += entry.file_size
            if entry.file_size > 1024 * 1024 or total > 8 * 1024 * 1024 or len(names) > 256:
                raise ValueError("Metadata inspection size limit exceeded")
            info = plistlib.loads(archive.read(entry))
            if not isinstance(info, dict):
                raise ValueError("Info.plist must contain a dictionary")
            minimum = info.get("MinimumOSVersion")
            parsed = version(minimum)
            bundles.append({
                "path": name,
                "bundle_id": info.get("CFBundleIdentifier"),
                "minimum_os": minimum,
                "metadata_result": "unknown" if parsed is None else
                    "above_target" if parsed > target_version else "within_target",
            })
    if not any(re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", b["path"]) for b in bundles):
        raise ValueError("No top-level application Info.plist found")
    return {"target_os": target, "bundles": bundles, "runtime_compatibility": "not assessed",
            "note": "Metadata only. Does not assess Mach-O requirements, symbols, encryption, entitlements, account eligibility, or server support."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    parser.add_argument("--target", default="17.0")
    args = parser.parse_args()
    try:
        print(json.dumps(inspect(args.ipa, args.target), indent=2))
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, plistlib.InvalidFileException) as error:
        parser.exit(2, f"Inspection failed: {error}\n")
