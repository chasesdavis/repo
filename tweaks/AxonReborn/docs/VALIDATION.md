# Validation record — October 23, 2026

First intended device: user's iOS 17 phone running RootHide Bootstrap. No device connection was available in this workspace. Exact OS build, device model, Bootstrap version and SpringBoard injection setting remain to be recorded.

| Check | Result |
|---|---|
| Portable C++17 index, warnings treated as errors | Passed |
| Duplicate/update/removal/selection edge cases | Passed |
| 20,000 seeded randomized events compared to a reference model | Passed |
| Rootful, rootless, RootHide Makefile configuration evaluation | Passed |
| XML settings, bundle Info.plist and PreferenceLoader entry parsing | Passed |
| Package firmware bounds, expected conflicts, disabled default | Passed |
| Shell syntax and source hygiene checks | Passed |
| Manual build workflow YAML parsing | Passed; workflow not executed |
| Chromium sample filtering, arrival, privacy toggle, empty state and reset | Passed |
| Compact/count controls and app ordering in the preview | Passed |
| Page overflow checks at 1440, 1024, 768, 390 and 320 px | Passed |
| Desktop and mobile visual inspection | Completed |
| Native Objective-C++/UIKit compilation | NOT RUN: no Xcode/iOS SDK toolchain available |
| Native `.deb` packaging and binary inspection | NOT RUN |
| SpringBoard hooks, privacy and native notification lifecycle | NOT RUN |
| RootHide installation, Settings injection and shared preferences | NOT RUN |

No `.deb` was generated and nothing was installed on a device. The source is being added under `tweaks/AxonReborn` in `chasesdavis/repo`, with the manual build workflow at the repository root. The included source and workflow are a reviewable experimental starting point, not certified compatibility.
