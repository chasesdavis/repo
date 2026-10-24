# Device validation and release gates

Every row below is **pending**. An OS number alone is insufficient: record device model, exact OS build, jailbreak and version, injection engine, package scheme and other installed notification tweaks.

| First target | Packaging | Required evidence |
|---|---|---|
| iOS 15 on a compatible jailbroken device | rootful | Correct package paths; successful SpringBoard injection; all cases below |
| iOS 15 on a compatible jailbroken device | rootless | Correct package architecture and rpaths; all cases below |
| iOS 16 on a compatible jailbroken device | rootful/rootless, independently | Separate package install and runtime results for each actual setup |
| iOS 15–17 on an appropriate RootHide environment | roothide | Working SpringBoard injection for that exact version and shared preferences; all cases below |
| iOS 17 on a compatible jailbroken device | rootless | Verified class/selector encodings, snapshot and layout integration |

Do not imply every package scheme exists on every listed device/OS. RootHide's published Bootstrap 2.0 beta 2 release notes explicitly added SpringBoard injection for iOS 16.0–17.0; that fact alone does not establish compatibility of this tweak. Newer releases or other jailbreaks must be checked against their own requirements.

## Build gate

- On macOS, build all three schemes from clean trees using the appropriate Theos distribution. Capture compiler output.
- Inspect each `.deb` with `dpkg-deb -I` and `dpkg-deb -c`. Verify firmware bounds, expected architecture, `PreferenceLoader` entry and preference bundle locations.
- Inspect dylibs with `file`, `lipo -info` and `otool -L`. Check arm64/arm64e slices and load paths for the intended environment. Do not mix files across schemes.
- Confirm the preference bundle can load and its principal class/specifiers work.

## Runtime gate

Use a recoverable test device, initially with competing notification groupers disabled. Use synthetic notifications from at least three apps; include one app with multiple conversations and multiple notifications in a coalesced group.

1. Start with the tweak disabled. Stock Lock Screen/Notification Center must behave normally.
2. Enable, then reopen the Lock Screen. Every existing request remains visible in All and counts match the expected interpretation.
3. Select each app repeatedly, including a horizontally offscreen capsule. No duplicate or missing cards, scrolling jumps, blank notification space or stalled UI.
4. Receive a notification from the selected app and a different app. Verify counts, ordering and stable selection; switching to All restores all requests.
5. Modify a notification; send repeated updates with the same identifier. There must be no duplicates.
6. Dismiss a visible request, the last request in a selected app, a nested coalesced notification, and a whole native group. Ensure nothing reappears after switching filters or reopening the screen.
7. Exercise native Clear All in every filter. Define and document whether hidden groups are cleared; reject unexpected resurrection or silent loss.
8. Test Focus, summaries, notification display modes, media controls, Live Activities, incoming calls, rotation and iPad layout if in scope.
9. Lock/unlock repeatedly; switch between Notification Center and Lock Screen. No stale singleton references or mismatched controller data.
10. Test previews set to Never and When Unlocked before/after Face ID. No sender/title/body appears in the rail, and native content never becomes visible earlier than on stock iOS.
11. Test native tap-to-open, quick reply, long press, swipes, notification actions and passcode entry.
12. Disable while filtering; every hidden request must return. Change settings in RootHide and verify that SpringBoard reads them correctly. Re-enable and confirm a fresh snapshot rather than stale cached requests.
13. Test VoiceOver navigation through updates, large text, Reduce Motion, Reduce Transparency, Increase Contrast and right-to-left layout.
14. Stress with at least 200 requests and rapid arrivals; compare memory, frame pacing and idle CPU with stock. The rail must not run an idle animation loop.
15. Induce adapter refusal on a development build: missing selector, wrong return type, incomplete snapshot. Verify stock behavior and no hook initialization. Force a replay rejection and verify restoration/recovery behavior.

## Release rule

Publish exact passing device/OS/jailbreak combinations. Keep every untested combination marked experimental. Do not label “iOS 15–17 supported” solely because compilation succeeds or the control file permits installation.
