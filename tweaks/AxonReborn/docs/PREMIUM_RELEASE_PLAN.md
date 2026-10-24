# Axon Reborn — premium release plan
Date: October 24, 2026
Owner/repository: Chase Davis · chasesdavis/repo
Baseline: alpha11, source cb233b186a2be94bfcc3a4d0d7f06f349def1c26
Implementation milestone: 0.2.0~beta1. Stable 1.0 remains gated on physical-device acceptance.

## Product promise
One tap makes the selected app's native notifications easy to reach. The selector must remain predictable during arrivals, scrolling, authentication and Lock Screen transitions. A premium result combines reliability, readable controls, coherent motion, customization and honest compatibility. No finite test suite can establish a “100% fail-proof” jailbreak tweak; this plan defines observable release criteria instead.

## Evidence and audit
Alpha3–9 device reports exposed multiple native layout and reveal assumptions. Alpha10 corrected the bottom-aligned short-list gap; the tester reports improvement. Alpha11 adds native Focus expansion and redesigned capsules, but its new behavior has not yet received device acceptance.
The source audit found:
1. CFPreferences values are returned without type checking. A malformed array/dictionary supplied for a scalar preference can receive boolValue/integerValue and raise an exception inside SpringBoard.
2. The rail preserves UIButton identity but still removes/re-adds arranged subviews when ordering changes. An arrival can disturb a touch or scrolling gesture.
3. The rail and mount independently duplicate height formulas, while fonts depend on global rather than local traits. Large accessibility text needs a shared size calculation and a stacked heading.
4. Context-menu actions lack explicit VoiceOver alternatives. Pin capacity is bounded, but saved entries need centralized sanitization and usable reorder/reset controls.
5. Icon lookup rescans the request index for each app. App display names are repeatedly queried through private APIs.
6. A selector that becomes unresolvable can leave an existing app filter active. Controller handoff must restore the previous controller's own rules.
7. The validation record still describes the original unbuilt source, despite many successful builds. Release evidence must name the actual commit, artifacts and remaining device checks.

## Release scope and design
### 1. Dependable state and recovery — P0
- Keep one active selection owner; restore the previous owner before handoff.
- If an active selector cannot resolve/mount, attempt to restore All before reporting the adapter failure.
- Never clear the native notification store, change authentication, overwrite Focus rules, or infer visibility from above-history counts.
- Keep generation checks for deferred reveals, native policy preservation and rollback.
- Bound snapshot size; reject incomplete/oversized snapshots before applying filters.
Acceptance: controller-handoff, missing-mount, malformed-snapshot and rollback contract tests pass; unknown interfaces retain native behavior.

### 2. Validated settings — P0
- Central schema for booleans, bounded enum values and favorite identifiers.
- Invalid reads/writes use documented defaults; unknown keys do not create arbitrary preferences.
- Immutable validated cache, refreshed on Darwin preference updates, avoids repeated CFPreferences reads while rendering capsules.
- Reset appearance/favorites without enabling the tweak or changing Focus preferences.
Acceptance: wrong types, out-of-range/fractional values, duplicate/oversized pins, cache refresh and reset isolation tested in the simulator.

### 3. Stable capsule interaction — P0
- Coalesce updates while the horizontal rail or a capsule is being touched.
- Apply the newest pending state when tracking/deceleration ends; no polling timer.
- Keep controls alive and reorder existing arranged views without rebuilding the entire hierarchy.
- Never move the vertical native list during an active finger gesture.
Acceptance: held-button and scroll-deceleration simulations keep current controls/order; final pending state appears after interaction; selection callbacks remain correct.

### 4. Adaptive visual system — P1
- Three densities: Slim, Balanced, Roomy; default Balanced.
- Shared height calculation drives both native inset reservation and the rail.
- Local Dynamic Type traits scale headings, names and badges; accessibility categories stack the heading and total.
- Four existing palettes remain; selected state includes border, badge and accessibility state.
- React live to Reduce Motion, Reduce Transparency, Increase Contrast and power changes.
Acceptance: 320/375/430-point widths, accessibility text categories, density changes, hidden count badges and long names produce nonoverlapping controls and matching insets. Verify light/dark wallpapers physically.

### 5. Accessible navigation — P1
- VoiceOver actions expose pin/unpin, favorite-first and Show All directly.
- Correct singular/plural counts and a selected-app hint that explains tap-again behavior.
- Stable control identity protects accessibility focus during count-only updates.
- All controls retain at least 48-point height.
Acceptance: real UIAccessibilityCustomAction handlers exercise the same paths as menus; selected traits, labels and actions are verified. Real VoiceOver navigation remains a device check.

### 6. Favorites and personalization — P1
- Pin/unpin through long press or VoiceOver; move a pinned app to the front.
- Persist up to 32 bounded app identifiers; absent apps keep their preference but do not create empty capsules.
- Separate controls for density, compact labels, accent, counts, ordering, haptics and motion.
- Motion automatically quiets in Low Power Mode and Reduce Motion.
Acceptance: pin limits/order/reset and multiple preference combinations tested; settings descriptions match native behavior.

