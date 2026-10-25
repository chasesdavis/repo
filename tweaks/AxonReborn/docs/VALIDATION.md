# Validation record — October 24, 2026

## Current beta2 release
- Source: `ac6bf4fdfd8fec35cdf4dc9eff9501135aca64ac`; [build 40146059731](https://github.com/chasesdavis/repo/actions/runs/40146059731), all five jobs passed.
- RootHide publication: `beb5f19d78e2975ab3b73875c728a2fce0d92bd7`; Pages verified all 34 public package/index files.
- Package: `com.chasesdavis.axonreborn_0.2.0~beta2_iphoneos-arm64e.deb`, 93858 bytes.
- SHA256: `4eac64d0c24e4d27f286b796d180fb05ca62f19486688c544a6e183759827eb0`.
- Native UIKit tests passed: no capsule spring/pulse/scroll animation, equal-height horizontal spacing, ShowAll on/off, accessible clear action and end-of-row viewport retention.
- Runtime tests passed: one-app native clear dispatch, exact current request identities, preserved post-confirmation arrivals, right/left neighbor selection, newly arrived neighbors, manual-selection priority, native rejection and inactive-controller guards. Existing filtering, Focus authentication and recovery tests remain green.
- Rootful, rootless and RootHide package builds and metadata/install/Mach-O inspection passed. Only RootHide is published to this Sileo feed.
- Physical beta1 feedback reported choppy motion and taller modes crossing the clock. Beta2 removes those capsule effects and vertical size differences. Beta2 physical-device verification is still pending; see [BETA2.md](BETA2.md).


## Beta1 baseline
- Version: **0.2.0~beta1**.
- Source commit: `a8f195011fcb45038073ac2f627d96a83c51533f`.
- [Build 40138163664](https://github.com/chasesdavis/repo/actions/runs/40138163664): **all five jobs passed**.
- Publication commit: `8a7dadaf8db71255ea1830f38bfe88111526db1b`.
- [Pages deployment 40138903642](https://github.com/chasesdavis/repo/actions/runs/40138903642): deployment and public-byte verification passed.
- RootHide feed: https://chasesdavis.github.io/repo/
- Package: `com.chasesdavis.axonreborn_0.2.0~beta1_iphoneos-arm64e.deb`.
- Package size: **86812 bytes**.
- SHA256: `61fb1e5a03c415c7adcf81cce5850e482eddfdf63cad173fbc30ae590db027c5`.

Only the RootHide package is published to this feed. Rootful and rootless packages are available as separate artifacts in the same build. These are three successful package builds, not three certified device environments.

## Automated gates
| Gate | Observed result |
|---|---|
| Portable request index | Passed edge cases and 20,000 seeded randomized notification events against a reference model |
| Selector inset lifecycle | Passed native rewrites/restoration and 10,000 layout passes |
| Source/package checks | Passed plist parsing, three package configurations, deployment bounds, source hygiene, shell/release-script syntax and settings schema alignment |
| Preference schema | Passed malformed values, enum bounds, favorite sanitization/capacity, cache reload and reset isolation |
| Capsule interaction | Passed held-touch preservation, scroll-update coalescing, latest pending state and surviving button identity |
| Accessibility actions | Passed actual VoiceOver pin/unpin, favorite reorder and Show All handlers |
| Adaptive layout | Passed Slim/Balanced/Roomy actual capsule heights; Large, XXXL and largest accessibility text at widths 320, 375 and 430; label vertical bounds and minimum target height |
| Runtime ownership/recovery | Passed restore-before-snapshot controller handoff, shared native state fixture, missing-mount restoration and oversized snapshot rejection |
| Native behavior contracts | Passed app filtering, tap-again reset, arrivals, reveal state, authentication-denied/authorized Focus expansion, native policy preservation, identity checks, rollback and report privacy |
| Native mount regression | Passed bottom-alignment gap, short/long selection positioning, active gesture preservation, alignment/inset restoration, resolver guards and diagnostic correlation |
| Package inspection | Passed rootful, rootless and RootHide metadata, firmware bounds, payload/install paths, arm64/arm64e slices and Mach-O dependency checks |
| Publication | All 34 public package/index files matched the staged manifest exactly |

The native tests ran against public UIKit plus test doubles for Apple's private notification objects. They verify the adapter's contracts and reproduced geometry, not the implementation of SpringBoard on iOS 17.0. The balanced-density synthetic capsule render from the final successful run was visually inspected. Large-text geometry was asserted; it was not visually certified on the phone.

The build artifacts are `axon-alpha-rootful`, `axon-alpha-rootless`, `axon-alpha-roothide` (legacy artifact names) and `axon-verified-release`. The verified payload records source, build ID, bytes and hashes. Before publication, all 11 unique Git blob hashes and the package SHA256 were independently rechecked; no mismatch remained. Existing package entries, including alpha11, were preserved.

## Defects found and corrected during validation
- Corrected the UIButton touch-end override to `endTrackingWithTouch:withEvent:`.
- Fixed a layout bug where the heading stack absorbed additional accessibility height, leaving capsules too short for their scaled fonts. A shared required header-height constraint now reserves the correct space.
- Restored the previous controller's rules before the replacement controller snapshots shared native state.
- Removed a supplementary large-text image capture that stalled the simulator test harness; retained all large-text assertions and added stage diagnostics plus a 45-second watchdog. The final suite completed successfully.

## Device gates — not completed
The primary target is the user's iOS 17.0 RootHide Bootstrap phone. Record model, full OS build, Bootstrap version and injection configuration in [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md). No beta1 physical-device pass, authentication observation, performance measurement or overnight soak has been recorded.

Run the physical matrix in [PREMIUM_RELEASE_PLAN.md](PREMIUM_RELEASE_PLAN.md): selection, arrivals/dismissals, Focus and authentication, native actions, presentation styles, accessibility, upgrades/recovery, repeated presentations and overnight/performance testing. Additional iOS 15/16 and package environments require their own results before advertising support. Metadata remains limited to iOS 15–17; no iOS 18–27 compatibility claim is made.

## Release decision
**Published beta candidate; stable 1.0 blocked by physical acceptance and compatibility evidence.** All available automated gates passed. “100% flawless” is not a testable or demonstrated guarantee. Do not mark the remaining device checklist complete from build or simulator results.
