# Harbor beta2 repair — 2026-11-04

Status: **beta2 publication authorized after local validation; no phone installation performed.** This repairs beta1 commit `d2137f515c757e07d837c11d4435f8e9bc6fe252`. See [PUBLICATION.md](PUBLICATION.md) and the linked Actions workflow for the release artifact and deployment status.

## Confirmed beta1 defects

1. `Tweak.xm` resolved `CCUIModularControlCenterViewController`. It is absent from the installed iPhoneOS 17.0 ControlCenterUI SDK exports. The iOS 17 runtime header declares `CCUIModularControlCenterOverlayViewController` directly under `UIViewController`, with `moduleCollectionViewController`, `overlayContainerView`, `_reparentAndBecomeActive`, and `_resignActive`. Beta1 silently abandoned hook registration when its obsolete class was missing.
2. `Prefs/entry.plist` omitted `isController`. Theos's canonical PreferenceLoader registration template sets it to true for a custom controller. Without it, PreferenceLoader uses the generic bundle-controller loading route instead of the intended class route.
3. `Prefs/Resources/Root.plist` was a top-level array. The Preferences format in Theos's canonical template is a dictionary containing `items` and `title`. Syntax-only `plutil -lint` accepted the wrong structure; it did not establish a usable Settings pane.

The actual published beta1 payload contains the tweak, SpringBoard-only filter, preference executable, Info.plist, Root.plist, and loader entry. No payload file was missing. RootHide's relative `Library/...` archive paths and the dylib's relocatable `.jbroot` dependencies are retained.

Evidence: [beta1-regression.txt](beta1-regression.txt) shows the new validator rejecting the original committed source for exactly these three defects. The published beta1 deb SHA-256 remains `d6e40609bb341db11ec706b267862e17146433b22da80982083bfbcb5bea7d4b`.

## Changes

- Hook the iOS 17 overlay class and validate its object-returning container/collection interfaces before hooking.
- Observe dyld image additions and coalesce hook checks onto the main queue. Registration can now happen after SpringBoard's launch notification. No private framework is force-loaded; the dyld callback does no UIKit, Objective-C messaging, or hook installation.
- Add Harbor inside the validated `overlayContainerView`, preserving Apple's presentation transforms. Native modules are still never reparented or destroyed; their previous hidden state is restored exactly.
- Correct the PreferenceLoader controller flag and Preferences dictionary schema.
- Show a timestamped, versioned **last SpringBoard report** in Settings, with Refresh status. Missing injection, waiting for the class, ready hooks, disabled Harbor, native handoff, and rejected layout can be distinguished. This is deliberately historical status, not a live health claim.
- Name the local package `0.1.0~beta2`; keep `iphoneos-arm64e`, both Mach-O slices, and the existing `>=17.0, <<17.1` firmware dependency.

## Verification

- RootHide Theos build: both Harbor and HarborPrefs compile/link/sign for arm64 and arm64e. See [build-beta2.log](build-beta2.log). Existing toolchain warnings are the obsolete `-multiply_defined` flag and restricted-shell CPU-count `sysctl`; no source compilation warnings/errors.
- Twenty C policy assertions pass with AddressSanitizer and UndefinedBehaviorSanitizer.
- Semantic source/package checks pass for PreferenceLoader routing, bundle identity, principal class, `items` schema, preference keys/defaults, and the actual iOS 17.0 SDK's hook-class exports. The same source checks reject beta1.
- Thirty-three UIKit/mock-host tests pass on iOS 17.5 iPhone 15 Pro Simulator. Added coverage checks the nested presentation container, missing/outside-container fallback, and diagnostic persistence. See [simulator-results-beta2.json](simulator-results-beta2.json).
- Exact six-file package payload, SpringBoard-only filter, version, Debian architecture, both Mach-O slices, and dynamic library paths pass inspection. See [package-verification-beta2.txt](package-verification-beta2.txt) for the current package checksum.
- `git diff --check` passes. Repair implementation stays under `tweaks/Harbor/`. The subsequently authorized publication also replaces Harbor's deb, updates its depiction/catalog entry and version validation, and regenerates indexes. Other tweak sources and all five unrelated package artifacts are preserved.

## Limits and next device check

The initial mock tests missed the class/schema defects; they cannot substitute for integration validation. The new SDK/schema checks close those specific gaps but still do not execute hooks in real SpringBoard.

A separate simulator probe could not load Preferences/ControlCenterUI into an ordinary app: an Apple SpringBoardUI `+load` assertion aborts that process. The assertion was not bypassed. The installed class-dump 3.5 also could not parse the simulator binary's modern chained-fixup load commands. Header/SDK evidence was used instead; neither failed probe is reported as a passing runtime test.

Phone model, exact firmware, Bootstrap/RootHide version, active injection runtime, PreferenceLoader behavior, live MediaRemote, actual hardware volume/brightness, Apple container geometry/transitions, lock-screen presentation, and conflicts with other tweaks remain unverified. Local NeonCC recovery history records Safe Mode problems from previous overlay experiments, so preserving runtime guards and native restoration remains essential; no old code/assets were copied.

After an authorized beta2 install, restart SpringBoard through Bootstrap's supported UI and reopen Settings. **Settings → Harbor → Enable Harbor** defaults on. Open Control Center with the normal top-right downward swipe in portrait. **All controls**, **Connections**, and **Focus** hand off to Apple for that visit; close/reopen to return. If nothing appears, **Refresh status** records where activation stopped. An absent pane still requires checking PreferenceLoader/Settings injection. TrollStore by itself does not inject a SpringBoard dylib.

References: [iOS 17 overlay header](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/ControlCenterUI.framework/CCUIModularControlCenterOverlayViewController.h), [iOS 17 collection header](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/ControlCenterUI.framework/CCUIModuleCollectionViewController.h), local Theos `vendor/templates/ios/preference_bundle/{Resources/Root.plist,layout/Library/PreferenceLoader/Preferences/@@PROJECTNAME@@.plist}`, and [RootHide PreferenceLoader's controller routing](https://github.com/roothide/preferenceloader/blob/master/Tweak.xm).
