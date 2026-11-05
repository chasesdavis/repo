#!/usr/bin/env python3
"""Validate integration contracts against Theos's format and the actual iOS 17 SDK.

This catches syntactically valid plists and mock-host interfaces that cannot load
on the target system. It does not claim to execute PreferenceLoader or SpringBoard.
"""
import argparse
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--package-root", type=Path)
parser.add_argument("--sdk", type=Path, default=Path(os.environ.get("THEOS", "/Users/chase/theos")) / "sdks/iPhoneOS17.0.sdk")
args = parser.parse_args()
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def plist(path):
    # plutil also reads the OpenStep syntax used by Theos's loader entry.
    return plistlib.loads(subprocess.check_output(["plutil", "-convert", "xml1", "-o", "-", str(path)]))


if args.package_root:
    bundle = args.package_root / "Library/PreferenceBundles/HarborPrefs.bundle"
    entry_path = args.package_root / "Library/PreferenceLoader/Preferences/Harbor.plist"
    root_path, info_path = bundle / "Root.plist", bundle / "Info.plist"
    check((bundle / "HarborPrefs").is_file(), "Preference bundle executable is missing")
else:
    entry_path = args.source / "Prefs/entry.plist"
    root_path = args.source / "Prefs/Resources/Root.plist"
    info_path = args.source / "Prefs/Resources/Info.plist"

entry = plist(entry_path).get("entry", {})
info = plist(info_path)
check(entry.get("isController") in (True, 1, "1"), "PreferenceLoader entry needs isController=true to load the custom controller")
check(entry.get("bundle") == info.get("CFBundleExecutable") == "HarborPrefs", "PreferenceLoader bundle name must match the executable")
check(entry.get("detail") == info.get("NSPrincipalClass") == "HBPreferencesController", "PreferenceLoader detail must match NSPrincipalClass")
root = plist(root_path)
check(isinstance(root, dict) and isinstance(root.get("items"), list), "Root.plist must be a dictionary containing the Preferences items array")
if isinstance(root, dict) and isinstance(root.get("items"), list):
    switches = {item.get("key"): item for item in root["items"] if isinstance(item, dict) and item.get("key")}
    check(set(switches) == {"enabled", "haptics"}, "Settings must contain the expected preference keys")
    check(all(item.get("defaults") == "com.chasedavis.harbor" for item in switches.values()), "Settings defaults domain must match the tweak")
    check(switches.get("enabled", {}).get("default") is True, "Harbor must be enabled by default")

if not args.package_root:
    exports_path = args.sdk / "System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI.tbd"
    exports = exports_path.read_text()
    source = (args.source / "Tweak.xm").read_text()
    hosts = set(re.findall(r"%hook\s+(\w+)", source))
    check(bool(hosts), "No Control Center hook targets found")
    for host in hosts:
        check(bool(re.search(r"\b" + re.escape(host) + r"\b", exports)), f"Hook target {host} is absent from the iOS 17.0 ControlCenterUI exports")
        check(f'NSClassFromString(@"{host}")' in source, f"Hook target {host} is not resolved by name")
    focus_exports = (args.sdk / "System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb.tbd").read_text()
    for focus_class in ("DNDStateService", "DNDState", "DNDModeConfigurationService"):
        check(bool(re.search(r"\b" + focus_class + r"\b", focus_exports)), f"Focus class {focus_class} is absent from iOS 17.0 exports")
    version_header = args.source / "HBVersion.h"
    if version_header.exists():
        version = re.search(r"^Version: (.+)$", (args.source / "control").read_text(), re.M).group(1)
        check(f'"{version}"' in version_header.read_text(), "Runtime diagnostic version must match the package version")

if errors:
    print("\n".join("FAIL: " + error for error in errors))
    sys.exit(1)
print("PASS: PreferenceLoader controller registration, Preferences schema, bundle identity, and defaults")
if not args.package_root:
    print("PASS: hook and optional Focus classes exist in the installed iOS 17.0 SDK exports")
