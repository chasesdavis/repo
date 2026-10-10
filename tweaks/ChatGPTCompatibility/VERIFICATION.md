# Beta 1 Verification

Date: 2026-10-10. Package: `com.chasedavis.chatgptcompat`, version `0.1.0~beta1`, architecture `iphoneos-arm64e`.

## Passed locally

- 116 policy and runtime-ABI assertions.
- 33 production-adapter integration assertions against a mock installer and hook provider.
- Three property-list validations.
- Both tweak and Settings bundle compiled for arm64 and arm64e with minimum OS and SDK 17.0.
- Exact five-file package payload; no maintainer scripts or pre-enabled preference file.
- 192 code-page hash checks across the two binaries, two slices, and their embedded CodeDirectories; two deliberately corrupted binaries were rejected.
- All 58 pre-existing package stanzas preserved byte-for-byte, with their existing package sizes/hashes checked.
- 59 total package records, 30 index-format copies, and 90 Release checksums verified before publication.

## Limits and observed tooling behavior

No phone was connected, installed, modified, restarted, or tested. Daemon injection, the actual App Store refusal path, download, installation, launch, and dot access remain unverified. Tests use synthetic data, not captured account requests.

The existing Theos recipe invokes `ldid -S`. macOS strict `codesign` verification reports the pseudo-signed images as unsigned. The package's embedded CodeDirectory hashes pass the independent verifier; this does not establish device loading or Apple trust. The linker also emits its existing `-multiply_defined is obsolete` toolchain warning. There are no source compile warnings under the selected warning-as-error flags.

Package SHA-256: `8766aa4cf678dfe1dce3eea2e0b0a444ef0b515090b063a5fa435aa8e004634d`.

Reproduce source tests with `bash scripts/test.sh`, build with the README command, and verify the resulting archive with `python3 scripts/verify_package.py`. Archive timestamps can change a rebuilt package's SHA-256.
