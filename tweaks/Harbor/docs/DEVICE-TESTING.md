# Harbor device acceptance — current candidate 0.1.0~beta7

Not executed on a physical phone. Record exact firmware, phone model, Bootstrap/RootHide version, injection runtime, and any other Control Center tweaks before testing. Start with other Control Center replacements disabled to isolate compatibility.

| Check | Expected result | Status |
| --- | --- | --- |
| Install and restart SpringBoard | SpringBoard launches normally; Settings shows Harbor | Pending |
| Settings → Harbor → Refresh status | Shows a current beta7 report with viewport/panel dimensions; master switch defaults on | Pending |
| Full-screen surface | Backdrop reaches the screen edges; content reserves native status/privacy and home-indicator areas | Pending |
| Short screen and largest text | Connections/Focus scroll fully into view; All controls remains pinned and tappable | Pending |
| Open Control Center, portrait | Harbor appears without clipping status/privacy indicators | Pending |
| All controls | Original controls reappear immediately and remain interactive | Pending |
| Close and reopen 20 times; interrupt swipes | No accumulating views, stuck hidden modules, or animation jumps | Pending |
| Connections, then long press individual radios | Native connectivity panel and details behave as before | Pending |
| Focus | Native focus chooser opens; chosen mode is reflected by the system | Pending |
| Turn master switch off while CC is visible | Native controls restore without a restart | Pending |
| Rotate, including mid-presentation | Landscape remains native; return to portrait is stable | Pending |
| Open on lock screen with CC allowed and disallowed | Existing access policy remains enforced | Pending |
| Speaker, headphones, Bluetooth, AirPlay | Native volume/routing work; unsupported routes show a usable fallback | Pending |
| Drag brightness, change auto-brightness, close/reopen | Actual screen brightness follows; slider resynchronizes; min 2% | Pending |
| Local music, streaming, paused, stopped, no session | Metadata/transport are correct; empty controls disabled; no stale artwork | Pending |
| Track with skip prohibited | Skip controls disabled | Pending |
| Close CC while metadata/artwork arrives | No callback updates detached UI; no crash | Pending |
| Receive a call, lock device, route disconnect | Media/volume reconcile on next presentation | Pending |
| VoiceOver | Logical navigation and actionable labels; hidden native controls are not announced | Pending |
| Largest text, Reduce Motion, Reduce Transparency | Readable vertical layout; reachable controls; no motion surprise | Pending |
| Editor theme and Settings haptics | Saved selections persist after reopening | Pending |
| Observe CPU/memory while CC is closed | No Harbor timers/polling; repeated presentation does not grow memory | Pending |
| Disable/uninstall | Original Control Center restored | Pending |

Use beta7 for this checklist only after an authorized installation. If Harbor never appears, inspect **Settings → Harbor → Refresh status** and the `[Harbor 0.1.0~beta7]` log lines. Confirm actual SpringBoard injection, not merely TrollStore installation. Unsupported class, ABI, viewport, or hierarchy retain native Control Center with a diagnostic. Record the exact installed package version, firmware, and Bootstrap version. If the pane is absent, check PreferenceLoader and Settings injection and restart Settings.

The radio circles forward existing native control actions. Connections/Focus and expanded shortcuts open native interfaces. Harbor does not activate Focus or start recording itself. All native controls remain available through All controls. Returning from native mode currently requires closing and reopening Control Center.

## Beta4 compact-sheet acceptance (still pending on the phone)

Confirm Sileo’s installed version before attributing a screenshot to a build. Beta4 is currently a local candidate, not a published update. Check the chevron expands/collapses reliably, normal compact controls all fit, and actual upward finger swipes reach the last expanded row on short/large-text layouts. Verify All controls, native header/home/blank-area dismissal, interrupted opening, rotation, lock screen and repeated visits.

Connectivity/rotation/low-power must reflect and change real system state; missing controls must hand off to native UI rather than show invented state. Test brightness with a continuous drag and verify the screen changes, and volume against an actual output route. Expanded shortcuts open native panels. Check the display/audio identifiers on the exact phone. The simulator’s button fixtures and 16.67 ms sample do not prove physical-device effects or smoothness.

## Beta5 acceptance still requiring a phone

- Open ellipsis → Edit layout & theme. Verify Save/Cancel, copy/rename/delete, group drag handles, compact/expanded visibility, custom colors/materials and repeated open/close.
- Verify Focus lists actual modes, exact links select the intended profiles, off/unlinked/failed queries use the chosen default, and live updates continue across repeated dismissals. The simulator app was denied service access; this is not yet confirmed in SpringBoard.
- Change Focus while dragging a slider, scrolling, or editing; changes should wait for the interaction to end without losing the draft.
- Lock/unlock and dismiss Control Center with an editor or color picker open. Confirm native lifecycle/recovery and no stranded modal. Unsaved drafts should be discarded on closing Control Center.
- Check active-control state, brightness/volume/media/AirPlay effects, larger text, Reduce Motion/Transparency, repeated layout/profile switches and device frame pacing with the installed tweak set.
- Master disable and All controls must still restore the existing native interface. Test the established safe-mode recovery before considering a public release.

## Beta6 Focus acceptance still requiring a phone

- Open editor → Focus → Focus diagnostics. Confirm version, **SpringBoard** process and actual runtime; record State, Updates and Catalog independently. Copy retains the report locally. A successful State with failed Catalog can still link the currently active mode. Failed Updates requires reopening/manual refresh.
- Link two actual returned modes to different profiles. Test exact switches, Focus off, an unlinked mode and disabled automatic matching. Preserve the chosen default and all saved links if any query becomes unavailable.
- Switch Focus while holding a control, scrolling or editing. Old/expired callbacks must not apply the wrong profile or interrupt the interaction. Close/reopen repeatedly and confirm subscriptions recover.
- Verify diagnostics scrolling at largest text, Copy, manual Refresh and Cancel without a profile revision change. Use the normal native Focus controls to change modes; Harbor's adapter is read-only.
- The simulator daemon explicitly rejected the ordinary preview app for lacking valid entitlements. This establishes that preview limitation only. Do not report phone Focus support until its own diagnostics and real transitions pass.

## Beta7 opt-in acceptance still requiring a phone

Keep automatic Focus matching off unless the user chooses to test it. Nothing in this checklist authorizes changing their real Focus status.

- With matching off, open/close Harbor, edit themes, select manual profiles and open diagnostics. Verify no Harbor Focus monitor, service query or subscription starts. Diagnostics must say reading is off, without asserting that system Focus is off.
- Verify an old beta6 enabled flag cannot start reading without a fresh On + Save. Corrupt-primary backup recovery must preserve layouts/links but keep access off.
- An unsaved On draft must not start reading. If the user later opts in, Off must pause immediately; Save keeps it off, while Cancel restores the saved choice. Account for an in-flight call finishing or listener cleanup after disable.
- Native Focus controls are separate. A shortcut tap should only open Apple's identified module; it must not toggle Focus. Avoid selecting a mode unless the user intends to change it. The iOS 17.5 simulator identifier is evidence, not confirmation for this phone.
- The automatic matching tests above from beta5/beta6 are optional and require the user's explicit opt-in. Real Focus effects and private service behavior are still unverified. See [beta7 audit](BETA7-FOCUS-OPT-IN.md) for exact boundaries and residual risks.
