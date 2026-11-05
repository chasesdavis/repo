# Harbor beta6 — Focus investigation and recovery

Local candidate, November 5, 2026. **Not published or installed on a phone.** The editor, themes, profiles and compact sheet from beta5 remain included. This update fixes Focus lifecycle bugs and makes unavailable service access diagnosable; it does not establish working named Focus switching on a physical device.

## Confirmed simulator root cause

The iOS 17.5 simulator has a running `donotdisturbd` service. A separate read-only probe used Harbor's own client identifier, resolved the expected query signature (`@` return, `^@` error argument), and queried without first registering a listener. It received `BSServiceConnectionErrorDomain` code 3 in 6.38 ms, with the reason `XPC error received on message reply handler`.

The daemon log identifies the probe's PID 11606 immediately before an explicit rejection: **“XPC connection without any valid entitlements tried to connect, will reject”**. This confirms an access restriction on the ordinary preview app, rather than an absent simulator daemon or the listener-first call sequence. The numeric error alone would not establish that cause.

Evidence: [probe result](beta6/focus-probe.json), [correlated daemon log](beta6/service-rejection.log). Log timestamps use the simulator's local time; the probe launched at 02:03 UTC. No signing entitlement, process identity, service permission or Focus setting was changed.

The public `INFocusStatusCenter` probe returned authorization status **0 (NotDetermined)** and `isFocused = false`. That false value is not treated as a verified Focus-off state. Apple's public [Focus Status API](https://developer.apple.com/documentation/intents/infocusstatus) exposes an optional focused/silenced state, not a named mode identifier. The installed iOS 17.0 headers corroborate that limit. Apple's supported [Focus filters](https://developer.apple.com/videos/play/wwdc2022/10121/) let users configure app-specific parameters in Settings. They require a registered app intent and, for work outside the app's own views, an extension. Harbor currently ships a SpringBoard tweak and preference bundle, so that is a separate companion-app design, not an automatic substitute for this read adapter. No companion app or unverified system functionality was added.

## Fixed in Harbor

- **Old timeout affecting a newer query:** beta5 used a shared querying flag and session generation. Query A's deadline could expire while query B was in progress in the same session. Each read now has its own request token.
- **Late and superseded replies:** expired replies cannot switch profiles. Updates received during a query coalesce into one fresh read; the superseded result is discarded. Stop/reopen invalidates previous session callbacks.
- **Optional work delaying usable state:** the current state publishes before mode discovery and observer registration. They run on separate bounded workers with separate deadlines. A catalog/observer failure does not invalidate an exact current mode. Successful observer registration triggers a fresh state read to close the initial subscription gap.
- **Blocked services and cleanup:** at most one request per channel remains pending. Repeated refreshes coalesce; reopening does not create more blocked workers. Listener removal is coalesced, and registration cancelled during closing is removed. A late timed-out read is ignored; a fresh explicit refresh or queued newer event is required to retry. Failed state reads do not start optional service requests or a polling retry loop.
- **Truthful fallback:** unknown, missing identifiers, timeouts and read errors use the saved default and clear stale current-mode data. Existing profile links remain saved. Focus off is only reported after a successful state query. Profile changes still defer during controls, scrolling and editing.

## Diagnostics and manual refresh

Open **Harbor → ellipsis → Edit layout & theme… → Focus**. **Focus diagnostics** shows the build, process, runtime, last completed read, state error and separate observer/catalog status. **Copy** copies the displayed report to the device clipboard; nothing is transmitted. The report is an in-memory snapshot, not a continually updating log. **Refresh Focus** reads again without saving the editor draft or changing the library. A blocked earlier call must finish before another is attempted.

The diagnostics page uses a standard scroll view, Dynamic Type and a fixed navigation bar. It was tested at the largest accessibility category on a 568-point fixture. The final paragraph is reachable, and Copy matches the displayed text. [Normal view](beta6/diagnostics.jpg), [large-text final paragraph](beta6/diagnostics-large.jpg).

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Host ASan + UBSan | 20 policy, 23 profile-model and 31 Focus coordinator checks; zero failures | [Host log](beta6/host-checks.txt) |
| iOS 17.5 UIKit harness | 124 checks; zero failures, including those same 31 Focus coordinator cases | [JSON](beta6/simulator-results.json), [runtime log](beta6/simulator-runtime.log) |
| Actual UIKit interactions | Diagnostics/back/refresh/cancel; saved library unchanged; actual failure retained | [12 capture assertions](beta6/ui-assertions.json), [UI captures](beta6/ui-captures.json) |
| Actual touch scrolling | 53-point body text, 470.33-point viewport, 3265.33-point content; swipes reach offset 2795 | [Before](beta6/focus-ui-large-before-scroll.json), [after](beta6/focus-ui-large-after-scroll.json) |
| Clipboard action | Copy matches the displayed report exactly | Same after-scroll capture |
| RootHide build/package | arm64 + arm64e binaries, iphoneos-arm64e Debian metadata, six-file payload, filter/PreferenceLoader/relocation checks pass | [Build](beta6/build.log), [inspection](beta6/package-verification.txt), [manifest](beta6/build-manifest.json) |

Coordinator tests drive the shipping monitor with controlled service callbacks and deadlines: stale timers, timed-out replies, event coalescing, 100 refreshes during a blocked request, stop/reopen, observer timing, missing identifiers, mode-list bounds and exact default recovery. They do **not** simulate successful real service authorization. The actual service failure and actual UI input results are recorded separately. No constraint-conflict/crash messages appeared in the final harness log. Existing Theos obsolete-linker and sandbox CPU-query warnings do not prevent the successful build.

Package: `packages/com.chasedavis.harbor_0.1.0~beta6_iphoneos-arm64e.deb`, **115254 bytes**. SHA-256: `af405691375ca90f6f6a8b68b8eeb17494b8b6a8e85b9f15f46b74aa16ef7b8b`.

```sh
bash scripts/check.sh
bash scripts/build.sh
bash scripts/verify-package.sh packages/com.chasedavis.harbor_0.1.0~beta6_iphoneos-arm64e.deb
HARBOR_PREVIEW_APP=/tmp/harbor-check/HarborPreview.app bash scripts/build-preview.sh
HARBOR_PREVIEW_MAIN=tests/ProfilesMain.m HARBOR_PREVIEW_APP=/tmp/harbor-ui/HarborPreview.app bash scripts/build-preview.sh
# Independent read-only probe, without an observer or authorization request:
HARBOR_PREVIEW_MAIN=tests/FocusProbeMain.m HARBOR_PREVIEW_APP=/tmp/harbor-probe/HarborPreview.app bash scripts/build-preview.sh
```

## Remaining device validation

The target stays **iOS 17.0, RootHide with actual SpringBoard injection, mobilesubstrate and PreferenceLoader**. TrollStore alone cannot load Harbor. The simulator's 17.5 runtime is not a claim of 17.5 jailbreak support.

The ordinary app's rejection cannot prove whether the existing SpringBoard process on Chase's exact setup can read mode identifiers, enumerate configurations or register updates. These three capabilities must be checked separately using the new diagnostics. Actual Work/Personal/off transitions, repeated close/open, Focus changes during interaction, lock/unlock and real control/performance behavior remain physical-device tests. No entitlement change or bypass is proposed. This is an unpublished beta with a confirmed environment limitation and verified recovery, not a release-ready claim that Focus works on the phone.
