#!/usr/bin/env python3
"""Packaging/source hygiene checks; not an Objective-C compiler or device test."""
import pathlib
import plistlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
for relative in ("Prefs/Resources/Info.plist", "Prefs/Resources/Root.plist", "layout/Library/PreferenceLoader/Preferences/AxonReborn.plist"):
    plistlib.loads((root / relative).read_bytes())
settings = plistlib.loads((root / "Prefs/Resources/Root.plist").read_bytes())
assert next(x for x in settings["items"] if x.get("key") == "Enabled")["default"] is False
control = (root / "control").read_text()
assert "firmware (>= 15.0), firmware (<< 18.0)" in control
assert "me.nepeta.axon" in control and "preferenceloader" in control
for relative in ("Tweak/AXNRuntime.mm", "Tweak/AXNRailView.m", "Shared/AXNPreferences.m", "Prefs/AXNSettingsController.m"):
    source = (root / relative).read_text()
    assert not re.search(r'@"/(?:var/jb|Library|usr)/', source), relative
    assert "writeToFile:" not in source and "NSURLSession" not in source, relative
for variant, scheme in (("rootful", ""), ("rootless", "rootless"), ("roothide", "roothide")):
    makefile = "include config.mk\n.PHONY: report\nreport:\n\t@echo scheme=$(THEOS_PACKAGE_SCHEME) target=$(TARGET) archs=$(ARCHS)\n"
    output = subprocess.check_output(["make", "--no-print-directory", "-f", "-", "report", f"AXON_VARIANT={variant}"], input=makefile.encode(), cwd=root).decode().strip()
    assert output == f"scheme={scheme} target=iphone:clang:latest:15.0 archs=arm64 arm64e", output
for script in ("build.sh", "test.sh", "test-ui.sh"):
    subprocess.run(["bash", "-n", root / "scripts" / script], check=True)
print("PASS: plist, package variants, deployment target, source hygiene and shell syntax")

for path in (root / "scripts").glob("*.py"):
    compile(path.read_text(), str(path), "exec")
expected = {"Enabled":False, "Compact":False, "ShowCounts":True, "Haptics":True, "Motion":True,
            "TapSelectedToAll":True, "RevealFocus":True, "Accent":0, "Sort":0, "Density":1}
actual = {entry["key"]:entry["default"] for entry in settings["items"] if "key" in entry}
assert actual == expected, (actual, expected)
print("PASS: release script syntax and settings schema alignment")
