# Initial beta publication

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
