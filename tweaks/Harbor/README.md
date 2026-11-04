# Harbor

A quiet place for the controls you reach for most. An original, free Control Center dashboard for Chase's iPhone, inspired by the cohesive feel of Prysm and Jade. No code, artwork, or assets from either project are used.

**0.1.0~beta3 corrects the full-screen layout; physical-device testing remains pending.** See [BETA3-FULLSCREEN.md](docs/BETA3-FULLSCREEN.md) for the screenshot investigation, reproduced defect, and current limitations. The package targets iOS **17.0** with RootHide and working SpringBoard injection. Simulator checks do not establish physical-device compatibility or jailbreak support for iOS 17.5.

![Harbor beta3 in the simulator with a synthetic native status header and pinned All controls](docs/preview-beta3-inset-fixture.png)

The screenshot shows the synthetic native-host fixture, with its system header explicitly labeled. It is not a physical-device screenshot. Simulator has no hardware volume route, so the volume card shows its fallback.

## This version

- A bottom-weighted portrait dashboard with soft dark surfaces, generous touch targets, and Sea Glass, Ember, or Iris accents.
- Live now-playing title, artist, bounded artwork thumbnails, play/pause, previous, and next. Empty and unavailable states disable transport. Skip respects MediaRemote's prohibition flag.
- Brightness control with a live percentage and a 2% minimum. Native `MPVolumeView` for volume; a system-controls shortcut appears if its slider is unavailable. Native AirPlay route picker.
- Connections and Focus shortcuts restore Apple's Control Center and request the matching installed module. These are panel shortcuts, **not fake connectivity toggles**. If a module cannot be identified, the native controls remain visible.
- **All controls** stays pinned above the home-indicator area and restores Apple's complete Control Center for the current visit. Close and reopen to return to Harbor. Cards scroll independently when space is limited. Native modules and their controllers are never moved, replaced, or destroyed.
- The backdrop fills the native Control Center background. Content uses the full-window native scroll surface, with space reserved for Apple's status/privacy header and safe areas; it is no longer sized to the inset module panel.
- An in-panel appearance menu and a Settings → Harbor page with a live master switch, palette, haptics, and the last diagnostic report from SpringBoard.
- VoiceOver labels, Dynamic Type with a single-column accessibility layout, scrollable compact layouts, Reduce Transparency, and Reduce Motion. Press feedback is an interruptible 120 ms opacity change; there is no extra entrance bounce layered onto the system gesture.

Landscape, iPad, unexpected hierarchies, and expanded native modules retain the native layout. No new activation gesture, lock-screen access override, radios implementation, or network service is installed.

## Build

From this directory:

```sh
bash scripts/check.sh
bash scripts/build.sh
bash scripts/verify-package.sh
```

Requires Xcode, RootHide-capable Theos at `$THEOS` (defaults to `/Users/chase/theos`), an `iPhoneOS17.0.sdk`, `ldid`, and Theos's normal packaging tools. `verify-package.sh` also uses Python 3 and `dpkg-deb`.

The build runs in a temporary directory because Theos does not reliably handle the spaces in `Jailbreak Tweak Repo`. It copies only Harbor's resulting package back to:

```text
packages/com.chasedavis.harbor_0.1.0~beta3_iphoneos-arm64e.deb
```

Both the tweak and preferences binary contain **arm64 and arm64e** slices. The Debian architecture is `iphoneos-arm64e`, as required by this RootHide packaging scheme. The dylib uses relocatable `.jbroot` library paths. There are no hardcoded `/var/jb` paths or install/respring scripts.

The authorized beta3 publication uses the established Harbor build/index/Pages pipeline, replacing only Harbor's package and related release assets. The other five packages are preserved. [PUBLICATION.md](docs/PUBLICATION.md) records the release artifact and deployment-verification process.

## Installation requirements and first device test

This repair workflow has not installed anything on Chase's phone. The following applies to beta3 after an authorized installation. The version installed when the supplied screenshot was captured has not yet been confirmed; it is not inferred from the timing of beta2's publication.

1. Verify the phone's exact iOS version and that its RootHide environment can already inject tweaks into **SpringBoard**. TrollStore alone cannot load this dylib. The official [Bootstrap release notes](https://github.com/roothide/Bootstrap/releases/tag/2.0-public-beta2) document SpringBoard injection for iOS 16.0–17.0; do not infer support for other firmware or bootstrap configurations.
2. The package requires a `mobilesubstrate`-compatible injection runtime and PreferenceLoader. Install the `.deb` using the package manager inside that RootHide environment, not TrollStore's IPA installer. Enable Settings injection if required by that environment for preference bundles.
3. Restart SpringBoard through the environment's supported UI, and fully close/reopen Settings. Look for **Settings → Harbor → Enable Harbor** (on by default). On environments that group tweak panes, check the PreferenceLoader tweaks section.
4. Swipe down from the top-right in portrait to open Control Center normally. There is no Home Screen app or separate activation gesture. Test **All controls first**, then close/reopen, then the master switch in Settings.
5. If the dashboard is absent, return to **Settings → Harbor → Refresh status**. The last report distinguishes missing SpringBoard injection, waiting for the framework, installed hooks, disabled Harbor, and rejected hierarchy/geometry. It records a timestamp and build version; it is not a live heartbeat. Complete [DEVICE-TESTING.md](docs/DEVICE-TESTING.md) before daily use.

