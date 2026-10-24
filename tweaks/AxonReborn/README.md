# Axon Reborn

A complete visual and architectural redesign of Axon's app-grouped Lock Screen notifications. Initial target: **iOS 15–17**, with **rootful**, **rootless**, and **RootHide** package configurations.

**Status: experimental alpha, compiled but not device-verified.** All three package variants passed the [native CI build](https://github.com/chasesdavis/repo/actions/runs/40089454370). The RootHide `0.1.0~alpha7` package is published at https://chasesdavis.github.io/repo/ for device testing. There is no claim that every iOS/device/jailbreak combination works. This project starts disabled in Settings.

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

### Alpha7 child-section reveal coordinator

The device was already using List display mode. With All selected, alpha6 restored all 323 requests and cleared all filtered caches, but the combined history and summarized sections still reported unrevealed. This narrows the remaining issue to native section presentation, not app-filter restoration.

Alpha7 keeps the app filter and adds a checked `NCNotificationListRevealCoordinator` path. It consults the coordinator's native reveal/transition gates and section-state lock, requests history reveal, refreshes its sublist references, sets its normal section-revealed state, and asks it to update the child views. Missing signatures, a denied gate or a locked state stop this path. It does not set force-reveal, authentication, preview permissions or a guessed display-style enum.

The previous section-revealed state is retained and restored when the list leaves presentation, Axon is disabled, or the coordinator is replaced. A later native collapse is respected. A transient denial of another reveal request does not itself collapse an existing presentation.

Simulator contract tests cover stale child sections, native reveal and transition denial, locked interaction state, preserving an already revealed state, cleanup, coordinator replacement and missing coordinator handling. These test doubles validate the adapter's control flow, not the private implementation on the phone. The change still needs device testing.

The report adds the coordinator class, section-revealed and lock flags, native permission results, sublist count and a fixed result label. No notification content or identifiers are exported.

### Alpha6 reveal timing and native-model diagnostics

The alpha5 device report recorded seven taps, 27 expected requests, 41 applied app rules and a successful reveal method call, but zero native visible notifications. This proves the callback and filter predicate are running; it does not establish where the selected requests are stored or whether native history opened.

Alpha6 hides other apps before restoring the newly selected app, then requests history reveal on the next main-queue turn after layout. Stale selections and controllers that have become inactive cannot run deferred reveal. A bounded sample 350 ms later records the model. This addresses a possible ordering/timing problem; it is not a confirmed diagnosis of the device's blank list.

The report now includes the native history-revealed flag, content-to-reveal flag, raw display-style value, section visibility/reveal flags and aggregate total/selected request counts in all/filtered/hidden containers. Combined sections are traversed with limits and duplicate protection. Unknown getters and unparsed container contents are marked explicitly. No dictionary keys, app identifiers, request identifiers, text or object descriptions are exported. The new zero-visible diagnostic describes the mismatch instead of reporting mount success alone.

Simulator tests verify hide-before-restore ordering, deferred reveal, rapid-selection and offscreen cancellation, model-count reporting and omission of dictionary keys, alongside the existing filtering/restore tests. They still do not emulate SpringBoard. After upgrading and respringing, select an app, wait a second, test All, and copy the report if the cards remain absent.

### Alpha5 iOS 17 selection

Alpha4 mounted the capsules on the test device, but the user reported that selecting an app did not show its cards and other apps remained visible when revealing history.

Alpha5 uses the checked native `toggleFilteringForSectionIdentifier:shouldFilter:` interface for existing app groups on iOS 17. It also hooks `notificationMasterList:shouldFilterNotificationRequest:` to preserve the native decision and add the selected-app restriction for incoming requests. The iOS 17 event hooks now forward insert, remove and modify operations to iOS instead of suppressing or replaying request lifecycles for presentation filtering. iOS 15–16 retain the earlier adapter.

Selecting an app or All requests `revealNotificationHistory:YES animated:YES` (deferred until after layout in alpha6). Repeated appearance callbacks in the same active presentation no longer reset selection. All, disabling and leaving the list restore only app rules owned by Axon; exclusions reported by the original native policy are retained. A partial mutation failure attempts rollback and disables that controller's filter.

Simulator contract tests exercise the actual runtime reconciliation code against a fake controller: switching apps, All, native policy precedence, arrivals and dismissals, repeated appearance, history reveal, disappearance cleanup and partial-failure rollback. Capsule UIAction dispatch is also tested. These tests validate our control flow and method contract, not Apple's private implementation. On-device filtering and history presentation still need verification.

The copyable report adds selection-tap count, selected/all state, expected request count, applied app-rule count, predicate call/exclusion counts, history-reveal request result and the native visible-notification count if available. It contains no app or notification identifiers. Native visible counts may represent groups differently from the index; these values are evidence for troubleshooting, not an assertion of equivalence.

### iOS 17 mount

The alpha3 device report confirmed notification reading but rejected its collection-view resolver. The iOS 17 runtime headers declare `masterListView` as `NCNotificationListView : UIScrollView`. The adapter checks that getter first, then `scrollView`, and verifies the native class and ownership. Its bounded fallback accepts exactly one outer native list; it skips arbitrary scroll views and their card descendants. A checked `collectionView` getter remains available for alternate layouts.

The selector mounts as a scrolling header with a reversible top inset. Scroll to the top of the notification list to find it. Disabling, leaving the list or detaching removes its reserved space. The native card views, data source and delegate are not replaced.

The CI simulator test covers both a real UICollectionView and a UIScrollView test double named NCNotificationListView. It checks mounting, card separation, repeated layouts, disabling, detaching, resolver ambiguity and foreign-view rejection, unsafe getters, report privacy and request correlation. The test double does not emulate Apple's private list layout; a passing test does not establish iOS 17 device compatibility.

### Device troubleshooting

After updating, respring, enable Axon, and open the Lock Screen with notifications present. Scroll to the top of the notification list. If the selector is absent, return to **Settings → Axon Reborn → Check SpringBoard → Copy Layout Report**, then paste the report with your test result.

The status describes the last observed Lock Screen presentation, not complete compatibility. The report contains runtime view class names, geometry, getter result types and whether the rail intersects the list viewport. It does not include notification text, application or notification identifiers, accessibility labels, object descriptions or screenshots. Reports stay in memory until a diagnostic request; the latest requested report is shared locally through a separate preferences domain and is copied only when you tap the copy action. There is no network upload. A request token prevents an older report from being shown as the current reply.

A timeout means no reply was received; it does not by itself prove injection is disabled. A reply without a matching alpha7 report can indicate an old SpringBoard process or blocked diagnostic preference sharing. Respring after upgrading.

## Development safety and limitations

1. No device or OS/jailbreak combination has been certified. Do not distribute as stable or install on a primary device as a validated release.
2. iOS 17 filtering uses native app-filter rules and preserves the original native predicate; iOS 15–16 use list insert/remove operations modeled after Axon. Neither adapter intentionally clears the notification dispatcher/store. Private APIs can still change behavior even when signatures match.
3. The adapter only supports the structured list's one-request methods returning `void` or `BOOL`. Unknown signatures, missing classes or incomplete initial snapshots disable filtering.
4. On a replay failure the adapter attempts to restore All and disables itself for that controller. Restoration is best-effort. If it fails, disable the tweak and respring through the jailbreak's existing controls.
5. Grouped/coalesced notification counts, bulk clears, Focus, Scheduled Summary, notification list modes, media controls, native quick actions, rotation, concurrent list controllers and authentication need physical-device tests. Counts represent distinct requests observed by this adapter and are not yet guaranteed to equal every visually nested notification.
6. No notification body export, analytics or network endpoint is implemented. The optional layout report is limited to structural UI metadata. Native request objects are retained temporarily in process memory for filtering; these objects may themselves contain message content.
7. The user's alpha3 diagnostic confirmed injection, the enabled preference and notification reading on iOS 17 RootHide Bootstrap. The user's alpha4 screenshot confirmed capsule mounting. The alpha5 report confirmed taps and predicate execution but zero visible notifications. Alpha6 device reports confirmed filter restoration but unrevealed child sections, with List mode selected. Alpha7 coordinator integration still requires device verification.
8. iOS 17 mounts in the checked native notification scroll view with reserved top content inset. iOS 15–16 retain the guarded adjunct-stack adapter. Unsupported or ambiguous layouts leave the native presentation active.

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
- https://github.com/MTACS/iOS-17-Runtime-Headers/tree/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/UserNotificationsUIKit.framework (native list class and getter declarations)
- https://theos.dev/docs/rootless
- https://github.com/roothide/Developer
- https://github.com/roothide/Bootstrap/releases
- https://github.com/opa334/Dopamine
- https://github.com/palera1n/palera1n
