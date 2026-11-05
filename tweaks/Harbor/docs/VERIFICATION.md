# Verification — 2026-11-05

## Latest validated beta: beta7

See [BETA7-FOCUS-OPT-IN.md](BETA7-FOCUS-OPT-IN.md). The beta6 audit found the automatic matching flag did not stop the reader. Beta7 requires fresh saved opt-in, creates no reader while off, cancels pending work on disable, and retains manual profiles. The package/source audit found no Focus-setting writes or activation calls; native Focus presentation remains separate and device behavior is unverified. Host checks (20 policy, 32 model, 35 coordinator), 141 UIKit checks and 21 recorded HID assertions passed. The totals overlap. Actual-touch tests substituted counted readers and did not call real Focus services. The local package built and validated; no publication, phone installation or real Focus status changes were performed during that audit. The subsequently authorized publication is recorded in [PUBLICATION.md](PUBLICATION.md).

## Beta3 full-screen correction and authorized publication

See [BETA3-FULLSCREEN.md](BETA3-FULLSCREEN.md). The actual submitted JPEG was materialized and visually inspected on the Mac. Its installed Harbor version remains unconfirmed. Independently, published beta2 reproduced the inset/cut-off layout and failed nine assertions in a 43-check screenshot-shaped fixture. The corrected source passes all 47 checks in the expanded fixture, including native transform inheritance, scroll offsets, safe areas, pinned native escape, landscape return, and detached-host cleanup. Both architectures and package/schema checks pass. Publication was subsequently authorized; [PUBLICATION.md](PUBLICATION.md) records its checks. Device gesture arbitration and lock-screen behavior remain unverified, and no phone installation was performed.

## Beta2 repair and authorized publication

The results below describe the initial beta1 work. They did not validate the real host class or the Preferences schema and missed three shipping integration defects. Read [BETA2-FIXES.md](BETA2-FIXES.md) for the correction and current evidence. Beta2 has 20 passing host policy assertions and 33 passing UIKit/mock-host assertions; semantic metadata and iOS 17 SDK class checks now also pass. No physical-device validation has been performed by this workflow.

## Completed

- RootHide Theos release package built against the locally installed iPhoneOS 17.0 SDK. Both tweak and Settings bundle compiled and linked for arm64 and arm64e.
- Twenty host policy assertions passed with AddressSanitizer and UndefinedBehaviorSanitizer. Covers supported/unsupported OS, master switch, iPad/landscape, narrow/invalid dimensions, changed hierarchy, native-mode persistence, expanded modules, invalid brightness values, and allowed media command IDs.
- Twenty-nine UIKit/mock-host checks passed on the **iOS 17.5 iPhone 15 Pro Simulator**. Covers parent/child containment, original hidden-state restoration, missing native hierarchy, expanded modules, enable/disable, native handoff and reopening, actual discovered fixture module identifiers, stopping timers, empty/playing media states, invalid palettes, and geometry.
- Long-title layouts tested at 300, 320, 375, and 430 point widths. No ambiguous layout found; All controls remains scroll-reachable. Accessibility text changes level cards to a vertical arrangement.
- The screenshot renders the shipping UIKit view controller, not an HTML approximation. The music and artwork are explicitly labeled fixtures. Simulator hardware volume is unavailable, so the fallback is shown.
- Package manifest, bundle/filter plists, both Mach-O architectures, and RootHide loader paths inspected. MediaRemote is dynamically resolved and is not a hard link dependency. No install scripts or unrelated payload files.

Evidence: `simulator-results.json`, `build.log`, `package-verification.txt`, `preview-iphone15pro.png`, and `preview-accessibility-empty.png` in this directory.

The build emits the existing Theos/Apple-linker warning `-multiply_defined is obsolete`. Restricted-shell builds also report an unavailable CPU-count `sysctl`; compilation and packaging still succeed. No source compilation errors remain.

## Not established by these tests

The simulator harness supplies an explicit mock of the private Control Center host. It does **not** execute Logos hooks against real SpringBoard. Passing mock tests establishes Harbor's own UI and restoration logic, not the availability or semantics of Apple's private APIs on the phone.

The original implementation did not install anything on the phone. The subsequently authorized 0.1.0~beta1 publication adds a Sileo package and regenerates the repo indexes; it does not establish device compatibility. Exact iOS 17.0 hardware compatibility, injection environment, native presentation gestures, system brightness/volume changes, live media and AirPlay, lock-screen behavior, preference injection, and interaction with existing tweaks remain pending in `DEVICE-TESTING.md`.

## Repository context

Read the repository `AGENTS.md`, existing Lumen/StayOn17 packaging, and the local Theos/iOS17 RootHide skill and robust-coding/verification protocols. The local Codex memory search found no matching Axon/jailbreak memory records. Motion follows the supplied Axon preference: short, restrained, interruptible, no overshoot.

The pre-existing untracked `tweaks/StayOn17/.stamp` is preserved. Implementation deliverables live under `tweaks/Harbor`. The authorized beta publication additionally adds only Harbor's package, depiction/assets, build/validation scripts, and the necessary index/Pages updates. See `PUBLICATION.md` for the publication validation scope.

## Beta4 compact sheet candidate

See [BETA4-COMPACT.md](BETA4-COMPACT.md) and [simulator-results-beta4.json](simulator-results-beta4.json). Earlier programmatic scroll reachability did not test real gesture arbitration. Beta4 adds a competing-pan fixture driven by actual HID swipes, native-button action forwarding checks and compact/expanded layout tests. Physical-device behavior remains unverified; beta4 has not been published or installed on a phone.

## Beta5 profiles, editor and themes

See [BETA5-PROFILES.md](BETA5-PROFILES.md) and [beta5 evidence](beta5/interaction-validation.json). Final run: 93 UIKit checks, 20 C policy checks, 23 Foundation profile checks, and 14 assertions against captured actual input results passed. RootHide package builds and validates. Real simulator Focus service reports BSServiceConnectionErrorDomain (3); real SpringBoard Focus and phone behavior remain unverified. No publication or device installation.
