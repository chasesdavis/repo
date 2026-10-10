# ChatGPT Compatibility Settings

## Overview
Settings component of ChatGPT Compatibility. Objective-C/UIKit/Preferences, Xcode 26.6, Apple clang 21.0.0, iOS 17 SDK, RootHide Theos and GNU Make. No separate dependency installation or package release.

## Commands
- Setup: `export THEOS=/Users/chase/theos`
- Test from here: `cd .. && bash scripts/test.sh`
- Build from here: `cd .. && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide`
- Lint: `plutil -lint entry.plist Resources/Info.plist`
- Dev: rebuild the parent package; never run an install target.

## Boundaries
- **NEVER** enable by default, restart processes, or trigger an App Store update.
- **NEVER** touch secrets, `.env`, production config, app bundles, or generated binaries. Use `<YOUR_VALUE>` for credential placeholders.
- **ALWAYS** disclose that device compatibility and dot access are unverified.

## Conventions
Use the shared strict-Boolean reader and RootHide-translated preferences path:
```objc
return @(CGCPreferencesEnabled(preferences));
```
English-only strings and identifiers; all settings use the `CGC` prefix.

## Dependencies
Foundation/UIKit from the iOS 17 SDK, the Preferences private framework, and PreferenceLoader on the phone. No downloads.

## Config
The only persisted key is Boolean `Enabled`; absent, invalid, and false values disable the experiment. Read-only Darwin notification states report daemon load, hook registration, and matching operations without storing request data.

## Error Handling
An unsuccessful preference write shows an alert, reloads the switch, and sends no settings-change notification. No error payload or private data is logged.

## Troubleshooting
- No Settings entry: check PreferenceLoader and RootHide package architecture.
- Save fails: verify access to this package's translated preferences path, not system-wide settings.
- No effect after saving: daemon loading and the actual request path remain device-validation requirements.
- Runtime status remains NO after upgrading: perform one Bootstrap userspace reboot so the updated daemon dylib can load, then refresh this page.
