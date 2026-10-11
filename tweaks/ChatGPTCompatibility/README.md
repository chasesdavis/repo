# ChatGPT Compatibility — Experimental Beta

**0.2.0~beta6 is locally tested, not device-tested.** Beta 6 adds the StoreKitUIService product-page host to the StoreKitUI compatibility decision hook for the exact ChatGPT store item. It retains the App Store and alternate store-process, late User-Agent, typed ChatGPT, and installer guards.

## Scope

- iPhone16,2, **iOS 17.0.x**, RootHide Bootstrap with working `appstored` and `installd` injection.
- Official ChatGPT store ID `6448311069`, bundle ID `com.openai.chat`.
- Installer changes are limited to main app version **1.2026.272**, and matching app extensions inside that exact app bundle, when comparing minimum OS 18.0 against 17.0.
- **Disabled by default.** Other devices, OS versions, apps, ambiguous requests, missing metadata, and incompatible method signatures keep their original behavior.

## What it actually changes

1. Inside the App Store and `StoreKitUIService` product-page hosts, hooks iOS 17 `SKUIIPhoneProductPageViewController` and `SUUIIPhoneProductPageViewController` `_isIncompatibleItem`. Only the item with bundle ID `com.openai.chat` and store ID `6448311069` is treated as compatible for the UI path. It does not alter unrelated apps.
2. Inside store processes, hooks the iOS 17 `AMSURLRequest` User-Agent setter after AppleMediaServices has attached typed `AMSPurchaseInfo` and `AMSBuyParams`. Only an HTTPS POST to the `itunes.apple.com` buyProduct endpoint whose purchase dictionary identifies the single ChatGPT product qualifies. It changes the existing `iOS/17.0` token to `iOS/18.0`. The request body and every other header are preserved. Selected task-creation hooks remain as a fallback. No network request is initiated by the tweak itself.
3. Inside `installd`, checks the runtime ABI before hooking `_isMinimumOSVersion:applicableToOSVersion:requiredOS:error:`. For the exact target bundle it calls the original method with the OS comparison argument set to 18.0. It does **not** return unconditional success. The original method's return value, minimum requirement, required-OS argument, and error pointer are preserved.

There are no global `UIDevice`, `NSProcessInfo`, `sysctl`, or MobileGestalt hooks, no signature/receipt/entitlement bypasses, no app patching, and no request-data logging. Only fixed startup/hook-status messages enter the system log. The installer reads bundle metadata for identity and version; it does not write it.

## Limits

Runtime injection, the actual App Store refusal path, successful download/installation, launch, and dot access are **unverified**. This package does not supply iOS 18 frameworks or symbols and cannot enable server-side entitlements or missing client UI.

The store path does not force or invent a build ID; it preserves the version requested by the App Store. The installer exception is pinned to 1.2026.272. Batch updates, streamed/compressed/binary/JSON bodies, query-bearing URLs, alternative transports, and unsupported UI gates are deliberately not handled. Do not broaden these guards simply because an update still fails.

The supplied 1.2026.272 IPA was inspected without modifying it. Its main executable, `ChatGPT.framework`, and `OpenAIXPlat.framework` all declare an iOS 18.0 minimum in their Mach-O build commands; the app executable is arm64. This tweak can change the store/installer decision path only. It does not make that iOS 18 binary runnable on iOS 17 or supply missing system frameworks.

## Install and control

Publication does not install anything on your phone. In Sileo, refresh `https://chasesdavis.github.io/repo/` and find **ChatGPT Compatibility (Experimental)**. It is a native `iphoneos-arm64e` RootHide package, not a rootless package needing conversion. It conflicts with the broad LowerInstall and AppStoreTroller packages to avoid combining spoofers.

After an installation you choose to perform, open **Settings → ChatGPT Compatibility**. The experiment remains disabled until you enable its switch. The Runtime status panel shows StoreKitUI, store-process, and installer hook/match state. Changing the switch updates already-loaded hooks without killing a process. If the dylib has not loaded into the target process, toggling does not make it load; this package deliberately performs no automatic reboot, respring, or daemon restart. Do not enable injection into ChatGPT itself.

An official App Store update necessarily replaces the installed app. “No app patching” does not mean an update leaves the old app files unchanged.

## Disable and remove

Turn the switch off **before** removing the package. Loaded hooks then call their originals without modification. Remove the package in Sileo to remove its dylib, filter, and Settings pane. Loaded code remains in a process until that process exits normally, but the disabled behavior remains unchanged. Removal does not restore an older ChatGPT version or undo app-data changes. The user preference may remain, as with other Settings tweaks; keep it off before uninstalling.

## Build and verification

```sh
export THEOS=/Users/chase/theos
bash scripts/test.sh
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
python3 scripts/verify_package.py
```

Host policy tests cover default-off settings, device/process/OS scope, single-app identity, malformed and duplicate parameters, ambiguous/mixed-app input, preservation of request data, exact bundle-version checks, and ABI mismatch. Hook integration tests execute the production adapters against a **mock** installer/hook provider and verify that original errors/results and other arguments survive. These are not iOS device tests. Builds use the existing iOS 17 SDK and produce arm64/arm64e slices with RootHide dependencies.

The beta 1 interception-order failure and beta 2 runtime-gate failure are locked down by regression tests: the late-header policy receives typed ChatGPT metadata and rewrites only the subsequently attached token, while iOS 17.0 patch releases pass the runtime gate and iOS 17.1 does not.

The package verifier checks the exact five-file payload, absence of maintainer scripts or enabled preferences, both architectures, minimum/SDK versions, and embedded CodeDirectory page hashes. Theos uses `ldid -S` pseudo-signing; macOS `codesign --verify --strict` reports these images as unsigned. The embedded page hashes are checked separately. This is an integrity check, not proof of device loading or Apple signing trust.

## Evidence behind the experiment

- [Existing installer comparison technique](https://github.com/waruhachi/AppStoreTroller/blob/79a32da92f8b9cbc3b5aa26819ede9274435daef/Tweak/AppStoreTroller.xm) and [earlier implementation](https://github.com/verygenericname/appstoretroller/blob/a7d0eb9a475a371bb92de1f77a781df6d481254e/Tweak.xm). This implementation adds narrow identity/version guards; it does not reuse their broad update spoofing.
- [iOS 17.0.3 AMSURLSession declarations](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/AppleMediaServices.framework/AMSURLSession.h). Method presence and types are rechecked at runtime; these headers do not attest the user's exact device.
- [iOS 17.0.3 AMSURLRequest](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/AppleMediaServices.framework/AMSURLRequest.h), [request properties](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/AppleMediaServices.framework/AMSURLRequestProperties.h), and [purchase info](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/AppleMediaServices.framework/AMSPurchaseInfo.h) define the typed identity chain used by beta 2. Every selector's ABI is checked before use.
- [ipatool's purchase request implementation](https://github.com/majd/ipatool/blob/987900b4170a61e1653357db228e9b419d0ab27e/pkg/appstore/appstore_purchase.go) uses the plist `salableAdamId` product identifier and `productType=C`. The experiment accepts only that identity-bearing shape, not arbitrary version strings in a request body.
- [Apple's public lookup](https://itunes.apple.com/lookup?id=6448311069&country=us), checked 2026-10-10: `com.openai.chat`, version `1.2026.272`, minimum OS `18.0`.
- [Bootstrap 2.2.1's pinned loader gates](https://github.com/roothide/Bootstrap-basebin/blob/f25ab8b9dc70e8e2e14af9e60f9d88c9c445cca9/bootstrap/bootstrap.c#L608). Source-level injection support does not confirm a loaded tweak on a specific phone.
