# Axon Reborn

A complete visual and architectural redesign of Axon's app-grouped Lock Screen notifications. Initial target: **iOS 15–17**, with **rootful**, **rootless**, and **RootHide** package configurations.

**Status: experimental alpha11; RootHide package published to the [Sileo repository](https://chasesdavis.github.io/repo/).** The [validated build](https://github.com/chasesdavis/repo/actions/runs/40131980274) passed all three package variants, portable checks, native runtime contract tests and UIKit regressions. The synthetic native capsule preview was visually inspected. The tester reports that alpha10 looks better; alpha11's Focus behavior and capsule controls still need confirmation on the iOS 17.0 device. This project starts disabled; native notification previews and authentication remain handled by iOS.

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

### Alpha11 Focus and capsule controls

On iOS 17, choosing an app with matching requests in `upcomingMissedSectionList` invokes the summarized section's checked `_expandSection` action after native history reveal. This is the normal Focus platter action: it calls `notificationListComponent:requestsAuthenticationAndPerformBlock:` before revealing content. Axon does not modify Focus mode, sounds, banners, preview policy, authentication or hidden caches. The action is requested only for an explicit matching app selection and can be disabled with **Expand While in Focus**. iOS owns the resulting expansion lifecycle, just as when the user opens the platter manually. A report status of `native-expand-requested` records the request, not proof that authentication completed.

The behavior is based on the [iOS 17.6.1 summarized-section implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationSummarizedSectionList.m). The phone runs iOS 17.0, so device verification remains necessary. The contract test covers inactive Focus, nonmatching/all selection, authentication denial, authorized expansion and an already expanded section.

Capsules now have four accent palettes (Mint, Violet, Ocean, Rose), a distinct selected border and count badge, spring press feedback, and count pulses for arrivals. Reduce Motion suppresses these animations and Reduce Transparency uses solid material. The heading shows the selected app and its count out of all indexed requests. Compact mode keeps other apps small while displaying the selected app's name.

Touch and hold an app for **Pin favorite / Unpin favorite** or **Show all notifications**. Up to 32 favorites persist as app identifiers in local settings and appear first, keeping their pin order. Apps with no notifications remain absent until they have requests again. Regular apps keep the user's recent/count ordering. Tapping the selected app again returns to All; this can be disabled in Settings. Existing buttons survive count-only updates so those refreshes do not discard an in-flight touch.

The UIKit regression checks control identity, selection accessibility, menu availability, persistent pin/unpin ordering and the existing mount geometry. A synthetic capsule preview is captured in the CI log for visual inspection; it contains only test data. Native filtering, restore, and history tests remain in place. No notification content is exported by the tweak.

### Alpha10 selection layout

Alpha9's on-device report shows two matching requests in the native history model, completed programmatic reveal, and a 123-point app group. The rail ends at screen y=302 while the group starts at y=570. The native master uses `setLayoutFromBottom:YES`; `_initialLayoutOffset` then adds bottom-alignment space before the first group. Axon's top inset alone never removed that space. Sources: [master setup](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationMasterList.m) and [list layout](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationListView.m).

While the selector is mounted, alpha10 switches only that master list to top alignment using its checked getter/setter. Native section/card views stay in their existing hierarchy. Filtering and history reveal run normally, then an explicit capsule tap brings the list to its start so a short selection cannot inherit a long list's old offset. Active tracking, dragging and deceleration are not interrupted. Hiding or detaching the rail restores its prior alignment and reserved inset. An unsupported alignment interface rejects the mount.

The simulator regression fixture starts with the reported 375×812 geometry and a bottom-aligned short group, then checks that the group starts directly below the selector. It also covers short/long/empty lists, a stale scroll offset, finger tracking, repeated layout, native reconfiguration, and restoring both originally bottom-aligned and top-aligned lists. This fixture reproduces the layout conflict, not Apple's private implementation. The phone still needs to confirm card rendering, scrolling and native actions.

### Alpha9 native reveal and diagnostic correction

The alpha8 device report recorded a revealed history list with five cached child views, while the coordinator's gesture flag was false and its state lock was true. The previous adapter misclassified this combination as hidden.

Inspection of the [iOS 17.6.1 coordinator implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationListRevealCoordinator.m) shows that programmatic reveal updates the actual state and reveal percentage, and locks the interaction state, without setting the gesture's `sectionRevealed` flag. That flag is not a reliable test for whether programmatic reveal completed. The [master-list implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationMasterList.m) also shows that `visibleNotificationCount` counts incoming content above history, rather than all rendered history notifications. Earlier alpha6–8 interpretations of those fields were incorrect and are superseded here.

Alpha9 uses the normal controller history request, checks the coordinator's `_isRevealed` result and refreshes newly created sublist views using that native state. It removes direct gesture-flag changes, the inferred lock rejection and the extra history-visibility update. Native reveal policy still takes precedence. An empty-history transition gate is handled without a false error for incoming-only selections. A pending native request is reported without manufacturing a reveal state. Cleanup restores Axon's app filters and leaves normal presentation cleanup to iOS.

The [section-list implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationStructuredSectionList.m) distinguishes configured view defaults from current presentation and includes authentication-related hidden-cache handling. Hidden requests therefore remain owned by iOS; Axon does not change authentication, preview permissions or those caches.

Reports label the raw count as above-history content, include actual reveal state/percentage and distinguish the gesture flag. They preserve both the selection-settled summary and the later presentation sample. Native list coordinates are converted into the master viewport, and cached child views are counted without reading their contents. A cached-view count is not a count of readable notification cards or proof of correct filtering.

The reference implementation is iOS 17.6.1; the test phone runs iOS 17.0. Runtime signature checks and simulator contract tests reduce adapter errors but do not establish equivalence between those versions. The tests cover programmatic reveal with a false gesture flag, native policy and identity changes, empty history, pending requests, view geometry, privacy and retention of separate samples. Physical app-selection testing remains required.

### Alpha5 iOS 17 selection

Alpha4 mounted the capsules on the test device, but the user reported that selecting an app did not show its cards and other apps remained visible when revealing history.

Alpha5 uses the checked native `toggleFilteringForSectionIdentifier:shouldFilter:` interface for existing app groups on iOS 17. It also hooks `notificationMasterList:shouldFilterNotificationRequest:` to preserve the native decision and add the selected-app restriction for incoming requests. The iOS 17 event hooks now forward insert, remove and modify operations to iOS instead of suppressing or replaying request lifecycles for presentation filtering. iOS 15–16 retain the earlier adapter.

Selecting an app or All requests native history reveal after layout. Repeated appearance callbacks in the same active presentation no longer reset selection. All, disabling and leaving the list restore only app rules owned by Axon; exclusions reported by the original native policy are retained. A partial mutation failure attempts rollback and disables that controller's filter.

Simulator contract tests exercise the actual runtime reconciliation code against a fake controller: switching apps, All, native policy precedence, arrivals and dismissals, repeated appearance, history reveal, disappearance cleanup and partial-failure rollback. Capsule UIAction dispatch is also tested. These tests validate our control flow and method contract, not Apple's private implementation. On-device filtering and history presentation still need verification.

The copyable report adds selection-tap count, selected/all state, expected request count, applied app-rule count, predicate call/exclusion counts, history-reveal request result and the native visible-notification count if available. It contains no app or notification identifiers. Native visible counts may represent groups differently from the index; these values are evidence for troubleshooting, not an assertion of equivalence.

### iOS 17 mount

The alpha3 device report confirmed notification reading but rejected its collection-view resolver. The iOS 17 runtime headers declare `masterListView` as `NCNotificationListView : UIScrollView`. The adapter checks that getter first, then `scrollView`, and verifies the native class and ownership. Its bounded fallback accepts exactly one outer native list; it skips arbitrary scroll views and their card descendants. A checked `collectionView` getter remains available for alternate layouts.

The selector mounts as a scrolling header with a reversible top inset and, since alpha10, a reversible top-alignment setting on the master list. Scroll to the top of the notification list to find it. Disabling, leaving the list or detaching removes its reserved space. The native card views, data source and delegate are not replaced.

The CI simulator test covers both a real UICollectionView and a UIScrollView test double named NCNotificationListView. It checks mounting, card separation, repeated layouts, disabling, detaching, resolver ambiguity and foreign-view rejection, unsafe getters, report privacy and request correlation. The test double does not emulate Apple's private list layout; a passing test does not establish iOS 17 device compatibility.

### Device troubleshooting

After updating, respring, enable Axon, and open the Lock Screen with notifications present. Scroll to the top of the notification list. If the selector is absent, return to **Settings → Axon Reborn → Check SpringBoard → Copy Layout Report**, then paste the report with your test result.

The status describes the last observed Lock Screen presentation, not complete compatibility. The report contains runtime view class names, geometry, getter result types and whether the rail intersects the list viewport. It does not include notification text, application or notification identifiers, accessibility labels, object descriptions or screenshots. Reports stay in memory until a diagnostic request; the latest requested report is shared locally through a separate preferences domain and is copied only when you tap the copy action. There is no network upload. A request token prevents an older report from being shown as the current reply.

A timeout means no reply was received; it does not by itself prove injection is disabled. A reply without a matching alpha11 report can indicate an old SpringBoard process or blocked diagnostic preference sharing. Respring after upgrading.

## Development safety and limitations

1. No device or OS/jailbreak combination has been certified. Do not distribute as stable or install on a primary device as a validated release.
2. iOS 17 filtering uses native app-filter rules and preserves the original native predicate; iOS 15–16 use list insert/remove operations modeled after Axon. Neither adapter intentionally clears the notification dispatcher/store. Private APIs can still change behavior even when signatures match.
3. The adapter only supports the structured list's one-request methods returning `void` or `BOOL`. Unknown signatures, missing classes or incomplete initial snapshots disable filtering.
4. On a replay failure the adapter attempts to restore All and disables itself for that controller. Restoration is best-effort. If it fails, disable the tweak and respring through the jailbreak's existing controls.
5. Grouped/coalesced notification counts, bulk clears, Focus, Scheduled Summary, notification list modes, media controls, native quick actions, rotation, concurrent list controllers and authentication need physical-device tests. Counts represent distinct requests observed by this adapter and are not yet guaranteed to equal every visually nested notification.
6. No notification body export, analytics or network endpoint is implemented. The optional layout report is limited to structural UI metadata. Native request objects are retained temporarily in process memory for filtering; these objects may themselves contain message content.
7. The user's alpha3 diagnostic confirmed injection, the enabled preference and notification reading on iOS 17 RootHide Bootstrap. The user's alpha4 screenshot confirmed capsule mounting. The alpha5 report confirmed taps and predicate execution but zero visible notifications. Alpha6–8 reports confirmed app-filter restoration, but their reveal-state interpretation was incorrect. Alpha9 confirmed matching filtered requests and completed native reveal on device, but the tester still reported incorrect presentation. Alpha10 addresses the bottom-aligned layout gap, and the tester subsequently reported that it looks better. Full native behavior and alpha11's new Focus/capsule controls still need device verification.
8. iOS 17 mounts in the checked native notification scroll view with reserved top content inset and reversible top alignment. iOS 15–16 retain the guarded adjunct-stack adapter. Unsupported or ambiguous layouts leave the native presentation active.

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