### 7. Rendering cost and lifecycle — P1
- Collect icons in one pass over requests, then create app items.
- Cache display names per controller with a bounded cache; tolerate lookup exceptions.
- Keep the existing one-render-per-main-queue-turn batching.
- No persistent timers, background worker, notification-text cache or network traffic.
Acceptance: regression tests verify lookup bounds and state consistency for large fixtures; Instruments on the actual phone must measure selection latency, scroll frame rate, memory and overnight idle cost before stable.

### 8. Support and recovery UX — P1
- “Use native notifications” disables Axon through the normal preference path.
- Confirmed appearance reset restores personalization only.
- Diagnostic report stays bounded and omits application/notification identifiers and message text.
- Settings clearly distinguish build success from on-device support.
Acceptance: reset does not change Enabled or RevealFocus; diagnostics tests still pass; reinstall/disable/re-enable is physically checked.

### 9. Reproducible candidate packaging — P0
- Build rootful, rootless and RootHide independently from the same commit.
- Run portable model tests, runtime contract tests and public UIKit tests.
- Inspect package architecture, firmware bounds, installation paths and both Mach-O slices.
- Produce an auditable release payload containing exact bytes, hashes, source commit and build ID; publish only after all build jobs pass.
- Preserve existing packages and all unrelated repository entries; refresh flat and dists indexes and their compression/checksums.
- Keep the published package a beta until device gates pass.
Acceptance: candidate package bytes and index hashes match CI output and deployed Pages content.

## Ideas considered and deliberately deferred
| Idea | Benefit | Decision |
|---|---|---|
| Multi-app selection and named collections | Useful for work/social bundles | After 1.0; changes single-selection/filter invariants and needs native tests |
| Search by app name | Faster with dozens of apps | After 1.0; avoid a keyboard/search overlay on the Lock Screen until navigation is stable |
| Per-app clear and undo | Faster cleanup | Deferred; would require destructive notification lifecycle operations and genuine undo support |
| Snooze notifications | Useful attention management | Deferred; persistence/scheduling and recovery need a separate design |
| “Unread” badge | Familiar language | Rejected until a reliable read/unread source exists; current badge means indexed notifications |
| Message previews inside capsules | Compact content | Rejected for this release; native cards preserve preview/privacy rules |
| Continuous glow/particles | Visual impact | Rejected; costly on a frequently displayed system surface |
| AI summaries/cloud sync | Novelty | Outside scope; unnecessary notification-content handling |
| Arbitrary OS-version claims | Wider marketing | Rejected; iOS 15–17 test target only, newer versions require evidence and adapters |
| Per-app accent / theme import | More customization | Later; four curated palettes and densities keep the first release coherent |

## Physical-device release gates
Record phone model, exact iOS build, Bootstrap version, injection method and installed conflicting tweaks. For the primary iOS 17.0 RootHide phone:
- Upgrade alpha11 → beta1; preferences preserved; respring; enable/disable twice.
- With apps A/B/C and multiple grouped notifications, select each app, tap again, tap All, receive and dismiss notifications while filtered, remove the last selected notification, and reopen Notification Center.
- Repeat with zero, one, 50, 300 and 1,000 requests; verify no missing/duplicate native cards.
- Focus off/on; allowed/silenced apps; app selection; authentication denied/accepted; Show Previews Always/When Unlocked/Never. Sounds/banners must remain governed by Focus.
- List/Stack/Count presentation, history collapsed/revealed, Lock Screen and unlocked Notification Center, portrait/landscape if available, media controls and large widgets.
- Native swipe actions, reply, long-press and clear still operate on the correct request.
- VoiceOver, Bold Text, largest Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast and Low Power Mode.
- Scroll rapidly while arrivals change order; hold a capsule while a notification arrives; open/close its context menu repeatedly.
- Ten resprings, 100 presentation cycles and an overnight idle/normal-use soak with no reproducible SpringBoard crash.
- Measure frame time, memory and energy against disabled baseline on the same phone. Target no sustained regressions; investigate any repeatable regression rather than guessing universal budgets.

Repeat the core selection/privacy/restore checks on at least one actual iOS 15 and iOS 16 device for each advertised package/OS combination. A compiled package is not a tested support matrix.

## Execution and completion rules
Implement the scoped work, run automated checks, fix failures, inspect artifacts, publish a beta candidate and update the validation record with exact evidence. Stable 1.0 is blocked by missing physical-device results, not by a checkbox in this document. Do not label those checks passed without observation. Any P0 failure blocks stable promotion; preserve the previous downloadable alpha as rollback.

## Release checklist
- [ ] Implementation committed
- [ ] Portable checks passed
- [ ] Native runtime and UIKit tests passed
- [ ] All three packages compiled and inspected
- [ ] RootHide beta candidate published and deployment verified
- [ ] Primary phone acceptance completed
- [ ] Additional advertised OS/package combinations tested
- [ ] Performance and overnight soak completed
- [ ] Stable release approved from actual evidence
