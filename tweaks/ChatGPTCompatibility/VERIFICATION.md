# Beta 6 Verification

Date: 2026-10-11. Package: `com.chasedavis.chatgptcompat`, version `0.2.0~beta6`, architecture `iphoneos-arm64e`.

## Passed locally

- 126 policy and runtime-ABI assertions.
- 40 production-adapter integration assertions against a mock installer and hook provider.
- Regression reproduction before the fix: beta 1 inspected a ChatGPT purchase request before its User-Agent existed; attaching `iOS/17.0` afterward reached the next stage unchanged.
- Regression after the fix: beta 2's late-header policy receives the typed ChatGPT purchase dictionary and rewrites the subsequently attached token to `iOS/18.0`; unrelated products, headers, and disabled state remain unchanged.
- Beta 3 regression: iOS 17.0.1 and 17.0.3 pass the device gate; iOS 17.1 remains excluded.
- Beta 4 scope regression: `appstored`, `itunesstored`, and `AppStore` pass the store-process gate; unrelated processes remain excluded.
- Beta 5 UI regression: an exact ChatGPT StoreKitUI item is treated as compatible; unrelated item IDs and bundle IDs preserve the original incompatibility result.
- Beta 6 host regression: `StoreKitUIService` passes the store-process gate while unrelated processes remain excluded.
- Three property-list validations.
- Both tweak and Settings bundle compiled for arm64 and arm64e with minimum OS and SDK 17.0.
- Exact five-file package payload; no maintainer scripts or pre-enabled preference file.
- 192 code-page hash checks across the two binaries, two slices, and their embedded CodeDirectories; two deliberately corrupted binaries were rejected.
- All 63 pre-existing package stanzas preserved byte-for-byte, with their existing package sizes/hashes checked.
- 64 total package records, 30 index-format copies, and 90 Release checksums verified before publication.

## Limits and observed tooling behavior

No phone was connected, installed, modified, restarted, or tested. Daemon injection, the actual App Store refusal path, download, installation, launch, and dot access remain unverified. Tests use synthetic data, not captured account requests.

The existing Theos recipe invokes `ldid -S`. macOS strict `codesign` verification reports the pseudo-signed images as unsigned. The package's embedded CodeDirectory hashes pass the independent verifier; this does not establish device loading or Apple trust. The linker also emits its existing `-multiply_defined is obsolete` toolchain warning. There are no source compile warnings under the selected warning-as-error flags.

Package SHA-256: `be6b8277c28cfdc00e28fe27357a594fcf993be6f9289b2132b7dae25397c637`.

The supplied `com.openai.chat_1.2026.272_und3fined.ipa` was inspected read-only. The main executable, `ChatGPT.framework`, and `OpenAIXPlat.framework` each declare `minos 18.0` in `LC_BUILD_VERSION`; the app executable is arm64. This is evidence that passing the store/installer gate would not establish launch compatibility on iOS 17.

Reproduce source tests with `bash scripts/test.sh`, build with the README command, and verify the resulting archive with `python3 scripts/verify_package.py`. Archive timestamps can change a rebuilt package's SHA-256.
