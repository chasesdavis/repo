# Validation record — October 24, 2026

## Current candidate
Version: 0.2.0~beta1. Implementation and tests are being committed; candidate results will be updated from the actual build, artifact inspection and deployment. No beta1 check is marked passed before execution.

## Established baseline
Alpha11 source cb233b186a2be94bfcc3a4d0d7f06f349def1c26:
- [Build 40131980274](https://github.com/chasesdavis/repo/actions/runs/40131980274): rootful, rootless and RootHide passed.
- Portable C++ index (20,000 seeded events) and inset lifecycle checks passed.
- Native runtime contract and public UIKit tests passed.
- RootHide package inspected and published; SHA256 6dcdbf3777b39dbd856eacf62b7cdb4fd0745b78dec8c7eb90069f83e3ec7242.
- Public package and all tested Sileo indexes matched the prepared bytes.
- Synthetic capsule preview visually inspected. This is not a SpringBoard screenshot.
- Tester reported improvement after alpha10. Alpha11's new Focus and capsule features have no completed physical acceptance record.

## Beta1 automated gates
| Gate | Evidence/status |
|---|---|
| Portable state and inset tests | Pending candidate build |
| Settings schema and corrupt-value handling | Pending simulator |
| Touch/deceleration update coalescing | Pending simulator fixture |
| VoiceOver action handlers and favorite reorder | Pending simulator |
| Densities, local Dynamic Type and narrow widths | Pending simulator |
| Controller handoff and missing-mount restore | Pending runtime contract tests |
| Focus authentication and native-policy preservation | Existing tests retained; candidate rerun pending |
| Three package variants and Mach-O inspection | Pending build |
| RootHide package, indexes and deployed hashes | Pending publication |

## Device gates — not completed
The primary target is the user's iOS 17.0 RootHide Bootstrap phone. Record its model, full OS build, Bootstrap version and injection configuration before the acceptance run. A simulator fixture cannot certify Apple's private layout/model.

Run the physical matrix in [PREMIUM_RELEASE_PLAN.md](PREMIUM_RELEASE_PLAN.md): selection, arrivals/dismissals, Focus and authentication, native actions, presentation styles, accessibility, upgrades/recovery, repeated presentations and overnight/performance testing. Additional iOS 15/16 and package environments require their own results before advertising support.

## Release decision
Beta candidate publication is permitted after automated validation. Stable 1.0 is blocked until the primary-device acceptance, performance/soak and advertised compatibility checks have actual recorded results. “100% flawless” is not a testable or demonstrated guarantee.
