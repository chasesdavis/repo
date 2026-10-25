# Beta2 device acceptance record

Status: NOT RUN. Fill this from observations on the actual phone; do not infer results from CI.

## Environment
- Device/model:
- iOS version and full build:
- Bootstrap/jailbreak and version:
- SpringBoard injection method:
- Installed package version: 0.2.0~beta2
- Other notification/Lock Screen tweaks:
- Test date:
- Build/source commit: `ac6bf4fdfd8fec35cdf4dc9eff9501135aca64ac` / [40146059731](https://github.com/chasesdavis/repo/actions/runs/40146059731)

## First acceptance pass
Use synthetic notifications from three apps, including two conversations in one app. Record Pass / Fail / Not run and a short observation.

| Scenario | Result | Observation |
|---|---|---|
| Upgrade from beta1, respring, preferences retained | Not run | |
| All shows the expected native cards | Not run | |
| Each capsule shows only its app; tap again restores All | Not run | |
| Arrivals and dismissals update counts without changing the selected app | Not run | |
| Last selected notification disappears and All restores correctly | Not run | |
| A held capsule and horizontal scrolling remain steady during arrivals | Not run | |
| Pin/unpin and Move favorite first persist across presentations | Not run | |
| Slim/Balanced/Roomy retain the same clock clearance; system text remains readable | Not run | |
| Focus selection expands through normal authentication | Not run | |
| Denied authentication leaves protected content protected | Not run | |
| Focus still governs sounds and banners | Not run | |
| Native reply, long press, swipe and tap-to-open work | Not run | |
| Use native notifications restores the ordinary list | Not run | |
| Reset appearance preserves Enabled and Expand While in Focus | Not run | |
| Capsule presses/count changes/selection have no Axon animation | Not run | |
| Show All capsule off/on; Show all notifications menu still works | Not run | |
| Clear confirmation Cancel keeps all notifications | Not run | |
| Confirmed app clear preserves other apps and later arrivals | Not run | |
| Clear selected app at the end keeps viewport and selects left neighbor | Not run | |
| Clear selected middle app selects next right neighbor | Not run | |
| Clear unselected app preserves current selection | Not run | |
| No SpringBoard crash, missing cards or duplicated requests | Not run | |

If a case fails: note the selected display mode (List/Stack/Count), Focus state, locked/unlocked state and the exact steps. Use Settings → Axon Reborn → Check SpringBoard → Copy Layout Report. Reports intentionally omit notification text and app identifiers; do not add private message content to the bug report.

## Stable-promotion gates
- [ ] Above pass completed without a reproducible P0/P1 issue
- [ ] Preview privacy modes, Face ID/passcode and native clear behavior checked
- [ ] Full matrix in PREMIUM_RELEASE_PLAN.md completed
- [ ] VoiceOver, RTL, Reduce Motion/Transparency, Increase Contrast and Low Power Mode checked
- [ ] 100 presentations and ten resprings completed without a regression
- [ ] Overnight use and Instruments comparison against disabled baseline recorded
- [ ] Every advertised OS/jailbreak/package combination has its own passing record

A passing simulator build does not complete this record. Keep beta status while any required gate is unobserved or failing.
