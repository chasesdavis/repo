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
        UIViewController *host = self.host;
        id object = HBGetObject(host, @"moduleCollectionViewController");
        UIViewController *collection = [object isKindOfClass:UIViewController.class] ? object : nil;
        UIView *native = collection.isViewLoaded ? collection.view : nil;
        NSUInteger expanded = 0;
        BOOL valid = native && native != host.view && [native isDescendantOfView:host.view] && HBExpandedCount(collection, &expanded);
        CGSize size = host.view.bounds.size;
        BOOL allowed = self.active && HBShouldPresent((int)NSProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            HBEnabled(), UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone,
            size.width, size.height, valid, self.nativeRequested, expanded > 0);
        if (!allowed) { [self restoreNative]; return; }
        // Reparenting by the system invalidates our old snapshot.
        if (self.nativeView != native && self.ownsHiddenState) [self restoreNative];
        if (!self.dashboard) {
            self.dashboard = [HBDashboardController new];
            __weak typeof(self) weakSelf = self;
            self.dashboard.openSystemControls = ^(HBSystemDestination destination) { [weakSelf openSystem:destination]; };
        }
        if (!self.dashboard.parentViewController) {
            [host addChildViewController:self.dashboard];
            self.dashboard.view.frame = host.view.bounds;
            self.dashboard.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [host.view addSubview:self.dashboard.view];
            [self.dashboard didMoveToParentViewController:host];
        }
        self.dashboard.view.frame = host.view.bounds;
        [self.dashboard setDashboardActive:YES];
        if (!self.ownsHiddenState) {
            self.nativeView = native;
            self.originalHidden = native.hidden;
            self.ownsHiddenState = YES;
        }
        // Do this last, after the replacement is successfully constructed.
        native.hidden = YES;
    } @catch (NSException *exception) {
        self.nativeRequested = YES;
        [self restoreNative];
        NSLog(@"[Harbor] Native Control Center retained: %@", exception.name);
    } @finally { self.layingOut = NO; }
}
- (void)openSystem:(HBSystemDestination)destination {
    self.nativeRequested = YES;
    [self restoreNative];
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
