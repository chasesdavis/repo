# Harbor 0.1.0~beta2 device acceptance

Not executed on a physical phone. Record exact firmware, phone model, Bootstrap/RootHide version, injection runtime, and any other Control Center tweaks before testing. Start with other Control Center replacements disabled to isolate compatibility.

| Check | Expected result | Status |
| --- | --- | --- |
| Install and restart SpringBoard | SpringBoard launches normally; Settings shows Harbor | Pending |
| Settings → Harbor → Refresh status | Shows a current beta2 SpringBoard report; master switch defaults on | Pending |
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
| Palette and haptics from both menus | Settings and in-panel preferences agree after reopening | Pending |
| Observe CPU/memory while CC is closed | No Harbor timers/polling; repeated presentation does not grow memory | Pending |
| Disable/uninstall | Original Control Center restored | Pending |

Beta1 has confirmed integration defects; use the corrected beta2 candidate for this checklist. If Harbor never appears, inspect **Settings → Harbor → Refresh status** and the `[Harbor 0.1.0~beta2]` log lines. Confirm actual SpringBoard injection, not merely TrollStore installation. Unsupported class, ABI, view size, or hierarchy retain native Control Center with a diagnostic. Record the exact firmware and Bootstrap version. If the pane is absent, check PreferenceLoader and Settings injection, restart Settings, and verify that the installed package version is beta2. A successful static package inspection does not establish on-device PreferenceLoader behavior.

Connections/Focus are shortcuts into the native interface. Harbor does not implement independent radio, Focus, flashlight, or screen-recording toggles in this version. All native controls remain available through All controls. Returning from native mode currently requires closing and reopening Control Center.
