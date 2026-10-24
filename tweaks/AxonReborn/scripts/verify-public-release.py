#!/usr/bin/env python3
"""Confirm the deployed Axon candidate bytes match its checked-in manifest."""
from concurrent.futures import ThreadPoolExecutor
import hashlib, json, pathlib, time, urllib.request
root = pathlib.Path(__file__).resolve().parents[3]
manifest_path = root / "repo/axon-reborn-release.json"
if not manifest_path.exists():
    print("No Axon release manifest in this commit; no candidate to verify.")
    raise SystemExit(0)
manifest = json.loads(manifest_path.read_text())
def check(entry):
    path = entry["path"]
    assert path.startswith("repo/") and ".." not in pathlib.PurePosixPath(path).parts
    expected = (root / path).read_bytes()
    assert hashlib.sha256(expected).hexdigest() == entry["sha256"]
    url = "https://chasesdavis.github.io/repo/" + path.removeprefix("repo/")
    url += "?axon-verify=" + manifest["source_commit"] + "-" + str(int(time.time()))
    with urllib.request.urlopen(url, timeout=20) as response:
        actual = response.read()
    assert actual == expected, "public content mismatch: " + path
    return path
for attempt in range(6):
    try:
        with ThreadPoolExecutor(max_workers=5) as executor:
            checked = list(executor.map(check, manifest["files"]))
        print("AXN_PUBLIC_RELEASE_PASS: " + manifest["version"] + " — " + str(len(checked)) + " package/index files match")
        break
    except Exception as error:
        if attempt == 5: raise
        print("Waiting for Pages propagation: " + str(error), flush=True)
        time.sleep(10)
