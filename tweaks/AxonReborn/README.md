# Axon Reborn

A complete visual and architectural redesign of Axon's app-grouped Lock Screen notifications. Initial target: **iOS 15–17**, with **rootful**, **rootless**, and **RootHide** package configurations.

**Status: experimental alpha, compiled but not device-verified.** All three package variants passed the [native CI build](https://github.com/chasesdavis/repo/actions/runs/40053352957). The RootHide `0.1.0~alpha2` package is published at https://chasesdavis.github.io/repo/ for device testing. There is no claim that every iOS/device/jailbreak combination works. This project starts disabled in Settings.

**First device target: the user’s iOS 17 device running RootHide Bootstrap.** RootHide is the default build variant. The exact Bootstrap version and SpringBoard injection setting still need to be recorded during device testing.

Open `Design/preview.html` in a browser for the interactive visual concept. It works offline with sample notifications. Its controls manipulate demo data only.

## What changed

- New horizontal app capsules with frosted material, readable names, counts, a persistent All option, and compact mode.
- Native iOS notification cards remain responsible for previews, authentication, actions and presentation. The custom rail does not render message bodies.
- A portable C++17 index handles duplicate IDs, grouping, recency, count ordering, and selection fallback when an app's last notification disappears.
- One guarded runtime adapter targets `NCNotificationStructuredListViewController`. It checks class and method signatures and requires an initial native snapshot before filtering. Unknown interfaces leave the original implementation active.
- Controller-specific state replaces Axon's global single-list manager. A new snapshot is read when the controller is presented again. UI refreshes are coalesced on the main queue.
- Preference reads use CFPreferences instead of absolute filesystem paths. PreferenceLoader resources live in Theos' layout tree, so each packaging scheme applies its prefix.
- A distinct development package ID avoids silently replacing an installed Axon. The packages conflict with the original and known competing groupers.

## Native implementation versus demo

The native source implements the capsule selector, All/app filtering through the guarded adapter, counts, compact mode, recent/count ordering, selection haptics and a Settings bundle. The demo additionally offers **sample data controls**: add an arrival, clear a sample group, reset and toggle preview privacy. Those demo controls are not new native notification-clear or lock-state APIs.

The native rail uses the system's blur material and respects Reduce Transparency. Its controls have VoiceOver labels/selection traits, Dynamic Type labels and at least 48-point height. There are no idle animation timers. Accessibility and native privacy behavior still need real-device verification.

## Build on macOS

Requirements: Xcode with an iPhoneOS SDK selected by `xcode-select`, current Theos and its SDK/private-header support, an arm64/arm64e-capable toolchain, and the expected Substrate-compatible hooking library. Use `roothide/theos` for RootHide builds. A compatible jailbreak with SpringBoard injection is required on the target device.

```sh
cd tweaks/AxonReborn
export THEOS="${THEOS:-/Users/chase/theos}"
bash scripts/test.sh
bash scripts/build.sh roothide
```

Build the other variants separately:

```sh
bash scripts/build.sh rootful
bash scripts/build.sh rootless
```

The script runs `make clean` before each build. Packages are emitted by Theos under `packages/`. Never convert support by simply changing a Debian architecture string or repacking a rootful binary. Inspect the generated architecture, dependency metadata, install paths and Mach-O load commands before installation. The current project requires macOS for its modern arm64e build; it does not attempt an ABI conversion workaround.

Rootful is the usual term for what is sometimes called “rooted.” Package format is independent of OS support. Package metadata is constrained to `>= 15.0` and `< 18.0`; all higher versions are intentionally outside this first target.

### Build using GitHub Actions

The [build workflow](../../.github/workflows/build-axon-reborn.yml) runs on Axon source changes and can also be started manually. It uses pinned RootHide Theos and a patched iOS 16.5 SDK, runs portable checks, compiles the tweak and Settings bundle for arm64/arm64e, packages all three variants, inspects metadata, and uploads separate artifacts. Use `axon-alpha-roothide` for the first device target. All three variants built successfully on October 24, 2026; this does not establish on-device compatibility. Running the workflow does not install anything on your phone.

### Alpha2 device troubleshooting

Alpha2 removes the dependency between reporting adjunct content and an already visible rail, attaches the list earlier in its lifecycle, retries mounting during layout, and reconnects visible controllers when enabled. These changes address a possible blank-panel path; on-device confirmation is still required.

After updating, respring, enable Axon, and open the Lock Screen with a notification present. If the selector is absent, return to **Settings → Axon Reborn → Check SpringBoard**. The diagnostic reply distinguishes a disabled preference, missing controllers, rejected signatures, unavailable snapshots, request parsing, mount failure, empty lists and successful attachment. A timeout means no reply was received; it does not by itself prove injection is disabled. Replies contain fixed status codes only, with no notification bodies or identifiers. Status describes the last observed Lock Screen presentation, not complete compatibility.

## Development safety and limitations

1. No device or OS/jailbreak combination has been certified. Do not distribute as stable or install on a primary device as a validated release.
2. Filtering uses native list insert/remove operations, modeled after Axon. It does not intentionally clear the notification dispatcher/store. Private APIs can still change behavior even when their signatures match.
3. The adapter only supports the structured list's one-request methods returning `void` or `BOOL`. Unknown signatures, missing classes or incomplete initial snapshots disable filtering.
4. On a replay failure the adapter attempts to restore All and disables itself for that controller. Restoration is best-effort. If it fails, disable the tweak and respring through the jailbreak's existing controls.
5. Grouped/coalesced notification counts, bulk clears, Focus, Scheduled Summary, notification list modes, media controls, native quick actions, rotation, concurrent list controllers and authentication need physical-device tests. Counts represent distinct requests observed by this adapter and are not yet guaranteed to equal every visually nested notification.
6. No custom notification body export, debug dump, analytics or network endpoint is implemented. Native request objects are retained temporarily in process memory for filtering; these objects may themselves contain message content.
7. The adapter and Settings preference domain must be verified specifically under RootHide. A working package build does not prove successful injection or shared preference behavior.
8. Unsupported native layouts have no speculative overlay fallback. If the `_stackView` mount is unavailable, the rail is not mounted and no user selection can start filtering.

## Validation completed here

`bash scripts/test.sh` compiles the portable index with C++17 and warnings-as-errors. It tests identifier collisions across apps, duplicate updates, selected-app removal, recency recalculation, deterministic ordering, and **20,000 seeded randomized notification events** against a reference model. It also parses the XML plists, evaluates all three Makefile configurations, checks package bounds and validates shell syntax.

The portable checks do **not** verify injection or notification safety on an iPhone. Separately, CI successfully compiled the native UIKit/Objective-C++ sources and packaged rootful, rootless and RootHide builds. The published RootHide artifact was inspected for architecture, package contents and Mach-O dependencies. See `docs/DEVICE_TESTING.md` for those release gates and `docs/SOURCE_AUDIT.md` for reference findings.

The standalone HTML preview was also exercised in headless Chromium: filtering, simulated arrivals, privacy demo, last-app removal fallback, compact/count controls, ordering, empty state and reset. It produced no page errors or horizontal page overflow at 1440, 1024, 768, 390 and 320 pixels. Desktop and mobile renders were visually inspected. `Tests/preview.spec.cjs` reproduces these checks with Playwright installed; this is browser validation, not native iOS validation.

## Attribution and license

Original Axon: **Nepeta & Baw Appie**. Reference fork: **dakotadawolfe/axon-ios16-compatibility**, commit `5de63de57c2ccb0fdefb33e374c59e1517b0c040`, retrieved October 23, 2026. This is an independent experimental redesign, not an official upstream release or endorsement. The prior manager, UI and preferences were replaced; the native structured-list and adjunct-stack integration concepts informed this adapter.

Distributed under **GPL-3.0-only**. Preserve the included `LICENSE`, attribution and corresponding source when distributing derivatives/binaries.

Primary references:

- https://github.com/Baw-Appie/Axon
- https://github.com/dakotadawolfe/axon-ios16-compatibility
- https://theos.dev/docs/rootless
- https://github.com/roothide/Developer
- https://github.com/roothide/Bootstrap/releases
- https://github.com/opa334/Dopamine
- https://github.com/palera1n/palera1n
