"""Check this RootHide package's layout and ldid CodeDirectory page hashes."""

import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tarfile


def archive_members(package: Path, option: str) -> dict[str, bytes]:
    data = subprocess.run(["dpkg-deb", option, str(package)], check=True, capture_output=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
        files = {}
        for member in archive:
            if member.isdir():
                continue
            assert member.isfile(), "Unexpected link or special package member"
            name = member.name.removeprefix("./")
            assert name not in files and ".." not in Path(name).parts
            files[name] = archive.extractfile(member).read()
        return files


def verify_binary(data: bytes) -> list[dict]:
    magic, count = struct.unpack_from(">II", data)
    assert magic == 0xCAFEBABE and count == 2, "Expected arm64/arm64e universal binary"
    results = []
    for index in range(count):
        cpu, subtype, offset, size, alignment = struct.unpack_from(">IIIII", data, 8 + index * 20)
        assert cpu == 0x0100000C and (subtype & 0xFFFFFF) in (0, 2)
        image = data[offset:offset + size]
        assert len(image) == size
        header = struct.unpack_from("<IIIIIIII", image)
        assert header[0] == 0xFEEDFACF
        position, signature, build = 32, None, None
        for _ in range(header[4]):
            command, length = struct.unpack_from("<II", image, position)
            assert length >= 8 and position + length <= len(image)
            if command == 0x1D:
                start, length_signature = struct.unpack_from("<II", image, position + 8)
                signature = image[start:start + length_signature]
            if command == 0x32:
                build = struct.unpack_from("<III", image, position + 8)
            position += length
        assert build == (2, 0x110000, 0x110000), "Expected iOS minimum/SDK 17.0"
        assert signature, "Missing embedded ldid signature structure"
        sig_magic, sig_length, blobs = struct.unpack_from(">III", signature)
        assert sig_magic == 0xFADE0CC0 and sig_length <= len(signature)
        directories, embedded = [], {}
        for item in range(blobs):
            slot, location = struct.unpack_from(">II", signature, 12 + item * 8)
            blob_magic, blob_length = struct.unpack_from(">II", signature, location)
            blob = signature[location:location + blob_length]
            assert len(blob) == blob_length
            if blob_magic == 0xFADE0C02:
                directories.append(blob)
            else:
                embedded[slot] = blob
        assert directories, "No CodeDirectory"
        verified_pages = 0
        for directory in directories:
            hash_offset, identifier_offset, special_count, page_count, code_limit = struct.unpack_from(">IIIII", directory, 16)
            hash_size, hash_type, platform, page_power = struct.unpack_from(">BBBB", directory, 36)
            algorithm = {1: "sha1", 2: "sha256", 3: "sha256", 4: "sha384"}[hash_type]
            assert hash_size in (20, 32, 48) and page_power <= 20 and 0 < code_limit <= len(image)
            page_size = 1 << page_power
            assert page_count == (code_limit + page_size - 1) // page_size
            for page in range(page_count):
                content = image[page * page_size:min((page + 1) * page_size, code_limit)]
                expected = directory[hash_offset + page * hash_size:hash_offset + (page + 1) * hash_size]
                assert hashlib.new(algorithm, content).digest()[:hash_size] == expected, "Invalid code-page hash"
                verified_pages += 1
            for slot in range(1, special_count + 1):
                expected = directory[hash_offset - slot * hash_size:hash_offset - (slot - 1) * hash_size]
                if slot in embedded:
                    assert hashlib.new(algorithm, embedded[slot]).digest()[:hash_size] == expected, "Invalid special-slot hash"
                else:
                    assert expected == bytes(hash_size), "Unexpected external signature binding"
        results.append({"architecture": "arm64e" if subtype & 0xFFFFFF == 2 else "arm64", "verified_page_hashes": verified_pages})
    assert {row["architecture"] for row in results} == {"arm64", "arm64e"}
    return results


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    package = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "packages/com.chasedavis.chatgptcompat_0.2.0~beta6_iphoneos-arm64e.deb"
    control = archive_members(package, "--ctrl-tarfile")
    assert set(control) == {"control"}, "No maintainer scripts are allowed"
    fields = dict(line.split(": ", 1) for line in control["control"].decode().splitlines() if ": " in line)
    assert fields["Package"] == "com.chasedavis.chatgptcompat"
    assert fields["Version"] == "0.2.0~beta6" and fields["Architecture"] == "iphoneos-arm64e"
    payload = archive_members(package, "--fsys-tarfile")
    dylib = "Library/MobileSubstrate/DynamicLibraries/ChatGPTCompatibility.dylib"
    bundle = "Library/PreferenceBundles/ChatGPTCompatibilityPrefs.bundle/ChatGPTCompatibilityPrefs"
    expected = {dylib, bundle, "Library/MobileSubstrate/DynamicLibraries/ChatGPTCompatibility.plist", "Library/PreferenceBundles/ChatGPTCompatibilityPrefs.bundle/Info.plist", "Library/PreferenceLoader/Preferences/ChatGPTCompatibility.plist"}
    assert set(payload) == expected, "Unexpected installed path or embedded preferences"
    report = {"package": package.name, "sha256": hashlib.sha256(package.read_bytes()).hexdigest(), "payload_files": len(payload), "maintainer_scripts": 0, "binaries": {name: verify_binary(payload[name]) for name in (dylib, bundle)}, "signature_scope": "ldid CodeDirectory hash integrity only; not Apple trust or device loading"}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
