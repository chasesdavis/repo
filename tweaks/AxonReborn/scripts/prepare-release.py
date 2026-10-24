#!/usr/bin/env python3
"""Stage a RootHide candidate and exact GitHub blob payload; never push or mutate the live repo."""
import base64, bz2, datetime, email.utils, gzip, hashlib, importlib.util, json, lzma, os, pathlib, subprocess, sys
root = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("verify_package", pathlib.Path(__file__).with_name("verify-package.py"))
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
artifact = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
packages = list(artifact.rglob("*.deb"))
assert len(packages) == 1, "expected exactly one RootHide package"
package = packages[0]
verification = module.verify(package, "roothide")
control = subprocess.check_output(["dpkg-deb", "-f", str(package)], text=True).rstrip()
metadata = module.fields(control)
subprocess.run(["dpkg", "--compare-versions", metadata["Version"], "gt", "0.1.0~alpha11"], check=True)
before = (root / "repo/Packages").read_bytes()
assert b"\r" not in before
def gitsha(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
for stanza in before.decode().strip().split("\n\n"):
    values = module.fields(stanza)
    assert not all(values.get(k) == metadata[k] for k in ("Package", "Version", "Architecture")), "version already published"
data = package.read_bytes()
filename = "debs/" + package.name
new_stanza = control + "\nFilename: " + filename + "\nSize: " + str(len(data)) + "\n"
for field, algorithm in (("MD5sum","md5"), ("SHA1","sha1"), ("SHA256","sha256")):
    new_stanza += field + ": " + hashlib.new(algorithm, data).hexdigest() + "\n"
index = before.rstrip(b"\n") + b"\n\n" + new_stanza.encode() + b"\n"
files = {"repo/" + filename:data}
indexes = {"Packages":index, "Packages.gz":gzip.compress(index, mtime=0),
    "Packages.bz2":bz2.compress(index), "Packages.xz":lzma.compress(index),
    "Packages.lzma":lzma.compress(index, format=lzma.FORMAT_ALONE),
    "Packages.zst":subprocess.check_output(["zstd", "-q", "-19", "-c"], input=index)}
stamp = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc), usegmt=True)
def release(relative, payloads):
    text = (root / relative).read_text().split("MD5Sum:",1)[0]
    text = "\n".join("Date: " + stamp if line.startswith("Date:") else line for line in text.splitlines()) + "\n"
    for title, algorithm in (("MD5Sum","md5"), ("SHA1","sha1"), ("SHA256","sha256")):
        text += title + ":\n"
        for path, content in payloads.items():
            text += f" {hashlib.new(algorithm,content).hexdigest()} {len(content):16} {path}\n"
    return text.encode()
for name, content in indexes.items():
    files["repo/" + name] = content
files["repo/Release"] = release("repo/Release", indexes)
for suite in ("stable", "ios17"):
    payloads = {}
    for arch in ("iphoneos-arm64", "iphoneos-arm64e"):
        for name, content in indexes.items():
            relative = f"main/binary-{arch}/{name}"
            files[f"repo/dists/{suite}/{relative}"] = content
            payloads[relative] = content
    path = f"repo/dists/{suite}/Release"
    files[path] = release(path, payloads)
# Preserve all prior stanzas and verify every compressed representation.
assert index.startswith(before.rstrip(b"\n") + b"\n\n")
assert gzip.decompress(indexes["Packages.gz"]) == index
assert bz2.decompress(indexes["Packages.bz2"]) == index
assert lzma.decompress(indexes["Packages.xz"]) == index
assert lzma.decompress(indexes["Packages.lzma"]) == index
assert subprocess.check_output(["zstd","-q","-d","-c"], input=indexes["Packages.zst"]) == index
entries, blobs, manifest = [], {}, []
for path, content in sorted(files.items()):
    target = output / path; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(content)
    sha = gitsha(content)
    entries.append({"path":path,"mode":"100644","type":"blob","sha":sha})
    blobs[sha] = base64.b64encode(content).decode()
    manifest.append({"path":path,"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest()})
release_manifest = {"version":metadata["Version"], "source_commit":os.environ["GITHUB_SHA"],
    "build_run":int(os.environ["GITHUB_RUN_ID"]), "files":manifest}
manifest_data = (json.dumps(release_manifest, indent=2) + "\n").encode()
manifest_path = "repo/axon-reborn-release.json"
(output / manifest_path).write_bytes(manifest_data)
manifest_sha = gitsha(manifest_data)
entries.append({"path":manifest_path,"mode":"100644","type":"blob","sha":manifest_sha})
blobs[manifest_sha] = base64.b64encode(manifest_data).decode()
payload = {"source_commit":os.environ["GITHUB_SHA"],"build_run":int(os.environ["GITHUB_RUN_ID"]),
    "base_packages_sha":gitsha(before),"verification":verification,"entries":entries,"blobs":blobs,"manifest":manifest}
(output / "release-payload.json").write_text(json.dumps(payload))
# The log contains distributable package bytes, never a token or user/device data.
print("AXN_RELEASE_META:" + json.dumps({k:v for k,v in payload.items() if k != "blobs"}))
for sha, content in blobs.items():
    print("AXN_RELEASE_BLOB:" + json.dumps({"sha":sha,"content":content}))
print("AXN_RELEASE_PAYLOAD_PASS")
