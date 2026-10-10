# ChatGPT Compatibility

## Overview
Default-off experimental RootHide tweak for iPhone16,2 on iOS 17.0.x and official ChatGPT 1.2026.272. Beta 3 accepts iOS 17.0 patch releases, while retaining beta 2's late `AMSURLRequest` User-Agent hook and runtime status. Objective-C, Foundation/UIKit, Xcode 26.6 with Apple clang 21.0.0, iOS 17 SDK, RootHide Theos; GNU Make builds an arm64/arm64e Debian package. No dependency downloads.

## Commands
- Setup: `export THEOS=/Users/chase/theos`
- Test: `bash scripts/test.sh`
- Build: `make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide`
- Check package: `python3 scripts/verify_package.py`
- Lint: `plutil -lint ChatGPTCompatibility.plist Preferences/entry.plist Preferences/Resources/Info.plist`
- Dev: edit source, rerun tests, then build; never invoke `make install`.

## Boundaries
- **NEVER** patch ChatGPT files, receipts, signatures, entitlements, account state, or global OS APIs.
- **NEVER** log credentials, request bodies, request headers, app paths, or arbitrary errors. Only fixed hook-status messages are allowed.
- **NEVER** install on the phone, pair it, start services, or restart processes without separate approval.
- **NEVER** edit unrelated tweaks, production workflows, `.env`, secrets, or generated package/index files by hand. Credentials use `<YOUR_VALUE>` placeholders only.
- **ALWAYS** keep the default off, preserve original behavior on missing identity/ABI, and distinguish local tests from device validation.

## Conventions
English-only identifiers and documentation; prefix symbols with `CGC`. Policy code stays host-testable and returns the original input for unsupported cases:
```objc
if (!enabled || !CGCRequestTargetsChatGPT(request)) return request;
```

## Dependencies
Existing Foundation and UIKit SDK frameworks; Preferences for the Settings pane; the installed Substrate-compatible hook provider and PreferenceLoader on RootHide. Python 3.14.6 and the existing `dpkg-deb` verify packaging. No dependency downloads.

## Config
Only `Enabled`, a strict Boolean defaulting to false, in the RootHide-translated `com.chasedavis.chatgptcompat.plist` preferences file. Target store ID, bundle ID, version, device model, and OS are fixed in source.

## Error Handling
Unknown formats, mixed identities, missing metadata, unsupported selectors, and ABI mismatch leave the original request or installer check untouched. Settings write failures surface in an alert. There are no automatic retries, process kills, or network calls initiated by the tweak.

## Troubleshooting
- No Settings entry: verify PreferenceLoader and the RootHide architecture before changing anything.
- Toggle has no effect: daemon injection or the observed transport may not match; absence of effect is not proof of runtime compatibility.
- Update still refused: unsupported request format/UI gate fails closed; do not broaden to process-wide spoofing.
- All runtime statuses show NO: the updated dylib has not loaded into the daemons; a userspace reboot is needed after package upgrade.
- Hooks show YES but request match is NO: the App Store did not traverse the typed ChatGPT purchase path; collect the exact screen/state before changing scope.
- Install succeeds but launch fails: missing iOS 18 APIs are outside this tweak; do not alter signatures or app files.
- Build cannot find SDK: verify the existing `iPhoneOS17.0.sdk` under `$THEOS/sdks`.
