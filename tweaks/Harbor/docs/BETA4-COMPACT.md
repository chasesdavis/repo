# Beta4: compact controls and real touch arbitration

Local candidate built on 2026-11-05 UTC. Not published or installed on a phone. This supersedes beta3’s layout claims; earlier programmatic scrolling checks did not exercise native gesture competition.

## Screenshot and reference review

Materialized and visually inspected Chase’s IMG_8639.jpeg and supplied Prysm references IMG_8640.jpeg / IMG_8641.jpeg through the Library helper. The first image shows the Connections/Focus cards clipped by the fixed footer. It does not display a package version; its installed version has not been independently confirmed. The reference images show a compact bottom sheet with circular connectivity, horizontal sliders, small shortcuts and a music strip; the expanded example adds a shortcut grid. The official [Prysm listing](https://havoc.app/package/prysm) and [Jade listing](https://chariz.com/buy/jade) were also consulted. User screenshots remain in the private task input folder, outside the repository and package.

The greeting/date dashboard and oversized empty media card are removed. Harbor now has compact and expanded sheet states, with original colors, UIKit/SF Symbol graphics and an independently drawn standard Bluetooth symbol. Normal compact layouts need no scroll at tested widths 300, 320, 375 and 430 points. Overflow uses a single inner scroll area with a pinned native escape.

## Diagnosis and correction

Beta3 placed an inner UIScrollView under Apple’s CCUIScrollView and overlay dismissal/scroll recognizers without participating in their arbitration. It also ran full HBSession layout from the native scroll callback. The iOS 17 overlay interface explicitly includes separate pan/flick/tap recognizers, failure setup and a CCUIScrollView gesture delegate. That is concrete evidence of a missing integration contract, not a real-device gesture trace.

The repair preserves that native hierarchy and its animation transforms. Three ABI-validated host callbacks exclude Harbor’s sheet from native pan/tap handling: gestureRecognizer:shouldReceiveTouch:, gestureRecognizerShouldBegin:, and scrollView:gestureRecognizerShouldBegin:. Native screen-edge recognizers are exempt. Outside-sheet/status-header touches continue to the system. No recognizer is disabled and no delegate is replaced.

The per-frame scroll callback now only updates the containing frame when changed. Inner contentOffset is never reset during dragging/deceleration. State/media polling uses the default run-loop mode to avoid starting polling work while tracking. Sheet expansion is a 200 ms ease-out with user interaction allowed, reduced to zero under Reduce Motion; press opacity feedback remains 120 ms. These choices reduce avoidable work; they do not establish device frame rates.

The pill slider’s hidden thumb exposed a second bug under actual pointer input: default tracking accepted the initial position but did not follow the drag. Explicit public UIControl tracking now updates brightness across begin, continuation and end, retaining UISlider accessibility adjustments. A subsequent pointer drag moved the displayed value to 0.8382524. The simulator reports UIScreen brightness as 0.5 afterwards, so hardware brightness persistence is not verified.

## Native control actions

HBNativeControls resolves already-loaded controllers and actionable UIControls, invokes their existing touch/primary actions, and reads the same controls’ selected/accessibility state. It does not instantiate private radio services, invent enabled states, or reparent system views/controllers. Four connectivity buttons plus rotation and low-power are supported when their actual controls are available. A missing control falls back to native access.

Controller names and connectivity button metadata were found in the local iOS 17.5 ConnectivityModule binary. Actual bundle identifiers were read from installed simulator Info.plists, catching three mistaken name assumptions: LowPowerModule, DisplayModule, and com.apple.mediaremote.controlcenter.audio. Runtime guards remain necessary because this is evidence from 17.5 Simulator, while the package’s firmware dependency remains 17.0.

Focus and expanded shortcuts deliberately use native module presentation. They are panel shortcuts, not direct recording/launch actions. Authentication and lock-screen policy are not overridden. Actual effects and native module availability on Chase’s phone remain unverified.

## Evidence

- `host-checks-beta4.txt`: 20 ASan/UBSan policy assertions, semantic PreferenceLoader/Preferences checks, hook exports in the actual iOS17.0 SDK, and plist validation.
- `simulator-results-beta4.json`: latest UIKit geometry, lifecycle, native-state restoration, action forwarding, safe-area and compact/expanded layout assertions. Exact count and failures are recorded in the JSON.
- `beta3-gesture-regression.json`: HID swipe against a fixture giving the native ancestor pan priority. Native pan began once; Harbor pan never began; offset stayed 0; the lower control was not visible. Beta3’s older layout tests would pass this fixture geometry.
- `beta4-gesture-overflow.json`: HID swipe in a 568-point-high, accessibility-text, expanded fixture. Harbor pan began once; native pans did not begin; offset reached 133 points; the last control became fully visible. A real tap on that last Display shortcut restored native UI and requested its panel.
- `beta4-native-action-fixture.json`: all six underlying fixture controls received exactly one action, with no native pan starting. These are simulated controls, not actual radios.
- `beta4-native-outside-gesture.json`: a stepped HID drag from the native status area reached a native pan; Harbor’s pan did not start. A plain desktop pointer drag did not exercise that recognizer, so the stepped HID result is the relevant test.
- `beta4-native-handoff.json`: actual tap on All controls restored the fixture’s native collection.
- `preview-beta4-compact-fixture.png` and `preview-beta4-expanded-fixture.png`: labeled synthetic-host previews. No physical-device screenshot or proprietary reference art is included.
- `build-beta4.log`, `preview-build-beta4.log`, `package-verification-beta4.txt`: exact build and inspection results. Known toolchain diagnostics are the obsolete multiply_defined linker flag and sandbox-denied CPU sysctl; no failed compile is treated as a passing build.

The final overflow sample recorded 71 display-link samples with a largest interval of about 16.67 ms. This short simulator sample is diagnostic evidence only, not a performance guarantee for SpringBoard or a 120 Hz device.

## Limits before publication or daily use

The fixture models documented delegate arbitration and deliberately gives the ancestor pan priority. It is not Apple’s implementation. Real Control Center has additional gesture/state machinery, so device verification is still required. Loading the actual private SpringBoard UI framework into an ordinary simulator app previously hit Apple’s process assertion; it was not bypassed.

Test on the exact iOS17.0 RootHide setup: opening/cancelling/dismissal, lower controls under real finger swipes, repeated compact/expanded changes, home/status/blank-area dismissal, rotation, locked/unlocked behavior, notifications/privacy headers, real radio and low-power state, volume/brightness persistence, media/AirPlay, Reduce Motion/Transparency, large text and other Control Center tweaks. Check All controls and the master switch first. If a selector/interface is missing, native controls must stay visible.

No phone connection, installation, respring, publication, index regeneration or git push was performed. The existing published beta3 and other packages remain unchanged. The final package checksum is recorded in `package-verification-beta4.txt` and the local sync manifest.
