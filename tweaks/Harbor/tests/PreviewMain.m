// Simulator-only harness. Not included in the tweak package.
#import <UIKit/UIKit.h>
#import "../HBDashboardController.h"
#import "../HBSession.h"
#import "../HBPreferences.h"
#import "FocusChecks.h"

@interface HBTestModule : UIViewController
@property (nonatomic, copy) NSString *moduleIdentifier;
@property (nonatomic, strong) UIViewController *contentViewController;
@end
@implementation HBTestModule
@end

@interface HBTestWiFiButtonController : UIViewController
@property (nonatomic, strong) UIButton *buttonView;
@property (nonatomic) NSUInteger actionCount;
@end
@implementation HBTestWiFiButtonController
- (void)loadView { self.buttonView = [UIButton buttonWithType:UIButtonTypeCustom]; self.view = self.buttonView; [self.buttonView addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside]; }
- (void)toggle { self.actionCount++; self.buttonView.selected = !self.buttonView.selected; }
@end

@interface HBTestCollection : UIViewController
@property (nonatomic) NSUInteger expandedModuleCount;
@property (nonatomic, copy) NSString *lastExpanded;
@end
@implementation HBTestCollection
- (void)expandModuleWithIdentifier:(NSString *)identifier { self.lastExpanded = identifier; }
@end
@interface HBTestHost : UIViewController
@property (nonatomic, strong) HBTestCollection *moduleCollectionViewController;
@property (nonatomic, strong) UIView *overlayContainerView;
@property (nonatomic, strong) UIScrollView *overlayScrollView;
@property (nonatomic, strong) UIView *overlayBackgroundView;
@property (nonatomic, strong) UIButton *overlayHeaderView;
@end
@implementation HBTestHost
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overlayBackgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.overlayBackgroundView.userInteractionEnabled = NO;
    self.overlayBackgroundView.backgroundColor = UIColor.systemGrayColor;
    self.overlayBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.overlayBackgroundView];
    self.overlayScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.overlayScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.overlayScrollView];
    // Screenshot proportions: a 375 × 812 viewport with a ~142...670pt module panel.
    // This deliberately differs from the full-window panel in the original mock.
    self.overlayContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 142, self.view.bounds.size.width, self.view.bounds.size.height - 284)];
    self.overlayContainerView.clipsToBounds = YES;
    self.overlayContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.overlayScrollView addSubview:self.overlayContainerView];
    self.overlayHeaderView = [UIButton buttonWithType:UIButtonTypeSystem];
    self.overlayHeaderView.frame = CGRectMake(20, 72, self.view.bounds.size.width - 40, 48);
    self.overlayHeaderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.overlayHeaderView setTitle:@"System status · fixture" forState:UIControlStateNormal];
    [self.overlayHeaderView setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.view addSubview:self.overlayHeaderView];
    self.moduleCollectionViewController = [HBTestCollection new];
    [self addChildViewController:self.moduleCollectionViewController];
    self.moduleCollectionViewController.view.frame = self.overlayContainerView.bounds;
    self.moduleCollectionViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.moduleCollectionViewController.view.backgroundColor = UIColor.systemBlueColor;
    [self.overlayContainerView addSubview:self.moduleCollectionViewController.view];
    [self.moduleCollectionViewController didMoveToParentViewController:self];
    for (NSString *name in @[@"com.apple.control-center.ConnectivityModule", @"com.apple.FocusUIModule",
        @"com.apple.mediaremote.controlcenter.audio", @"com.apple.control-center.DisplayModule"]) {
        HBTestModule *module = [HBTestModule new]; module.moduleIdentifier = name;
        [self.moduleCollectionViewController addChildViewController:module];
        [module didMoveToParentViewController:self.moduleCollectionViewController];
    }
}
@end

