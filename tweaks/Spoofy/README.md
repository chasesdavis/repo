# spoofy — research prototype

**Status: experimental, not an app-update solution.** Earlier diagnostic betas were tested on an iPhone; beta 6 itself has not been tested on a device. It only changes what `UIDevice.systemVersion` returns inside `com.apple.AppStore`, and only when explicitly enabled by a valid config on iOS 17.0. It starts disabled and performs no installer bypass. A changed display or OS string is not proof that an app can be acquired, installed, or run.

## What each layer can do

1. **Store presentation:** the App Store UI might use one or more OS-version APIs to decide what to display. This prototype intercepts only `UIDevice.systemVersion`; whether this is consulted on iOS 17.0 is unknown.
2. **Acquisition:** `appstored` and Apple's services can apply separate eligibility and delivery rules. Apple's exact server-side checks are not public and no server behavior has been verified for this prototype. The App Store UI hook does not change appstored or server state.
3. **Installation:** Apple's MobileInstallation daemon `installd` performs local installation checks. Historic [LowerInstall](https://github.com/julioverne/LowerInstall/blob/master/lowerinstallhooks/LowerInstall.xm) hooked `MIBundle` version checks in installd, among many other checks. Those private hooks have not been verified on iOS 17.0, and Spoofy does not hook them. Current upstream [Bootstrap's injection list](https://github.com/roothide/Bootstrap-basebin/blob/main/resignList.plist) includes App Store, appstored, and installd, but availability depends on the installed Bootstrap version and configuration.
4. **Execution:** installation cannot add missing OS frameworks or symbols, entitlements, or server support. An application may fail to launch or fail later even if it installs. TrollStore can install IPAs but does not provide newer iOS APIs or guarantee an app is compatible.

The repository already contains a `StayOn17` experiment, but its broad network rewriting and unverified installer hook are not evidence of reliable compatibility. Spoofy is independently scoped. The unrelated name Spoofy has appeared in the jailbreak community; this uses package ID `com.chasedavis.spoofy.compat`.

Beta 6 adds an opt-in, same-thread call-context diagnostic. It records fixed flags for explicitly marked spoofy work and unclassified calls, without addresses, paths, arguments or app data. Unclassified does not identify a caller or eligibility decision. See [CALL-CONTEXT.md](CALL-CONTEXT.md). The package listing uses the spoofy smile icon. The Settings switch is an experimental control for the App Store display test. Beta 5 reads prior integer and current boolean diagnostic values. Existing reports are protected from overwriting on a new App Store launch; close the Store and explicitly clear a report before recording another run. Optional diagnostics record a fixed state, timestamp, and three yes/no call indicators and two hook-comparison indicators; the Settings page displays and can clear the latest report. Calls can come from any code in the process, including the diagnostics, and do not prove eligibility behavior. An absent or stale report is inconclusive.

## Build and tests

```sh
sh tests/run.sh
make package FINALPACKAGE=1
```

The beta source adds a Settings switch and moves its config to `<jbroot>/var/mobile/Library/Preferences/com.chasedavis.spoofy.compat.plist`, consistent with RootHide's writable-data guidance. Missing, disabled, invalid, or unsupported-OS configuration causes pass-through. Close and reopen the App Store after a configuration change. The Settings bundle and whether its file can be read by the App Store have not been verified on-device. No configuration is deployed automatically. The package is for research only.

In the sandbox used for the earlier prototype build, normal packaging failed because `fakeroot` could not create its IPC channel. A local build-only wrapper and `dpkg-deb --root-owner-group` produced the earlier research archive with xz compression; both architecture slices and archive contents were inspected. The earlier archive predates the Settings switch and is not suitable for release. The beta's device behavior, RootHide relocation, and config-file access remain unverified.

To inspect the declared minimum OS values in a locally supplied IPA without modifying or extracting it:

```sh
python3 tools/inspect_ipa.py /path/to/app.ipa
```

This reports bundle and extension metadata only. It cannot verify architecture, Mach-O deployment targets, imports, DRM/encryption, entitlements, account eligibility, or runtime behavior. A `within_target` result is not a compatibility determination.

## Device investigation still needed

With explicit permission before any installation, establish the actual Bootstrap version and injection support; record a baseline for a disposable app and preserve its data. Verify that the disabled tweak loads without changing Store behavior and that enabling it reaches the hook through `[spoofy]` logs. Compare the same app's Store presentation with the experiment off and on. Separately determine, from controlled logs and errors, whether acquisition is rejected by the Store service, delivery is blocked, or `installd` rejects the bundle. Do not bypass signing, device-family, entitlement, or other unrelated checks. Any candidate installer hook requires confirmation of the actual iOS 17 method, its type, and safe per-app targeting before implementation. Finally, for an authorized test app, verify installation, launch, major features, and app-specific server behavior. A successful experiment says nothing about other apps.
