#import "HBSession.h"
#import "HBDashboardController.h"
#import "HBPreferences.h"
#import "HBPolicy.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

static const void *HBSessionKey = &HBSessionKey;
static NSHashTable<HBSession *> *sessions;

// Validate the ABI as well as the selector before messaging an undocumented API.
static BOOL HBObjectGetter(id object, SEL selector) {
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    return signature && signature.numberOfArguments == 2 && signature.methodReturnType[0] == '@';
}
static id HBGetObject(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return HBObjectGetter(object, selector) ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}
static UIView *HBGetView(id object, NSString *name) {
    id value = HBGetObject(object, name);
    return [value isKindOfClass:UIView.class] ? value : nil;
}
static CGRect HBLayoutRect(UIView *view, UIView *ancestor) {
    CGRect rect = view.bounds;
    for (UIView *node = view; node && node != ancestor; node = node.superview) {
        // Layout geometry, without cancelling Apple's live presentation transforms.
        // Bounds origins still account for scroll offsets; no native property is set.
        rect.origin.x += node.layer.position.x - node.layer.anchorPoint.x * node.bounds.size.width - node.bounds.origin.x;
        rect.origin.y += node.layer.position.y - node.layer.anchorPoint.y * node.bounds.size.height - node.bounds.origin.y;
    }
    return rect;
}
static BOOL HBCoversViewport(UIView *view, UIView *viewport, BOOL exact) {
    if (!view || !viewport || ![view isDescendantOfView:viewport]) return NO;
    CGRect rect = HBLayoutRect(view, viewport), bounds = viewport.bounds;
    if (!isfinite(rect.origin.x) || !isfinite(rect.origin.y) || !isfinite(rect.size.width) || !isfinite(rect.size.height)) return NO;
    if (!exact) return CGRectContainsRect(CGRectInset(rect, -2, -2), bounds);
    return fabs(CGRectGetMinX(rect) - CGRectGetMinX(bounds)) <= 2 &&
        fabs(CGRectGetMinY(rect) - CGRectGetMinY(bounds)) <= 2 &&
        fabs(rect.size.width - bounds.size.width) <= 2 && fabs(rect.size.height - bounds.size.height) <= 2;
}
static UIEdgeInsets HBProtectedInsets(UIViewController *host) {
    UIView *root = host.view;
    UIEdgeInsets safe = root.safeAreaInsets, windowSafe = root.window.safeAreaInsets;
    safe.top = MAX(safe.top, windowSafe.top); safe.bottom = MAX(safe.bottom, windowSafe.bottom);
    safe.left = MAX(safe.left, windowSafe.left); safe.right = MAX(safe.right, windowSafe.right);
    // Control Center's status/privacy header can sit below the normal status bar.
    // Reserve it without hiding, moving, or intercepting Apple's controls.
    for (NSString *name in @[@"overlayHeaderView", @"overlayLeadingStatusBar"]) {
        UIView *header = HBGetView(host, name);
        if (!header || header.hidden || header == root || ![header isDescendantOfView:root]) continue;
        CGRect rect = HBLayoutRect(header, root);
        CGFloat bottom = CGRectGetMaxY(rect) - CGRectGetMinY(root.bounds);
        if (isfinite(bottom) && rect.size.height > 0 && bottom > 0 && bottom < root.bounds.size.height * 0.5)
            safe.top = MAX(safe.top, bottom + 8);
    }
    return safe;
}
static BOOL HBExpandedCount(id collection, NSUInteger *count) {
    SEL selector = NSSelectorFromString(@"expandedModuleCount");
    NSMethodSignature *signature = [collection methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 2 || strcmp(signature.methodReturnType, @encode(NSUInteger)) != 0) return NO;
    *count = ((NSUInteger (*)(id, SEL))objc_msgSend)(collection, selector);
    return YES;
}
static NSString *HBFindModule(UIViewController *controller, HBSystemDestination destination, NSUInteger depth) {
    if (depth > 4) return nil;
    id identifier = HBGetObject(controller, @"moduleIdentifier");
    if ([identifier isKindOfClass:NSString.class]) {
        NSString *name = [identifier lowercaseString];
        if (destination == HBSystemDestinationConnections && [name containsString:@"connectivity"]) return identifier;
        if (destination == HBSystemDestinationFocus && ([name containsString:@"donotdisturb"] || [name containsString:@"focus"])) return identifier;
        if (destination == HBSystemDestinationVolume && [name containsString:@"volume"]) return identifier;
    }
    for (UIViewController *child in controller.childViewControllers) {
        NSString *found = HBFindModule(child, destination, depth + 1);
        if (found) return found;
    }
    return nil;
}

