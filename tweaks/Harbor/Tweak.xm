#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "HBSession.h"
#import "HBPreferences.h"

@interface CCUIModularControlCenterViewController : UIViewController
@end

%group HarborControlCenter
%hook CCUIModularControlCenterViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [[HBSession sessionForHost:self create:YES] begin];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[HBSession sessionForHost:self create:YES] begin];
}
- (void)viewDidLayoutSubviews {
    %orig;
    [[HBSession sessionForHost:self create:NO] layout];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [[HBSession sessionForHost:self create:NO] end];
}
%end
%end

%group HarborActivation
%hook CCUIModularControlCenterViewController
- (void)_reparentAndBecomeActive {
    %orig;
    [[HBSession sessionForHost:self create:YES] begin];
}
- (void)_resignActive {
    [[HBSession sessionForHost:self create:NO] end];
    %orig;
}
%end
%end

static void HBPreferencesDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                  const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ [HBSession preferencesChanged]; });
}
static void HBTryInstallHooks(void) {
    static BOOL installed = NO;
    if (installed || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 17) return;
    Class host = NSClassFromString(@"CCUIModularControlCenterViewController");
    if (!host || ![host isSubclassOfClass:UIViewController.class] ||
        !class_getInstanceMethod(host, NSSelectorFromString(@"moduleCollectionViewController"))) return;
    installed = YES;
    %init(HarborControlCenter, CCUIModularControlCenterViewController=host);
    Method activate = class_getInstanceMethod(host, NSSelectorFromString(@"_reparentAndBecomeActive"));
    Method resign = class_getInstanceMethod(host, NSSelectorFromString(@"_resignActive"));
    char activeReturn[8] = {0}, resignReturn[8] = {0};
    if (activate && resign) {
        method_getReturnType(activate, activeReturn, sizeof(activeReturn));
        method_getReturnType(resign, resignReturn, sizeof(resignReturn));
        if (method_getNumberOfArguments(activate) == 2 && method_getNumberOfArguments(resign) == 2 &&
            activeReturn[0] == 'v' && resignReturn[0] == 'v') {
            %init(HarborActivation, CCUIModularControlCenterViewController=host);
        }
    }
    NSLog(@"[Harbor] Control Center presentation hooks ready; runtime layout checks remain enabled.");
}
%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        HBReloadPreferences();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            HBPreferencesDidChange, (__bridge CFStringRef)HBPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_async(dispatch_get_main_queue(), ^{ HBTryInstallHooks(); });
        // The private framework can arrive after the tweak's constructor.
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { HBTryInstallHooks(); }];
    }
}