static UIView *HBFind(UIView *view, NSString *identifier) {
    if ([view.accessibilityIdentifier isEqual:identifier]) return view;
    for (UIView *child in view.subviews) { UIView *found = HBFind(child, identifier); if (found) return found; }
    return nil;
}
static HBDashboardController *HBDashboard(HBTestHost *host) {
    for (UIViewController *child in host.childViewControllers) if ([child isKindOfClass:HBDashboardController.class]) return (id)child;
    return nil;
}
static BOOL HBHasAmbiguity(UIView *view) {
    BOOL ambiguous = view.hasAmbiguousLayout;
    if (ambiguous) NSLog(@"HARBOR_AMBIGUOUS: %@ %@", NSStringFromClass(view.class), NSStringFromCGRect(view.frame));
    for (UIView *child in view.subviews) ambiguous = HBHasAmbiguity(child) || ambiguous;
    return ambiguous;
}
static UIImage *HBTestArtwork(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(320, 320)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor colorWithRed:0.17 green:0.34 blue:0.35 alpha:1] setFill];
        UIRectFill(CGRectMake(0, 0, 320, 320));
        for (int i = 0; i < 11; i++) {
            UIBezierPath *path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(-30, 70 + i * 24)];
            [path addCurveToPoint:CGPointMake(350, 150 + i * 22) controlPoint1:CGPointMake(90, -30 + i * 20) controlPoint2:CGPointMake(180, 320 + i * 4)];
            path.lineWidth = 1.5;
            [[UIColor colorWithRed:0.69 green:0.91 blue:0.79 alpha:0.65] setStroke]; [path stroke];
        }
    }];
}

#import "FocusAccessChecks.h"
#import "ProfileChecks.h"