@interface HBSession ()
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, weak) UIView *nativeView;
@property (nonatomic, strong) HBDashboardController *dashboard;
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL nativeRequested;
@property (nonatomic) BOOL ownsHiddenState;
@property (nonatomic) BOOL originalHidden;
@property (nonatomic) BOOL layingOut;
@end

@implementation HBSession
+ (instancetype)sessionForHost:(UIViewController *)host create:(BOOL)create {
    HBSession *session = objc_getAssociatedObject(host, HBSessionKey);
    if (!session && create) {
        session = [HBSession new];
        session.host = host;
        if (!sessions) sessions = [NSHashTable weakObjectsHashTable];
        [sessions addObject:session];
        objc_setAssociatedObject(host, HBSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return session;
}
+ (void)preferencesChanged {
    HBReloadPreferences();
    for (HBSession *session in sessions.allObjects) {
        [session.dashboard applyAppearance];
        [session layout];
    }
}
- (void)begin {
    if (!self.active) { self.active = YES; self.nativeRequested = NO; }
    HBReloadPreferences();
    [self layout];
}
- (void)restoreNative {
    [self.dashboard setDashboardActive:NO];
    [self.dashboard useBackdropHost:nil];
    if (self.ownsHiddenState) {
        self.nativeView.hidden = self.originalHidden;
        self.ownsHiddenState = NO;
    }
    if (self.dashboard.parentViewController) {
        [self.dashboard willMoveToParentViewController:nil];
        [self.dashboard.view removeFromSuperview];
        [self.dashboard removeFromParentViewController];
    }
}
- (void)layout {
    if (self.layingOut) return;
    self.layingOut = YES;
    @try {
        if (!self.active) { [self restoreNative]; return; }
        UIViewController *host = self.host;
        UIView *root = host.isViewLoaded ? host.view : nil;
        id object = HBGetObject(host, @"moduleCollectionViewController");
        UIViewController *collection = [object isKindOfClass:UIViewController.class] ? object : nil;
        UIView *native = collection.isViewLoaded ? collection.view : nil;
        UIView *container = HBGetView(host, @"overlayContainerView");
        UIView *surface = HBGetView(host, @"overlayScrollView");
        UIView *background = HBGetView(host, @"overlayBackgroundView");
        NSUInteger expanded = 0;
        BOOL hasCount = HBExpandedCount(collection, &expanded);
        BOOL viewportValid = root.window && HBCoversViewport(root, root.window, YES) &&
            [surface isKindOfClass:UIScrollView.class] && surface != root && HBCoversViewport(surface, root, YES) &&
            background && background != root && HBCoversViewport(background, root, NO);
        BOOL valid = viewportValid && container && [container isDescendantOfView:surface] &&
            native && native != container && [native isDescendantOfView:container] && hasCount;
        CGSize size = root.bounds.size;
        BOOL allowed = !UIInterfaceOrientationIsLandscape(root.window.windowScene.interfaceOrientation) &&
            HBShouldPresent((int)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            HBEnabled(), UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone,
            size.width, size.height, valid, self.nativeRequested, expanded > 0);
        if (!allowed) {
            [self restoreNative];
            NSString *reason;
            if (!HBEnabled()) reason = @"Harbor is disabled. Enable Harbor in Settings.";
            else if (self.nativeRequested) reason = @"Native controls requested for this visit. Close and reopen Control Center to return to Harbor.";
            else if (!viewportValid) reason = @"Apple controls retained: a full-window Control Center scroll surface and background are unavailable. No window or clipping overrides were applied.";
            else if (!valid) reason = @"Apple controls retained: the native collection, presentation container, or expanded-module interface is unavailable.";
            else if (expanded > 0) reason = @"Apple controls retained while a native module is expanded.";
            else reason = @"Apple controls retained: Harbor needs an iPhone in portrait with a presentation area of at least 300 × 480 points.";
            HBReportRuntimeStatus(reason);
            return;
        }
        // Reparenting by the system invalidates our old snapshot.
        if (self.ownsHiddenState && (self.nativeView != native || self.dashboard.view.superview != surface)) [self restoreNative];
        if (!self.dashboard) {
            self.dashboard = [HBDashboardController new];
            __weak typeof(self) weakSelf = self;
            self.dashboard.openSystemControls = ^(HBSystemDestination destination) { [weakSelf openSystem:destination]; };
        }
        if (!self.dashboard.parentViewController) {
            [host addChildViewController:self.dashboard];
            // The module container is an inset rectangle, not a screen-sized viewport.
            // Use its existing full-window scroll ancestor, retaining gesture ancestry.
            self.dashboard.view.frame = surface.bounds;
            self.dashboard.view.autoresizingMask = UIViewAutoresizingNone;
            [surface addSubview:self.dashboard.view];
            [self.dashboard didMoveToParentViewController:host];
        }
        self.dashboard.view.frame = surface.bounds;
        UIEdgeInsets protected = HBProtectedInsets(host), inherited = root.safeAreaInsets;
        self.dashboard.additionalSafeAreaInsets = UIEdgeInsetsMake(MAX(0, protected.top - inherited.top),
            MAX(0, protected.left - inherited.left), MAX(0, protected.bottom - inherited.bottom), MAX(0, protected.right - inherited.right));
        // The noninteractive backdrop follows Apple's full-screen background animation;
        // status/privacy views keep their existing z-order above that background.
        [self.dashboard useBackdropHost:background];
        [self.dashboard setDashboardActive:YES];
        if (!self.ownsHiddenState) {
            self.nativeView = native;
            self.originalHidden = native.hidden;
            self.ownsHiddenState = YES;
        }
        // Do this last, after the replacement is successfully constructed.
        native.hidden = YES;
        HBReportRuntimeStatus([NSString stringWithFormat:@"Dashboard displayed in %.0f × %.0f viewport (module panel %.0f × %.0f). All controls stays available below the scrolling cards.",
            size.width, size.height, container.bounds.size.width, container.bounds.size.height]);
    } @catch (NSException *exception) {
        self.nativeRequested = YES;
        [self restoreNative];
        HBReportRuntimeStatus([NSString stringWithFormat:@"Apple controls retained after an exception: %@.", exception.name]);
    } @finally { self.layingOut = NO; }
}
- (void)openSystem:(HBSystemDestination)destination {
    self.nativeRequested = YES;
    [self restoreNative];
    HBReportRuntimeStatus(@"Native controls requested for this visit. Close and reopen Control Center to return to Harbor.");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.nativeView);
    if (destination == HBSystemDestinationAll) return;
    @try {
        id collection = HBGetObject(self.host, @"moduleCollectionViewController");
        if (![collection isKindOfClass:UIViewController.class]) return;
        NSString *identifier = HBFindModule(collection, destination, 0);
        SEL expand = NSSelectorFromString(@"expandModuleWithIdentifier:");
        NSMethodSignature *signature = [collection methodSignatureForSelector:expand];
        if (identifier && signature.numberOfArguments == 3 && signature.methodReturnType[0] == 'v' &&
            [signature getArgumentTypeAtIndex:2][0] == '@') {
            ((void (*)(id, SEL, id))objc_msgSend)(collection, expand, identifier);
        }
        // Unknown module identifiers or selectors intentionally leave all native controls visible.
    } @catch (NSException *exception) { NSLog(@"[Harbor] Native panel unavailable: %@", exception.name); }
}
- (void)end {
    self.active = NO;
    [self restoreNative];
}
- (void)dealloc { [_dashboard setDashboardActive:NO]; }
@end
