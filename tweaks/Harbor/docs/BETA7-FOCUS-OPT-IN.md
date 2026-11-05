# Beta7 Focus access audit — before publication

Audited on 2026-11-05. No physical phone installation, publication, or real Focus setting change was performed. This records the local candidate audit before publication, not a verified phone release. See [PUBLICATION.md](PUBLICATION.md) for the subsequently authorized publication.

## Confirmed beta6 issue

Beta6's `automaticFocus` flag defaulted to false and prevented automatic profile selection, but `HBDashboardController.setDashboardActive:` still created and started `HBFocusMonitor` whenever Harbor opened. Opening the editor and Refresh could also query regardless of that flag. **The off switch did not prevent reading.** This was an implementation gap, separate from the ordinary simulator app's previously confirmed OS entitlement rejection.

The audit found no Focus activation, deactivation, assertion acquisition, mode-configuration writes, system Focus preference writes, or authorization request in the shipping source. That finding does not establish zero risk: these are private interfaces running in SpringBoard on the phone, and native controls have their own behavior.

## Reads, writes and other side effects

| Path | Beta6 behavior and audit finding | Beta7 behavior |
| --- | --- | --- |
| `HBFocusMonitor.m` service factory | Lazily loads DoNotDisturb; `serviceForClientIdentifier:` uses Harbor's own identifier `com.chasedavis.harbor`. No Apple client spoofing. | Same factory, reachable only after saved opt-in through the dashboard gate. |
| Current state | `DNDStateService.queryCurrentStateWithError:`, then `isActive`, `activeModeIdentifier`, `activeModeConfiguration`, `mode` and `name` getters. | Same read-only calls when opted in; signatures checked and requests bounded. |
| Mode catalog | `DNDModeConfigurationService.modeConfigurationsReturningError:`, then `mode`, `modeIdentifier`, `name`. | Same optional read, only after a valid state read. |
| Live changes | `addStateUpdateListener:error:` and `removeStateUpdateListener:`. These register/remove a listener and can cause IPC/service activity; they are not purely side-effect-free operations. | Opt-in only; disabling invalidates callbacks, cancels queued work and cleans up the listener. |
| Preferences | `HBProfileStore.m`, `HBPreferences.m` and the Settings controller write only `com.chasedavis.harbor`: profiles/backups, enable/haptics/palette and runtime report. Mode names/links are stored locally as Harbor preferences after saving. | Adds a versioned opt-in marker to Harbor's library. Recovery cannot re-enable reading. No system Focus domain is written. |
| Notifications/clipboard | Posts only Harbor's preference-change Darwin notification. Diagnostics Copy writes the user's clipboard on explicit tap. | Unchanged. Diagnostics can include mode names when opted in; no report is uploaded automatically. |
| Permissions and packaging | No Focus authorization request, entitlement additions, entitlement spoofing or daemon modification found. Package contains no install/respring scripts. | Unchanged. No attempt to bypass simulator entitlement rejection. |
| Native Focus shortcut | User tap hands off to native CC and calls checked `expandModuleWithIdentifier:`. No toggle is sent. Beta6's substring match could accept a third-party identifier containing “focus”/“donotdisturb”. | Restricted to the observed Apple bundle ID `com.apple.FocusUIModule`. Unknown IDs fall back to all native controls. The label is “Focus controls”; its accessibility hint explains that choosing a mode there can change Focus. |
| Native toggle bridge | `HBNativeControls` allows only Wi-Fi, Bluetooth, Airplane Mode, Cellular, Rotation Lock and Low Power. `focus` is not an activatable key. | Preserved and tested. Native hierarchy enumeration reads module IDs, not current Focus state. |

`setActive:` and `setFocus:` strings in the dylib are Harbor's own synthesized property setters (dashboard/session/media provider, and editor respectively); they are not calls to system Focus setters. Binary string searches alone cannot prove behavior. The inventory below is supporting evidence alongside source call-path review. [Beta6 source hashes and relevant excerpts](beta7/beta6-source-audit.json) preserve the audited starting point.

Apple's own Control Center may read Focus independently. Disabling Harbor's automatic reader does not disable Apple's native Focus UI, and the user can deliberately change a mode there. Expanding that private module on the exact phone is not yet verified.

## Opt-in and recovery behavior

- Fresh installs, legacy beta6 flags, missing/corrupt/unknown opt-in markers and recovered backups keep automatic access off. Profiles, themes, default selection and saved links survive.
- Explicitly turn on **Match Focus automatically** and **Save** to authorize reading. An unsaved On draft makes no calls. Cancel preserves the saved choice. This is Harbor's local preference, not an OS permission grant.
- Turning Off pauses reading immediately, including while a control is held or an editor is open. Save keeps it off; Cancel restores the prior saved choice, including a previously authorized On setting. Closing Harbor discards an unsaved draft.
- When off from startup, no Focus monitor/reader is created, no DoNotDisturb framework load is requested by Harbor, and no Harbor Focus query or subscription starts. Opening diagnostics, Refresh, previews, appearance changes or manual profile selection cannot bypass the gate.
- If previously enabled, queued reads are canceled before service creation when still queued. A worker that already began executing cannot be forcibly recalled; it may complete a service operation after the switch changes. Its result is ignored. Removing an existing or late listener can itself send a cleanup message after disabling. The retained stopped monitor does not poll or register again.
- The off snapshot means **Harbor is not reading**, not “your system Focus is off.” Manual selection: ellipsis → Saved profiles → a profile → Use as default.

