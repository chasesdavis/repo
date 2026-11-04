#import "HBSession.h"
#import "HBDashboardController.h"
#import "HBPreferences.h"
#import "HBPolicy.h"
#import <objc/runtime.h>
#import <objc/message.h>

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
        id object = HBGetObject(host, @"moduleCollectionViewController");
        UIViewController *collection = [object isKindOfClass:UIViewController.class] ? object : nil;
        UIView *native = collection.isViewLoaded ? collection.view : nil;
        id containerObject = HBGetObject(host, @"overlayContainerView");
        UIView *container = [containerObject isKindOfClass:UIView.class] ? containerObject : nil;
        NSUInteger expanded = 0;
        BOOL hasCount = HBExpandedCount(collection, &expanded);
        BOOL valid = host.isViewLoaded && container && [container isDescendantOfView:host.view] &&
            native && native != container && [native isDescendantOfView:container] && hasCount;
        CGSize size = container.bounds.size;
        BOOL allowed = HBShouldPresent((int)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            HBEnabled(), UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone,
            size.width, size.height, valid, self.nativeRequested, expanded > 0);
        if (!allowed) {
            [self restoreNative];
            NSString *reason;
            if (!HBEnabled()) reason = @"Harbor is disabled. Enable Harbor in Settings.";
            else if (self.nativeRequested) reason = @"Native controls requested for this visit. Close and reopen Control Center to return to Harbor.";
            else if (!valid) reason = @"Apple controls retained: the native collection, presentation container, or expanded-module interface is unavailable.";
            else if (expanded > 0) reason = @"Apple controls retained while a native module is expanded.";
            else reason = @"Apple controls retained: Harbor needs an iPhone in portrait with a presentation area of at least 300 × 480 points.";
            HBReportRuntimeStatus(reason);
            return;
        }
        // Reparenting by the system invalidates our old snapshot.
        if (self.ownsHiddenState && (self.nativeView != native || self.dashboard.view.superview != container)) [self restoreNative];
        if (!self.dashboard) {
            self.dashboard = [HBDashboardController new];
            __weak typeof(self) weakSelf = self;
            self.dashboard.openSystemControls = ^(HBSystemDestination destination) { [weakSelf openSystem:destination]; };
        }
        if (!self.dashboard.parentViewController) {
            [host addChildViewController:self.dashboard];
            self.dashboard.view.frame = container.bounds;
            self.dashboard.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            // Stay inside Apple's presentation container so its transition transforms
            // and dismissal gestures also apply to Harbor. Never move native modules.
            [container addSubview:self.dashboard.view];
            [self.dashboard didMoveToParentViewController:host];
        }
        self.dashboard.view.frame = container.bounds;
        [self.dashboard setDashboardActive:YES];
        if (!self.ownsHiddenState) {
            self.nativeView = native;
            self.originalHidden = native.hidden;
            self.ownsHiddenState = YES;
        }
        // Do this last, after the replacement is successfully constructed.
        native.hidden = YES;
        HBReportRuntimeStatus(@"Dashboard displayed. All controls restores Apple's controls for the current visit.");
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