@interface HBPreviewApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray<NSString *> *results;
@property (nonatomic) NSUInteger failures;
@property (nonatomic, copy) NSDictionary *previousLibrary;
@end
@implementation HBPreviewApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.results = [NSMutableArray array];
    HBReloadPreferences(); self.previousLibrary = HBLoadProfileLibrary(); HBSaveProfileLibrary(HBDefaultLibrary(@"sea"), nil, nil);
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    HBTestHost *host = [HBTestHost new];
    self.window.rootViewController = host;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self runTests:host]; });
    return YES;
}
- (void)check:(BOOL)condition name:(NSString *)name {
    NSString *line = [NSString stringWithFormat:@"%@: %@", condition ? @"PASS" : @"FAIL", name];
    [self.results addObject:line]; NSLog(@"%@", line); if (!condition) self.failures++;
}
- (void)runTests:(HBTestHost *)host {
    HBSetPreference(@"enabled", @YES);
    HBSetPreference(@"haptics", @NO);
    HBSetPreference(@"palette", @"sea");
    HBSession *session = [HBSession sessionForHost:host create:YES];
    [session begin];
    [host.view layoutIfNeeded];
    [self check:host.moduleCollectionViewController.view.hidden && HBDashboard(host) != nil name:@"Valid host displays Harbor and hides only the native collection"];
    HBDashboardController *dashboard = HBDashboard(host);
    [self check:CGRectEqualToRect([dashboard.view convertRect:dashboard.view.bounds toView:host.view], host.view.bounds)
        name:@"Inset module panel does not constrain the full-window dashboard viewport"];
    UIView *backdrop = HBFind(host.overlayBackgroundView, @"harbor.backdrop");
    [self check:backdrop && CGRectEqualToRect([backdrop convertRect:backdrop.bounds toView:host.view], host.view.bounds)
        name:@"Backdrop fills the complete native background, including top and bottom"];
    [self check:[dashboard.view isDescendantOfView:host.overlayScrollView.panGestureRecognizer.view] &&
        host.overlayScrollView.panGestureRecognizer.enabled && host.overlayContainerView.clipsToBounds &&
        fabs(host.overlayContainerView.frame.origin.y - 142) < 1
        name:@"Native scroll/dismiss ancestry, panel geometry, and clipping stay unchanged"];
    [dashboard.view layoutIfNeeded];
    [self check:!HBHasAmbiguity(dashboard.view) name:@"Dashboard has no ambiguous Auto Layout geometry"];
    CGPoint headerPoint = [host.overlayHeaderView convertPoint:CGPointMake(40, 24) toView:host.view];
    UIView *headerHit = [host.view hitTest:headerPoint withEvent:nil];
    [self check:headerHit == host.overlayHeaderView || [headerHit isDescendantOfView:host.overlayHeaderView]
        name:@"Native status/privacy header stays visible and receives touches"];
    UIScrollView *cards = [dashboard valueForKey:@"scroll"];

    UIPanGestureRecognizer *nativePan = host.overlayScrollView.panGestureRecognizer;
    UIView *brightness = HBFind(dashboard.view, @"harbor.brightness");
    [self check:[session ownsTouchView:brightness recognizer:nativePan] name:@"Native ancestor pan excludes touches on Harbor controls"];
    [self check:![session ownsTouchView:host.overlayHeaderView recognizer:nativePan] name:@"Native header touches retain the system gesture path"];
    UIScreenEdgePanGestureRecognizer *edge = [UIScreenEdgePanGestureRecognizer new];
    [host.view addGestureRecognizer:edge];
    [self check:![session ownsTouchView:brightness recognizer:edge] name:@"System edge gestures are never filtered"];
    [host.view removeGestureRecognizer:edge];
    [self check:![session ownsTouchView:brightness recognizer:cards.panGestureRecognizer] name:@"Harbor's own scrolling recognizer is never filtered"];
    [self check:![dashboard containsInteractionPoint:CGPointMake(10, 10)] name:@"Empty space above the sheet remains available for native dismissal"];
    [dashboard setValue:@YES forKey:@"expanded"]; [dashboard.view layoutIfNeeded];
    UIView *lastControl = HBFind(dashboard.view, @"harbor.display");
    [self check:![(UIView *)[dashboard valueForKey:@"moreRows"] isHidden] && CGRectContainsRect(cards.bounds, [lastControl convertRect:lastControl.bounds toView:cards])
        name:@"Expanded controls all fit on a standard portrait viewport"];
    [dashboard setValue:@NO forKey:@"expanded"]; [dashboard.view layoutIfNeeded];
    HBTestWiFiButtonController *wifi = [HBTestWiFiButtonController new];
    HBTestModule *connectivity = (id)host.moduleCollectionViewController.childViewControllers.firstObject;
    [connectivity addChildViewController:wifi]; wifi.view.frame = CGRectMake(0, 0, 50, 50); [connectivity.view addSubview:wifi.view]; [wifi didMoveToParentViewController:connectivity];
    HBNativeControls *bridge = [HBNativeControls new]; bridge.collection = host.moduleCollectionViewController;
    [self check:[bridge buttonForKey:@"wifi"] == wifi.buttonView name:@"Connectivity adapter resolves an existing native button"];
    [self check:[bridge activateKey:@"wifi"] && wifi.actionCount == 1 && wifi.buttonView.selected name:@"Connectivity action reaches the underlying button once and reads its real state"];
    [self check:wifi.view.superview == connectivity.view && wifi.parentViewController == connectivity name:@"Native controls retain their view and controller ownership"];
    wifi.buttonView.enabled = NO;
    [self check:![bridge activateKey:@"wifi"] && wifi.actionCount == 1 name:@"Disabled native controls cannot be activated"];
    wifi.buttonView.enabled = YES;
    [self check:![bridge activateKey:@"unknown"] && ![bridge activateKey:@"cellular"] name:@"Missing or unknown controls fail without invented state or actions"];
    [wifi.buttonView removeTarget:wifi action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [self check:[bridge buttonForKey:@"wifi"] == nil name:@"A non-actionable native view is not presented as a working toggle"];
    [wifi willMoveToParentViewController:nil]; [wifi.view removeFromSuperview]; [wifi removeFromParentViewController];
    HBTestModule *lowPower = [HBTestModule new]; lowPower.moduleIdentifier = @"com.apple.control-center.LowPowerModule";
    HBTestWiFiButtonController *powerButton = [HBTestWiFiButtonController new]; lowPower.contentViewController = powerButton;
    [host.moduleCollectionViewController addChildViewController:lowPower]; [lowPower addChildViewController:powerButton];
    [lowPower.view addSubview:powerButton.view]; [powerButton didMoveToParentViewController:lowPower]; [lowPower didMoveToParentViewController:host.moduleCollectionViewController];
    [self check:[bridge activateKey:@"power"] && powerButton.actionCount == 1 name:@"Low Power uses the identifier in the actual iOS 17.5 system bundle"];
    [lowPower willMoveToParentViewController:nil]; [lowPower.view removeFromSuperview]; [lowPower removeFromParentViewController];

    UIButton *escape = (id)HBFind(dashboard.view, @"harbor.allControls");
    CGRect escapeFrame = [escape convertRect:escape.bounds toView:host.view];
    [self check:![(UIView *)escape isDescendantOfView:cards] && CGRectContainsRect(host.view.bounds, escapeFrame) &&
        CGRectGetMaxY(escapeFrame) <= host.view.bounds.size.height - host.view.safeAreaInsets.bottom
        name:@"All controls is pinned visibly above the home-indicator safe area"];
    [cards setContentOffset:CGPointMake(0, MAX(-cards.contentInset.top, cards.contentSize.height - cards.bounds.size.height)) animated:NO];
    UIView *focus = HBFind(dashboard.view, @"harbor.focus");
    [self check:CGRectContainsRect(cards.bounds, [focus convertRect:focus.bounds toView:cards]) &&
        CGRectEqualToRect(escapeFrame, [escape convertRect:escape.bounds toView:host.view])
        name:@"Lower shortcut is fully scroll-reachable while native escape stays fixed"];
    host.overlayScrollView.contentOffset = CGPointMake(0, 40); [session layout];
    [self check:CGRectEqualToRect([dashboard.view convertRect:dashboard.view.bounds toView:host.view], host.view.bounds)
        name:@"Native scroll offsets do not move the dashboard out of its viewport"];
    host.overlayScrollView.contentOffset = CGPointZero;
    host.overlayScrollView.transform = CGAffineTransformMakeTranslation(0, 40); [session layout];
    CGRect movingFrame = [dashboard.view convertRect:dashboard.view.bounds toView:host.view];
    [self check:HBDashboard(host) == dashboard && fabs(movingFrame.origin.y - 40) < 1 &&
        CGAffineTransformEqualToTransform(host.overlayScrollView.transform, CGAffineTransformMakeTranslation(0, 40))
        name:@"Dashboard inherits native presentation transforms without cancelling or changing them"];
    host.overlayScrollView.transform = CGAffineTransformIdentity; [session layout];
    [(UIControl *)HBFind(dashboard.view, @"harbor.connections") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[dashboard valueForKey:@"clock"] == nil && [[dashboard valueForKey:@"media"] valueForKey:@"timer"] == nil name:@"Native handoff stops both visible-only timers"];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Connections restores native hierarchy"];
    [self check:[host.moduleCollectionViewController.lastExpanded containsString:@"Connectivity"] name:@"Connections resolves an actual installed module identifier"];
    [session layout];
    [self check:HBDashboard(host) == nil name:@"Native selection persists across layout callbacks"];
    [session end]; [session begin];
    [self check:HBDashboard(host) != nil name:@"Reopening starts a fresh Harbor visit"];
    [(UIControl *)HBFind(HBDashboard(host).view, @"harbor.focus") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[host.moduleCollectionViewController.lastExpanded isEqual:@"com.apple.FocusUIModule"] name:@"Focus resolves and requests its native panel"];
    [self check:![bridge activateKey:@"focus"] name:@"Focus cannot use the native-toggle forwarding adapter"];
    HBTestModule *focusModule=nil;
    for (HBTestModule *module in host.moduleCollectionViewController.childViewControllers) if ([module.moduleIdentifier isEqual:@"com.apple.FocusUIModule"]) focusModule=module;
    focusModule.moduleIdentifier=@"com.thirdparty.focus"; host.moduleCollectionViewController.lastExpanded=nil;
    [session end]; [session begin];
    [(UIControl *)HBFind(HBDashboard(host).view,@"harbor.focus") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:host.moduleCollectionViewController.lastExpanded==nil && !host.moduleCollectionViewController.view.hidden name:@"Unknown Focus module identities fall back to native controls without expansion"];
    focusModule.moduleIdentifier=@"com.apple.FocusUIModule";
    [session end]; [session begin];
    [(UIControl *)HBFind(HBDashboard(host).view, @"harbor.volumeFallback") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[host.moduleCollectionViewController.lastExpanded isEqual:@"com.apple.mediaremote.controlcenter.audio"] name:@"Volume fallback resolves the real MediaControlsAudioModule identifier"];
    [session end]; [session begin];
    [HBDashboard(host) setValue:@YES forKey:@"expanded"]; [HBDashboard(host).view layoutIfNeeded];
    [(UIControl *)HBFind(HBDashboard(host).view, @"harbor.display") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[host.moduleCollectionViewController.lastExpanded isEqual:@"com.apple.control-center.DisplayModule"] name:@"Display shortcut resolves the actual DisplayModule identifier"];
    [session end]; [session begin];
    HBSetPreference(@"enabled", @NO); [HBSession preferencesChanged];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Master switch immediately restores native controls"];
    [self check:[HBRuntimeStatusSummary() containsString:@"Harbor is disabled"] name:@"Settings diagnostics preserve the reason native controls were retained"];
    HBSetPreference(@"enabled", @YES); [HBSession preferencesChanged];
    [self check:HBDashboard(host) != nil name:@"Master switch re-enables the active portrait dashboard"];
    host.moduleCollectionViewController.expandedModuleCount = 1; [session layout];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Expanded native modules are never covered"];
    host.moduleCollectionViewController.expandedModuleCount = 0; [session layout];
    [session end];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Dismissal removes the child controller and restores native state"];
    host.moduleCollectionViewController.view.hidden = YES;
    [session begin]; [session end];
    [self check:host.moduleCollectionViewController.view.hidden name:@"Pre-existing hidden state is restored exactly"];
    host.moduleCollectionViewController.view.hidden = NO;
    UIView *native = host.moduleCollectionViewController.view;
    [native removeFromSuperview]; [session begin];
    [self check:HBDashboard(host) == nil name:@"Unexpected native hierarchy fails open"];
    [host.view addSubview:native]; [session layout];
    [self check:HBDashboard(host) == nil && !native.hidden name:@"A collection outside the presentation container remains visible"];
    [host.overlayContainerView addSubview:native]; [session layout];
    UIView *originalContainer = host.overlayContainerView;
    host.overlayContainerView = nil; [session layout];
    [self check:HBDashboard(host) == nil && !native.hidden name:@"A missing presentation container restores the native collection"];
    host.overlayContainerView = originalContainer; [session layout];
    UIView *fullBackground = host.overlayBackgroundView;
    host.overlayBackgroundView = nil; [session layout];
    [self check:HBDashboard(host) == nil && !native.hidden name:@"Missing full-screen background retains native controls"];
    host.overlayBackgroundView = fullBackground; [session layout];
    CGRect backgroundFrame = fullBackground.frame;
    fullBackground.frame = CGRectInset(backgroundFrame, -12, -12); [session layout];
    [self check:HBDashboard(host) != nil name:@"An overscanned native blur background is accepted without resizing it"];
    fullBackground.frame = backgroundFrame; [session layout];
    [host.view removeFromSuperview]; [session layout];
    [self check:HBDashboard(host) == nil && !native.hidden name:@"A detached Control Center host cannot keep Harbor visible"];
    [self.window addSubview:host.view]; [session layout];
    CGRect portrait = self.window.frame;
    self.window.frame = CGRectMake(0, 0, portrait.size.height, portrait.size.width);
    host.view.frame = self.window.bounds; [host.view layoutIfNeeded]; [session layout];
    [self check:HBDashboard(host) == nil && !native.hidden name:@"Landscape resize restores native controls"];
    self.window.frame = portrait; host.view.frame = self.window.bounds;
    [host.view layoutIfNeeded]; [session layout];
    [self check:HBDashboard(host) != nil name:@"Returning to portrait restores the complete Harbor viewport"];
    [session end]; [session layout];
    [self check:HBDashboard(host) == nil && HBFind(host.overlayBackgroundView, @"harbor.backdrop") == nil
        name:@"Ending presentation removes both content and backdrop; layout cannot reopen it"];
    [session begin];
    dashboard = HBDashboard(host);
    HBMediaSnapshot *empty = [HBMediaSnapshot new]; empty.title = @"Nothing playing"; empty.artist = @"Your next moment of calm.";
    [dashboard displayMedia:empty];
    [self check:![(UIControl *)HBFind(dashboard.view, @"harbor.play") isEnabled] name:@"Empty media disables transport"];
    HBMediaSnapshot *sample = [HBMediaSnapshot new];
    sample.title = @"A quieter kind of evening"; sample.artist = @"Harbor · Sample media";
    sample.artwork = HBTestArtwork(); sample.hasSession = YES; sample.available = YES; sample.playing = YES; sample.canSkip = YES;
    [dashboard displayMedia:sample];
    [self check:[(UIControl *)HBFind(dashboard.view, @"harbor.play") isEnabled] && [HBFind(dashboard.view, @"harbor.play").accessibilityLabel isEqual:@"Pause"] name:@"Playing media enables transport with accurate accessibility label"];
    HBSetPreference(@"palette", @"invalid");
    [self check:[HBPalette() isEqual:@"sea"] name:@"Invalid palette falls back to Sea Glass"];
    HBSetPreference(@"palette", @"iris");
    [self check:[HBPalette() isEqual:@"iris"] name:@"Palette preference round trips"];
    HBSetPreference(@"palette", @"sea");
    HBMediaProvider *provider = [HBMediaProvider new];
    [self check:![provider sendCommand:2] && ![provider sendCommand:99] name:@"Inactive media provider rejects commands"];
    [session end];
    // Preview the actual shipping view controller, without the mock host or an active provider.
    HBDashboardController *preview = [HBDashboardController new];
    self.window.rootViewController = preview;
    [preview setDashboardActive:YES]; [preview setDashboardActive:NO];
    [preview displayMedia:sample];
    [preview.view layoutIfNeeded];
    [self check:!HBHasAmbiguity(preview.view) name:@"Standalone fixture uses unambiguous shipping UI"];
    CGRect originalFrame = preview.view.frame;
    sample.title = @"A deliberately very long track name that must wrap without pushing a control off the screen";
    sample.artist = @"A similarly long artist name for compact-width layout verification";
    [preview displayMedia:sample];
    for (NSNumber *width in @[@300, @320, @375, @430]) {
        preview.view.frame = CGRectMake(0, 0, width.doubleValue, 568);
        [preview.view setNeedsLayout]; [preview.view layoutIfNeeded];
        UIScrollView *scroll = [preview valueForKey:@"scroll"];

        [self check:scroll.contentSize.height <= scroll.bounds.size.height + 1 name:[NSString stringWithFormat:@"Compact controls need no scrolling at %@pt", width]];
        [preview setValue:@YES forKey:@"expanded"]; [preview.view layoutIfNeeded];
        [scroll setContentOffset:CGPointMake(0, MAX(0, scroll.contentSize.height - scroll.bounds.size.height)) animated:NO];
        UIView *last = HBFind(preview.view, @"harbor.display");
        [self check:CGRectContainsRect(scroll.bounds, [last convertRect:last.bounds toView:scroll]) name:[NSString stringWithFormat:@"Final expanded control remains within scroll reach at %@pt", width]];
        [preview setValue:@NO forKey:@"expanded"]; [preview.view layoutIfNeeded];

        [self check:!HBHasAmbiguity(preview.view) && scroll.contentSize.width <= scroll.bounds.size.width + 1
            name:[NSString stringWithFormat:@"Long media stays within a %@pt viewport", width]];
        UIButton *all = (id)HBFind(preview.view, @"harbor.allControls");
        CGRect rect = [all convertRect:all.bounds toView:preview.view];
        [self check:CGRectContainsRect(preview.view.bounds, rect) && ![all isDescendantOfView:scroll] && all.bounds.size.height >= 44
            name:[NSString stringWithFormat:@"All controls stays pinned and reachable at %@pt", width]];
    }
    preview.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [preview applyAppearance]; [preview.view setNeedsLayout]; [preview.view layoutIfNeeded];
    [self check:((UIStackView *)[preview valueForKey:@"levels"]).axis == UILayoutConstraintAxisVertical && !HBHasAmbiguity(preview.view)
        name:@"Accessibility text switches level cards to a single column"];
    UIScrollView *largeScroll = [preview valueForKey:@"scroll"];
    UIButton *largeAll = (id)HBFind(preview.view, @"harbor.allControls");
    [largeScroll setContentOffset:CGPointMake(0, MAX(-largeScroll.contentInset.top, largeScroll.contentSize.height - largeScroll.bounds.size.height)) animated:NO];
    UIView *largeFocus = HBFind(preview.view, @"harbor.focus");
    [self check:CGRectContainsRect(largeScroll.bounds, [largeFocus convertRect:largeFocus.bounds toView:largeScroll]) &&
        CGRectContainsRect(preview.view.bounds, [largeAll convertRect:largeAll.bounds toView:preview.view])
        name:@"Largest text keeps the final shortcut scrollable and native escape on screen"];
    preview.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryLarge;
    preview.view.frame = originalFrame;
    [preview applyAppearance];
    sample.title = @"A quieter kind of evening"; sample.artist = @"Harbor · Sample media";
    [preview displayMedia:sample];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--large"]) {
        preview.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
        [preview applyAppearance];
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--empty"]) [preview displayMedia:empty];
    [preview.view setNeedsLayout]; [preview.view layoutIfNeeded];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--inset-host"]) {
        HBTestHost *insetHost = [HBTestHost new];
        self.window.rootViewController = insetHost; [insetHost.view layoutIfNeeded];
        [[HBSession sessionForHost:insetHost create:YES] begin];
        [insetHost.view layoutIfNeeded];
        [HBDashboard(insetHost) displayMedia:empty];
    }
    HBRunProfileChecks(self.window, ^(BOOL pass, NSString *name) { [self check:pass name:name]; });
    HBRunFocusChecks(^(BOOL pass, NSString *name) { [self check:pass name:name]; });
    HBRunFocusAccessChecks(self.window, ^(BOOL pass, NSString *name) { [self check:pass name:name]; });
    HBSaveProfileLibrary(self.previousLibrary, nil, nil);
    NSMutableDictionary *report = [@{@"failures": @(self.failures), @"checks": self.results,
        @"runtime": UIDevice.currentDevice.systemVersion,
        @"scope": @"UIKit + simulated native host; not real SpringBoard or device media"} mutableCopy];
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[directory stringByAppendingPathComponent:@"test-results.json"] atomically:YES];
    NSLog(@"HARBOR_TESTS_COMPLETE: %lu checks, %lu failures", (unsigned long)self.results.count, (unsigned long)self.failures);
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(HBPreviewApp.class)); }
}