## Verification and evidence

Environment: iPhone 15 Pro simulator, **iOS 17.5 (21F79)**, dedicated device `BA8C8DB3-AF39-4017-BC32-34A368185776`. Preview SDK is 26.5, deployment target 17.0. Theos device build uses iPhoneOS17.0 SDK. The simulator was shut down again after testing.

- [Host checks](beta7/host-checks.log): 20 policy, 32 profile-model and 35 Focus coordinator checks passed; Focus/model checks use AddressSanitizer and UndefinedBehaviorSanitizer. Includes three suspended production-reader queues canceled before reaching the service factory.
- [UIKit results](beta7/uikit-tests.log): **141 checks, zero failures**. Includes the 35 coordinator checks, 11 access-gate cases, native Focus toggle rejection, exact module handoff and rejection of a third-party Focus identifier. These totals overlap; they are not 141 separate private-API tests.
- [Touch assertions](beta7/interaction-checks.json): **21 passed, zero failed**, derived from 15 recorded states following actual HID taps. Tests covered opening editor/diagnostics, unsaved On, Cancel, manual Work selection, saved opt-in, immediate Off pause, Cancel restoring saved consent, saved Off, reopen, native handoff and process relaunch. Relevant raw captures are `beta7/01-*.json` through `15-*.json`.
- `tests/FocusPrivacyMain.m` replaces Harbor's own reader methods before constructing the shipping UIKit UI, counts every call, and returns clearly named **Simulated Work** data. It never calls the real Focus service. The success path and opt-in counts are fixture evidence, not working phone Focus integration.
- [Disabled editor](beta7/focus-off-editor.jpg) and [disabled diagnostics](beta7/focus-off-diagnostics.jpg) are inspected screenshots from the touch run. Refresh has no enabled action while off. Native handoff [metrics](beta7/14-native-focus-handoff-gesture.json) show `com.apple.FocusUIModule` expanded with **zero native toggle actions** in the fixture.
- [Package build](beta7/package-build.log), [validation](beta7/package-verification.log) and [beta6/beta7 package audit](beta7/package-audit.json): both have exactly six payload files, a SpringBoard-only injection filter, arm64 + arm64e binary slices and only the Debian control file, with no maintainer scripts. `ldid -e` returns no entitlement document for either binary; `codesign` reports no Apple code signature. This does not imply that injected code lacks the host's permissions.

The legacy-enabled sequence recorded **0 state / 0 catalog / 0 registration** calls until Save. Explicit opt-in made **2 / 1 / 1** calls (the second state read closes the registration gap). Off paused and requested cleanup; diagnostics did not restart it. Cancel restored the saved opt-in; a subsequent saved Off stopped it again. Fresh process relaunch retained the manual Work profile with **0 / 0 / 0**, no monitor created.

Reproduce the scripted checks:

```sh
bash scripts/check.sh
HARBOR_PREVIEW_APP=/tmp/harbor-checks/HarborPreview.app bash scripts/build-preview.sh
# Install/run only in the dedicated simulator; read Documents/test-results.json.
HARBOR_PREVIEW_MAIN=tests/FocusPrivacyMain.m HARBOR_PREVIEW_APP=/tmp/harbor-privacy/HarborPreview.app bash scripts/build-preview.sh
# --seed-legacy seeds only the preview app's Harbor preferences for a fresh HID run.
# Its Documents/focus-privacy.json records calls; gesture-results.json records handoff.
python3 tests/check_focus_privacy_evidence.py  # validates the recorded run
bash scripts/build.sh
bash scripts/verify-package.sh packages/com.chasedavis.harbor_0.1.0~beta7_iphoneos-arm64e.deb
```

## Package identities and remaining limits

| Audited package | Bytes | SHA-256 |
| --- | ---: | --- |
| `com.chasedavis.harbor_0.1.0~beta6_iphoneos-arm64e.deb` | 115254 | `af405691375ca90f6f6a8b68b8eeb17494b8b6a8e85b9f15f46b74aa16ef7b8b` |
| `com.chasedavis.harbor_0.1.0~beta7_iphoneos-arm64e.deb` | 116682 | `70d55b6edf6e13d258e0172b6ab5fcdd0170998058f7b24e13246bd02736d352` |

RootHide package architecture remains `iphoneos-arm64e`; firmware dependencies restrict installation to 17.0.x, with mobilesubstrate-compatible injection and PreferenceLoader. TrollStore alone is insufficient. No support expansion is implied by iOS 17.5 simulator testing.

Physical SpringBoard Focus access, native module identity/presentation, OS-side effects, conflicts with other tweaks, lock-screen behavior, memory and frame pacing remain unverified. Private APIs may change, reject access, stall or crash despite guards. The prior ordinary simulator app denial is documented in [beta6](BETA6-FOCUS.md); beta7 does not bypass it. No claim of zero risk or device readiness is made. Automatic matching can remain off indefinitely while manual profiles, layout editing and themes remain usable.
