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

%group HarborScrollUpdates
%hook CCUIModularControlCenterOverlayViewController
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    [[HBSession sessionForHost:self create:NO] scrollPositionChanged];
}
%end
%end

%group HarborGestureRouting
%hook CCUIModularControlCenterOverlayViewController
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    if ([[HBSession sessionForHost:self create:NO] ownsTouchView:touch.view recognizer:recognizer]) return NO;
    return %orig;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if ([[HBSession sessionForHost:self create:NO] ownsGestureStart:recognizer]) return NO;
    return %orig;
}
- (BOOL)scrollView:(UIScrollView *)scrollView gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    // CCUIScrollView forwards this delegate method for its own pan recognizer.
    if ([[HBSession sessionForHost:self create:NO] ownsGestureStart:recognizer]) return NO;
    return %orig;
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
static BOOL HBGestureMethod(Class host, NSString *name, unsigned arguments) {
    Method method = class_getInstanceMethod(host, NSSelectorFromString(name));
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    char type[16] = {0}; method_getReturnType(method, type, sizeof(type));
    if (type[0] != 'B' && type[0] != 'c') return NO;
    for (unsigned i = 2; i < arguments; i++) { method_getArgumentType(method, i, type, sizeof(type)); if (type[0] != '@') return NO; }
    return YES;
}
static void HBTryInstallHooks(void) {
    // Only called on the main queue, after dyld has finished adding the image.
    if (hooksInstalled.load() || NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 17) return;
    Class host = NSClassFromString(@"CCUIModularControlCenterOverlayViewController");
    if (!host) return;
    if (![host isSubclassOfClass:UIViewController.class] ||
        !HBHasMethod(host, @"moduleCollectionViewController", '@') ||
        !HBHasMethod(host, @"overlayContainerView", '@') ||
        !HBHasMethod(host, @"overlayScrollView", '@') ||
        !HBHasMethod(host, @"overlayBackgroundView", '@') ||
        !HBGestureMethod(host, @"gestureRecognizer:shouldReceiveTouch:", 4) ||
        !HBGestureMethod(host, @"gestureRecognizerShouldBegin:", 3) ||
        !HBGestureMethod(host, @"scrollView:gestureRecognizerShouldBegin:", 4)) {
        HBReportRuntimeStatus(@"Apple controls retained: the Control Center host interface is incompatible.");
        return;
    }
    %init(HarborControlCenter, CCUIModularControlCenterOverlayViewController=host);
    %init(HarborGestureRouting, CCUIModularControlCenterOverlayViewController=host);
    Method scroll = class_getInstanceMethod(host, NSSelectorFromString(@"scrollViewDidScroll:"));
    char scrollReturn[16] = {0}, scrollArgument[16] = {0};
    if (scroll && method_getNumberOfArguments(scroll) == 3) {
        method_getReturnType(scroll, scrollReturn, sizeof(scrollReturn));
        method_getArgumentType(scroll, 2, scrollArgument, sizeof(scrollArgument));
        if (scrollReturn[0] == 'v' && scrollArgument[0] == '@') {
            %init(HarborScrollUpdates, CCUIModularControlCenterOverlayViewController=host);
        }
    }
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
