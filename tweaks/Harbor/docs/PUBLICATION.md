# Beta7 full-beta publication

Publication was explicitly authorized after the Focus opt-in audit. This release includes the complete compact/expanded sheet, real-control bridge, live editor, themes, saved profiles, and optional Focus matching. **Physical-device behavior remains unverified. Automatic Focus matching is off until explicitly enabled and saved.**

- Version: `0.1.0~beta7`
- Package: `com.chasedavis.harbor` — Harbor (Beta), free
- Debian architecture: `iphoneos-arm64e`; both binaries include `arm64` and `arm64e`
- Firmware: `>=17.0`, `<17.1`; working RootHide SpringBoard injection, compatible injection runtime and PreferenceLoader required
- Artifact: `repo/debs/com.chasedavis.harbor_0.1.0~beta7_iphoneos-arm64e.deb`
- Size: **117100 bytes**
- SHA-256: `b50e8e050c1f103227af8eb8bdcfae0249c8b44a99de7423118b8cdbe053682b`

Prepared in an isolated checkout of `main` at `231e473e2f3565c9d381e1fab820662d3c8cf8c2`. The original `stayon17` checkout and unrelated stamp are preserved. Only Harbor source/tests/evidence, its package/depiction/previews/catalog entry, Harbor validation and the established generated indexes change. All five unrelated package stanzas and binary hashes remain identical. Beta7 sorts after published beta3; intermediate local betas are included in this complete release.

## Rebuild and package checks

The runtime source files are hash-identical to the candidate covered by 141 UIKit checks and 21 recorded actual-touch assertions. Those tests use fixtures and simulated Focus readers; they are not phone integration tests. The publication rebuild reran the host sanitizer checks: 20 policy, 32 model and 35 Focus coordinator checks passed.

The first rebuild compiled but the local `fakeroot` daemon could not allocate IPC channels. Read-only inspection found the message queue table full; no system queues or other projects were changed. A temporary adapter used the inspected `dm.pl` non-root packaging path. Both binaries rebuilt successfully; each of their four total Mach-O slices matches the tested candidate after ignoring only `LC_UUID` and code-signature blobs. See [binary comparison](beta7/publication/mach-o-comparison.json).

Archive inspection also found the macOS packer retained the builder's numeric uid/gid despite root/wheel names. The release normalizes archive ownership to **uid/gid 0** with `dpkg-deb --root-owner-group` and xz compression. Harbor's build script now performs that normalization, and package validation rejects non-root archive entries. This only changes packaging; the normalized archive preserves the freshly rebuilt binary bytes and all configuration content. This explains why the published checksum differs from the earlier audit candidate's `70d55b6e…` checksum.

[Rebuild log](beta7/publication/release-rebuild.log), [package validation](beta7/publication/package-verification.log), and [pre-push checks](beta7/publication/prepush-validation.json) record the exact release. All six payload files, filter, PreferenceLoader registration, versions, RootHide links and binary architectures pass. No maintainer scripts or added entitlements. Flat and both suites/two architectures retain the established index layout; every compressed format decompresses correctly and all Release checksums validate.

## Deployment and use

