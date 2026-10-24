# Source audit and design decisions

Reference inspected: dakotadawolfe/axon-ios16-compatibility at `5de63de57c2ccb0fdefb33e374c59e1517b0c040`.

| Observed in the reference source | Decision for this prototype |
|---|---|
| Top-level scheme fixed to `roothide`; subprojects target an older SDK/deployment setting | Shared build configuration, explicit variants, iOS 15 minimum |
| PreferenceLoader files manually copied to an unprefixed staging path | Standard root layout tree staged by the selected Theos scheme |
| Preferences read directly from an absolute mobile path | Shared CFPreferences domain without filesystem prefix assumptions |
| Global single manager/list view and one-time initialization flag | Associated state per native list and per adjunct host |
| Hooks assume private class/method behavior | Exact argument/return-shape checks before registration; snapshot/mount prerequisites |
| Notification interception can return success without forwarding to the original implementation | Only suppress on an initialized adapter after explicit selection; preserve native result otherwise |
| Destructive clear operations call the notification dispatcher | No new native clear action in this version; keep scope to selection |
| A debug observer can write native request descriptions to a document file | No notification debug-export feature |
| Cell/UI state, notification bookkeeping and private integration are closely coupled | Separate portable index, UIKit rail, preferences and runtime adapter |

The source audit is not a report of crashes reproduced on a device. The new adapter still depends on private behavior and must pass the device matrix before release.

## Visual direction

An understated notification shelf sits directly above native cards. App capsules carry a familiar app icon, name and readable count. The selected capsule gains a bright material border. All is always reachable, so filtering does not leave the user guessing how to recover the complete list.

The prototype uses warm amber accents and a dim blue wallpaper to make selection visible without turning the Lock Screen into a second dashboard. The native implementation uses system blur material and the user's existing wallpaper. The webpage clock, wallpaper, sample cards and demo controls are presentation aids, not an attempt to replace those native iOS surfaces.

## Deliberately deferred

Custom notification cards, AI summaries, pinned app editing, snoozing, per-app clearing, vertical sidebars, media reshaping, Live Activity modification and iOS 18+ adapters are outside this first implementation. Each adds native behavior or privacy edge cases that need independent design and testing.
