#import <UIKit/UIKit.h>
#import <notify.h>
#import "LumenPrefs.h"
#import "LumenPill.h"

static BOOL gLumenReady = NO;
static int gLumenNotifyToken = 0;

static void LumenSync(void) {
    if (!gLumenReady) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (LumenEnabled()) {
            [LumenPill.shared attach];
        } else {
            [LumenPill.shared teardown];
        }
    });
}

// The clock keeps its layout slot; it is only made transparent so the other
// status items do not move and the pill can sit on the empty space.
static void LumenStyleClock(id target) {
    UIView *view = (UIView *)target;
    BOOL hide = LumenEnabled() && LumenHideClock();
    CGFloat wanted = hide ? 0.0 : 1.0;
    if (fabs(view.alpha - wanted) > 0.001) {
        view.alpha = wanted;
    }
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    gLumenReady = YES;
    if (gLumenNotifyToken == 0) {
        notify_register_dispatch(LumenPrefsChangedNotification.UTF8String, &gLumenNotifyToken, dispatch_get_main_queue(), ^(int token) {
            LumenSync();
        });
    }
    LumenSync();
}

%end

%hook SBApplicationController

- (void)applicationDidBecomeActive:(id)application {
    %orig;
    LumenSync();
}

%end

%hook UIStatusBarTimeItemView

- (void)didMoveToWindow {
    %orig;
    LumenStyleClock(self);
}

- (void)layoutSubviews {
    %orig;
    LumenStyleClock(self);
}

%end
