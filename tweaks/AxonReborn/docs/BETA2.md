# Beta2: quiet capsules and predictable clearing

## Changes requested from beta1 phone testing
- Remove capsule bounce/scale, count pulses, animated horizontal scrolling and inherited layout animations. Keep immediate pressed-state feedback and optional haptics.
- Reinterpret Slim/Balanced/Roomy as horizontal spacing. All retain Slim's vertical height; native text scaling remains supported. Existing density preferences keep their value but no longer grow the rail vertically.
- Add Show All capsule, enabled by default. The long-press and VoiceOver Show all notifications actions remain available when it is hidden.
- Add Clear app notifications to the app capsule menu and VoiceOver actions. Confirmation captures one app's current requests, preserves later arrivals and revalidates request identity/controller state before calling the native clear route. Native removal callbacks update counts; no optimistic index deletion.
- When the selected app's final request is removed by that clear action, select the next surviving app in displayed order. At the end, select the nearest remaining app to the left. Favorites are included in that order. An unselected clear preserves the selected app. The horizontal viewport clamps near its existing position; it does not select the All capsule.

## Automated regression coverage
- Saved Motion=YES cannot re-enable old effects; no transform/arrival animations on capsules.
- Each spacing mode keeps the same rail top, height and native card origin in the reproduced iOS 17 geometry. Horizontal padding changes independently.
- ShowAll off/on and the accessible fallback action.
- Clearing at the end of a twelve-app rail retains the end viewport.
- Native clear dispatch contains only captured current identities from the requested app; duplicates, other apps, replaced requests and later arrivals are excluded.
- Right/left neighbor selection, unselected clearing, native rejection, inactive controller and empty-list fallback.
- Existing native filtering, Focus/authentication, restore, preference and large-text regressions remain in the suite.

## Native API evidence and limits
The adapter checks Objective-C signatures for `notificationListBaseComponent:requestsClearingPresentables:` and its delegate `notificationStructuredListViewController:requestsClearingNotificationRequests:`. This is the native card-clearing path, not a global clear or direct store mutation. References: [iOS 17 runtime declaration](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationStructuredListViewController.h) and [iOS 17.6.1 controller implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/UserNotificationsUIKit.framework/NCNotificationStructuredListViewController.m). A matching runtime signature is required on the actual phone; unsupported clear routes show a message to use native controls.

The larger density modes no longer introduce height beyond Slim. This avoids the reported density-dependent clock overlap; it does not certify every Dynamic Type size or Lock Screen arrangement. Clearing is irreversible after confirmation, and does not mute an app or uninstall it. Standard iOS notification animations remain controlled by iOS.

## Candidate validation
Pending native CI, package inspection and publication. Physical checks on iOS 17.0 RootHide: spacing versus clock, long-press confirmation/cancel, selected and unselected clears near both ends, new arrivals during confirmation, Focus, and ShowAll off/on. No physical beta2 pass is claimed.