To disable, turn off Settings → Harbor → Enable Harbor. To remove, uninstall `com.chasedavis.harbor` with the same package manager and restart SpringBoard through the normal supported UI. If SpringBoard cannot launch normally, use the environment's established disable-tweak/safe-mode recovery path; no device-specific recovery commands have been assumed.

## Implementation map

| File | Responsibility |
| --- | --- |
| `Tweak.xm` | iOS 17 overlay-controller hooks, runtime ABI checks, coalesced main-queue registration after dyld image loading |
| `HBSession.m` | Host/viewport validation, full-screen backdrop and scroll-surface containment, native header safe areas, exact hidden-state restoration, native handoff |
| `HBDashboardController.m` | Shipping UIKit interface, public brightness/volume/routing controls, accessibility, appearance menu |
| `HBMediaProvider.m` | Dynamically resolved MediaRemote, asynchronous visible-only polling, bounded thumbnail decode, timeout/stale-callback guard |
| `HBPreferences.m` | One preference domain and change notification; defaults, type validation, timestamped runtime diagnostics |
| `HBPolicy.c` | Host-tested presentation eligibility, numeric clamping, command allowlist |
| `Prefs/` | PreferenceLoader registration and Settings bundle |
| `tests/PreviewMain.m` | Standalone simulator host, lifecycle/UI tests, sample-media preview; not packaged |
| `tests/integration_contract_test.py` | Semantic PreferenceLoader/Preferences checks and hook-class validation against the actual iOS 17.0 SDK exports |
| `scripts/` | Local build, checks, package inspection, and simulator preview build |

Preferences use `com.chasedavis.harbor` through CFPreferences. Polling runs every two seconds for media and every 15 seconds for date/status only while Harbor is active. Artwork decode runs on a serial background queue, accepts at most 8 MiB, and creates thumbnails no larger than 320 pixels. Battery is shown only if the host already provides a valid reading; Harbor does not toggle the process-wide monitoring setting.

## Verification and limits

See [VERIFICATION.md](docs/VERIFICATION.md), [the machine-readable simulator results](docs/simulator-results.json), and [the build log](docs/build.log).

Real SpringBoard injection, host-controller dimensions and callbacks on the exact phone, authenticated/locked presentation, private MediaRemote responses, actual volume/brightness persistence, AirPlay, and conflicts with other Control Center tweaks still require device testing. The runtime guards retain native Control Center when assumptions do not hold. A successful build and mock-host test cannot prove those private APIs work on the phone.

## Simulator preview

```sh
# Use /tmp for signing if an iCloud/FileProvider folder re-adds FinderInfo.
HARBOR_PREVIEW_APP=/tmp/harbor-preview/HarborPreview.app bash scripts/build-preview.sh
# Choose an installed iOS 17 simulator; the following only targets a simulator UUID.
xcrun simctl install SIMULATOR_UUID /tmp/harbor-preview/HarborPreview.app
xcrun simctl launch SIMULATOR_UUID com.chasedavis.harbor.preview
```

The harness runs its checks and saves `Documents/test-results.json` in its own simulator app container. Optional launch arguments `--large` and `--empty` show the accessibility and empty-media states; `--inset-host` shows the synthetic native-host fixture used to reproduce the clipped panel. The preview is a standalone app; it does not inject into Simulator SpringBoard and is not an IPA/device installer.

## API references

The public UIKit/MediaPlayer/AVKit controls are compiled against the installed SDK. Beta2's integration targets the [iOS 17 overlay controller](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/ControlCenterUI.framework/CCUIModularControlCenterOverlayViewController.h) and [iOS 17 module collection](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/main/PrivateFrameworks/ControlCenterUI.framework/CCUIModuleCollectionViewController.h), with class exports checked against the installed iPhoneOS17.0.sdk. Beta1 incorrectly relied on an older superclass declaration. Media uses [Theos MediaRemote declarations](https://github.com/theos/headers/blob/master/MediaRemote/MediaRemote.h). Headers establish names and interfaces, not physical-device behavior; runtime checks and device validation remain necessary.

Free, with no paid tier. Uses the repository's MIT license.