The existing [Pages workflow](https://github.com/chasesdavis/repo/actions/workflows/deploy-pages.yml) validates before deployment and compares the public index and Harbor package to its exact commit afterward. This committed record documents preparation; it does not infer deployment success while a run is pending. The final publication report additionally verifies all public index variants, Release files, package and Harbor assets against the exact pushed commit.

Refresh the Sileo source and confirm `0.1.0~beta7`. After an installation chosen by the user, restart SpringBoard through the environment's supported UI and reopen Settings. Edit Harbor through its ellipsis menu. Manual profiles remain available without Focus reads. The separate native Focus shortcut opens Apple's chooser; choosing a mode there can change Focus.

No phone installation, restart or real Focus setting change is part of this publication. Private API behavior, actual system controls, lock-screen behavior and physical-device smoothness remain unverified. See the [Focus audit](BETA7-FOCUS-OPT-IN.md) and [device checklist](DEVICE-TESTING.md).

## Historical beta3 publication

- Version: `0.1.0~beta3`
- Display name: `Harbor (Beta)`
- Package: `com.chasedavis.harbor`
- Debian architecture: `iphoneos-arm64e` (RootHide)
- Mach-O slices: `arm64`, `arm64e`
- Firmware dependency: `>= 17.0`, `< 17.1`
- Size: `49628` bytes
- SHA-256: `dab1172f7602259fc749e5710f30cba376bc6c631184f0124f24074f1a0749fe`

Artifact: `repo/debs/com.chasedavis.harbor_0.1.0~beta3_iphoneos-arm64e.deb`.

Publication was explicitly authorized after the full-screen correction passed local checks. This replaces Harbor beta2 in the current index, updates only Harbor's release page/catalog/preview and validator, and regenerates the established flat and suite indexes. All five unrelated package stanzas and binary hashes remain unchanged. The isolated `main` checkout starts at beta2 commit `1eb125a8e71db81a32fb5c45c61b930606cf6adb`; the original `stayon17` branch and its unrelated work are not merged.

The runtime is the same source covered by the recorded **47/47 simulator/mock-host checks**, including the inset-panel regression, safe areas, native transform inheritance, scrolling, pinned All controls, landscape restoration, and detached-host cleanup. Publishing changes release metadata/assets and indexes, not runtime behavior. Both architectures were rebuilt; the **20 policy assertions**, SDK/schema checks, and exact six-file package verification passed again. All compressed index formats and Release hashes are checked, and Debian orders beta3 after beta2.

The public preview is the explicitly labeled simulator fixture, not the user's original screenshot or a physical-device compatibility claim. The screenshot's installed Harbor version is still unconfirmed. Native gesture arbitration, actual rotation, lock-screen behavior, and other device integration remain unverified.

The existing Pages workflow validates the indexes before upload and then downloads and compares `Packages` and Harbor's `.deb` against the exact release commit. Read the deployment status and commit from the [Actions workflow](https://github.com/chasesdavis/repo/actions/workflows/deploy-pages.yml); this source record describes pre-push validation and does not infer success from a pending deployment. The post-deployment local verification additionally compares all public index variants, Release files, package, and Harbor site assets with the committed bytes.

No phone installation or restart is performed by publication. After upgrading through the RootHide package manager, restart SpringBoard through Bootstrap's supported UI and reopen Settings. Physical-device behavior remains an unverified beta.

## Historical beta2 publication

- Version: `0.1.0~beta2`
- Display name: `Harbor (Beta)`
- Package: `com.chasedavis.harbor`
- Debian architecture: `iphoneos-arm64e` (RootHide)
- Mach-O slices: `arm64`, `arm64e`
- Firmware dependency: `>= 17.0`, `< 17.1`
- Size: `46100` bytes
- SHA-256: `57012100fd2f1b853a68a1ca3363fa64a520c9cbf365d1feed94a8cc192e3c2e`

Artifact: `repo/debs/com.chasedavis.harbor_0.1.0~beta2_iphoneos-arm64e.deb`.

This publication was explicitly authorized after the local repair. It replaces the broken beta1 package in the current index and leaves all five unrelated package stanzas and binary hashes unchanged. The isolated `main` checkout starts at beta1 commit `d2137f515c757e07d837c11d4435f8e9bc6fe252`; the original `stayon17` branch and its work are not merged.

Beta2 corrects the iOS 17 host class, delayed registration, and PreferenceLoader/Preferences metadata, adds runtime diagnostics, and uses the native presentation container. See [BETA2-FIXES.md](BETA2-FIXES.md). The runtime sources are those covered by the recorded 33 UIKit/mock-host checks; publishing changes only release documentation, packaging/index validation, and repository artifacts. The package was rebuilt for both architectures, with 20 sanitizer-backed policy assertions and SDK/schema checks rerun. Package inspection verifies the six-file payload, controller registration, bundle identity, preference defaults, architectures, and RootHide dependencies.

The existing Pages workflow validates the repository before upload, then compares the deployed index and downloadable Harbor package against the exact commit. Read deployment success and the exact published commit from the [Actions workflow](https://github.com/chasesdavis/repo/actions/workflows/deploy-pages.yml); this source record documents pre-push checks and does not infer success from a pending deployment.

Physical-device behavior is still unverified. Publication does not install anything on the phone or certify compatibility. After upgrading, restart SpringBoard through Bootstrap and reopen Settings; see [the activation instructions](../README.md#installation-requirements-and-first-device-test).

## Historical beta1 publication

Version: `0.1.0~beta1`
Display name: `Harbor (Beta)`
Package: `com.chasedavis.harbor`
Debian architecture: `iphoneos-arm64e` (RootHide)
Mach-O slices: `arm64`, `arm64e`
Firmware dependency: `>= 17.0`, `< 17.1`
SHA-256: `d6e40609bb341db11ec706b267862e17146433b22da80982083bfbcb5bea7d4b`

Artifacts:

- Source: `tweaks/Harbor/`
- Package: `repo/debs/com.chasedavis.harbor_0.1.0~beta1_iphoneos-arm64e.deb`
- Sileo depiction: `repo/depiction/harbor/index.html`
- Original icon and simulator preview: `repo/assets/harbor/`
- Source URL: https://chasesdavis.github.io/repo/
- Depiction URL: https://chasesdavis.github.io/repo/depiction/harbor/

Prepared on a clean `main` checkout based on `8e66d1c9d0f6b94e454d253ad2a548810f4d8ac8`. The original `stayon17` checkout and its unrelated work were not merged. All five existing package stanzas and hashes were checked against that base and remain identical; Harbor is the sixth artifact.

The beta changes packaging metadata and the Settings beta label; the runtime implementation is the same one covered by the recorded 29 simulator/mock-host checks. The beta was rebuilt for both architectures, its 20 policy assertions rerun, and its exact package manifest/filter verified. Flat and suite indexes were regenerated with the existing index script. All package hashes and Release checksums passed validation, and every compressed flat index was decompressed and checked.

The Pages workflow now requires Harbor and validates its metadata and repository hashes before upload. After deployment it downloads and compares both the exact `Packages` file and Harbor `.deb` against the commit being deployed. Deployment status and the exact published commit should be read from the [GitHub Actions run](https://github.com/chasesdavis/repo/actions/workflows/deploy-pages.yml), not inferred from this pre-push validation record.

This is an initial beta. Physical-device testing remains pending. No phone installation or restart is part of publication. The depiction and package description explicitly disclose that status.
