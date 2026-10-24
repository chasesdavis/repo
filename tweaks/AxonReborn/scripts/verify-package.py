#!/usr/bin/env python3
"""Inspect package metadata, install layout and both Mach-O slices without executing payloads."""
import hashlib, io, json, pathlib, plistlib, struct, subprocess, sys, tarfile

def fields(text):
    result = {}
    for line in text.splitlines():
        if line.startswith((" ", "\t")):
            continue
        if ": " in line:
            key, value = line.split(": ", 1)
            result[key] = value
    return result

def macho(data):
    magic = data[:4]
    if magic in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        count = struct.unpack_from(">I", data, 4)[0]
        assert 0 < count <= 8, "invalid fat binary"
        result = []
        for i in range(count):
            if magic == b"\xca\xfe\xba\xbe":
                cpu, subtype, offset, size, align = struct.unpack_from(">iiIII", data, 8 + i * 20)
            else:
                cpu, subtype, offset, size, align, reserved = struct.unpack_from(">iiQQII", data, 8 + i * 32)
            assert offset + size <= len(data)
            result.extend(macho(data[offset:offset + size]))
        return result
    assert magic == b"\xcf\xfa\xed\xfe", "expected little-endian 64-bit Mach-O"
    _, cpu, subtype, filetype, count, size, flags, reserved = struct.unpack_from("<IiiIIIII", data)
    assert count <= 1024 and 32 + size <= len(data)
    cursor, dylibs = 32, []
    for _ in range(count):
        command, length = struct.unpack_from("<II", data, cursor)
        assert length >= 8 and cursor + length <= 32 + size
        if command in (0xc, 0x80000018, 0x8000001f, 0x20, 0x80000023):
            name_offset = struct.unpack_from("<I", data, cursor + 8)[0]
            assert 12 <= name_offset < length
            dylibs.append(data[cursor + name_offset:cursor + length].split(b"\0", 1)[0].decode())
        cursor += length
    return [{"cpu":cpu, "subtype":subtype & 0xffffff, "dylibs":dylibs}]

def verify(package, variant):
    package = pathlib.Path(package)
    metadata = fields(subprocess.check_output(["dpkg-deb", "-f", str(package)], text=True))
    source = fields((pathlib.Path(__file__).resolve().parents[1] / "control").read_text())
    assert metadata["Package"] == source["Package"] == "com.chasesdavis.axonreborn"
    assert metadata["Version"] == source["Version"]
    assert metadata["Architecture"] == {"rootful":"iphoneos-arm", "rootless":"iphoneos-arm64", "roothide":"iphoneos-arm64e"}[variant]
    assert "firmware (>= 15.0)" in metadata["Depends"] and "firmware (<< 18.0)" in metadata["Depends"]
    prefix = "var/jb/" if variant == "rootless" else ""
    expected = {prefix + name for name in (
        "Library/MobileSubstrate/DynamicLibraries/AxonReborn.dylib",
        "Library/MobileSubstrate/DynamicLibraries/AxonReborn.plist",
        "Library/PreferenceBundles/AxonRebornPrefs.bundle/AxonRebornPrefs",
        "Library/PreferenceBundles/AxonRebornPrefs.bundle/Info.plist",
        "Library/PreferenceBundles/AxonRebornPrefs.bundle/Root.plist",
        "Library/PreferenceLoader/Preferences/AxonReborn.plist")}
    archive = subprocess.check_output(["dpkg-deb", "--fsys-tarfile", str(package)])
    files = {}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for member in tar:
            name = member.name.removeprefix("./").rstrip("/")
            assert not name.startswith("/") and ".." not in pathlib.PurePosixPath(name).parts
            assert member.isdir() or member.isfile(), "unexpected symlink/special payload"
            if member.isfile():
                assert name not in files and member.size < 8_000_000
                files[name] = tar.extractfile(member).read()
    assert set(files) == expected, f"unexpected install layout: {set(files) ^ expected}"
    for name, data in files.items():
        if name.endswith(".plist"):
            plistlib.loads(data)
    settings = plistlib.loads(files[prefix + "Library/PreferenceBundles/AxonRebornPrefs.bundle/Root.plist"])
    assert next(x for x in settings["items"] if x.get("key") == "Enabled")["default"] is False
    binaries = {}
    for name, data in files.items():
        if name.endswith(".plist"): continue
        slices = macho(data)
        assert {(s["cpu"], s["subtype"]) for s in slices} == {(16777228, 0), (16777228, 2)}
        for item in slices:
            dylibs = item["dylibs"]
            assert not any("/Users/" in x or "/workspace/" in x or "/.axon-theos/" in x for x in dylibs)
            if name.endswith(".dylib"):
                substrate = [x for x in dylibs if "substrate" in x.lower()]
                assert substrate, "missing hook runtime"
                if variant == "roothide":
                    assert substrate == ["@loader_path/.jbroot/usr/lib/libsubstrate.dylib"]
                if variant == "rootless":
                    assert all(x.startswith("/var/jb/") or x.startswith("@rpath/") for x in substrate)
                if variant == "rootful":
                    assert all(not x.startswith("/var/jb/") and ".jbroot" not in x for x in substrate)
        binaries[name] = slices
    return {"package":package.name, "variant":variant, "version":metadata["Version"],
            "bytes":package.stat().st_size, "sha256":hashlib.sha256(package.read_bytes()).hexdigest(),
            "binaries":binaries}

if __name__ == "__main__":
    assert len(sys.argv) == 3, "verify-package.py package.deb variant"
    print(json.dumps(verify(sys.argv[1], sys.argv[2]), indent=2))
