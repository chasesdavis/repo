#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include <atomic>
#import "HBSession.h"
#import "HBPreferences.h"

// iOS 17 removed the older CCUIModularControlCenterViewController superclass.
// This name is exported by the 17.0 SDK and declared in the iOS 17 runtime headers.
@interface CCUIModularControlCenterOverlayViewController : UIViewController
@end

%group HarborControlCenter
%hook CCUIModularControlCenterOverlayViewController
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
%hook CCUIModularControlCenterOverlayViewController
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
static std::atomic<bool> hooksInstalled(false), hookCheckQueued(false);
static BOOL HBHasMethod(Class host, NSString *name, char returnType) {
    Method method = class_getInstanceMethod(host, NSSelectorFromString(name));
    char type[16] = {0};
    if (!method || method_getNumberOfArguments(method) != 2) return NO;
    method_getReturnType(method, type, sizeof(type));
    return type[0] == returnType;
}
static void HBTryInstallHooks(void) {
    // Only called on the main queue, after dyld has finished adding the image.
    if (hooksInstalled.load() || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 17) return;
    Class host = NSClassFromString(@"CCUIModularControlCenterOverlayViewController");
    if (!host) return;
    if (![host isSubclassOfClass:UIViewController.class] ||
        !HBHasMethod(host, @"moduleCollectionViewController", '@') ||
        !HBHasMethod(host, @"overlayContainerView", '@')) {
        HBReportRuntimeStatus(@"Apple controls retained: the Control Center host interface is incompatible.");
        return;
    }
    %init(HarborControlCenter, CCUIModularControlCenterOverlayViewController=host);
    Method activate = class_getInstanceMethod(host, NSSelectorFromString(@"_reparentAndBecomeActive"));
    Method resign = class_getInstanceMethod(host, NSSelectorFromString(@"_resignActive"));
    char activeReturn[8] = {0}, resignReturn[8] = {0};
    if (activate && resign) {
        method_getReturnType(activate, activeReturn, sizeof(activeReturn));
        method_getReturnType(resign, resignReturn, sizeof(resignReturn));
        if (method_getNumberOfArguments(activate) == 2 && method_getNumberOfArguments(resign) == 2 &&
            activeReturn[0] == 'v' && resignReturn[0] == 'v') {
            %init(HarborActivation, CCUIModularControlCenterOverlayViewController=host);
        }
    }
    hooksInstalled.store(true);
    HBReportRuntimeStatus(@"Control Center hooks ready. Open Control Center in portrait.");
}
static void HBQueueHookCheck(void) {
    if (hooksInstalled.load() || hookCheckQueued.exchange(true)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        hookCheckQueued.store(false);
        HBTryInstallHooks();
    });
}
static void HBImageAdded(const struct mach_header *header, intptr_t slide) {
    // No Objective-C, UIKit, dlopen, or hooking inside dyld's callback/loader lock.
    // Coalesce notifications, including images loaded after SpringBoard finishes launch.
    HBQueueHookCheck();
}
%ctor {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        HBReloadPreferences();
        if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 17) {
            HBReportRuntimeStatus(@"Apple controls retained: this build targets iOS 17.");
            return;
        }
        HBReportRuntimeStatus(@"Loaded in SpringBoard; waiting for the Control Center framework.");
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            HBPreferencesDidChange, (__bridge CFStringRef)HBPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        _dyld_register_func_for_add_image(HBImageAdded);
        HBQueueHookCheck();
    }
}
