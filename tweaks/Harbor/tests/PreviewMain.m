// Simulator-only harness. Not included in the tweak package.
#import <UIKit/UIKit.h>
#import "../HBDashboardController.h"
#import "../HBSession.h"
#import "../HBPreferences.h"

@interface HBTestModule : UIViewController
@property (nonatomic, copy) NSString *moduleIdentifier;
@end
@implementation HBTestModule
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
@end
@implementation HBTestHost
- (void)viewDidLoad {
    [super viewDidLoad];
    self.moduleCollectionViewController = [HBTestCollection new];
    [self addChildViewController:self.moduleCollectionViewController];
    self.moduleCollectionViewController.view.frame = self.view.bounds;
    self.moduleCollectionViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.moduleCollectionViewController.view.backgroundColor = UIColor.systemBlueColor;
    [self.view addSubview:self.moduleCollectionViewController.view];
    [self.moduleCollectionViewController didMoveToParentViewController:self];
    for (NSString *name in @[@"com.apple.control-center.ConnectivityModule", @"com.apple.donotdisturb.control-center.module"]) {
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

@interface HBPreviewApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray<NSString *> *results;
@property (nonatomic) NSUInteger failures;
@end
@implementation HBPreviewApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.results = [NSMutableArray array];
    HBReloadPreferences();
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
    [dashboard.view layoutIfNeeded];
    [self check:!HBHasAmbiguity(dashboard.view) name:@"Dashboard has no ambiguous Auto Layout geometry"];
    [(UIControl *)HBFind(dashboard.view, @"harbor.connections") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[dashboard valueForKey:@"clock"] == nil && [[dashboard valueForKey:@"media"] valueForKey:@"timer"] == nil name:@"Native handoff stops both visible-only timers"];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Connections restores native hierarchy"];
    [self check:[host.moduleCollectionViewController.lastExpanded containsString:@"Connectivity"] name:@"Connections resolves an actual installed module identifier"];
    [session layout];
    [self check:HBDashboard(host) == nil name:@"Native selection persists across layout callbacks"];
    [session end]; [session begin];
    [self check:HBDashboard(host) != nil name:@"Reopening starts a fresh Harbor visit"];
    [(UIControl *)HBFind(HBDashboard(host).view, @"harbor.focus") sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self check:[host.moduleCollectionViewController.lastExpanded containsString:@"donotdisturb"] name:@"Focus resolves and requests its native panel"];
    [session end]; [session begin];
    HBSetPreference(@"enabled", @NO); [HBSession preferencesChanged];
    [self check:!host.moduleCollectionViewController.view.hidden && HBDashboard(host) == nil name:@"Master switch immediately restores native controls"];
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
        [self check:!HBHasAmbiguity(preview.view) && scroll.contentSize.width <= scroll.bounds.size.width + 1
            name:[NSString stringWithFormat:@"Long media stays within a %@pt viewport", width]];
        UIButton *all = (id)HBFind(preview.view, @"harbor.allControls");
        CGRect rect = [all convertRect:all.bounds toView:scroll];
        [self check:CGRectGetMaxY(rect) <= scroll.contentSize.height + 1 && all.bounds.size.height >= 44
            name:[NSString stringWithFormat:@"All controls remains scroll-reachable at %@pt", width]];
    }
    preview.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    [preview applyAppearance]; [preview.view setNeedsLayout]; [preview.view layoutIfNeeded];
    [self check:((UIStackView *)[preview valueForKey:@"levels"]).axis == UILayoutConstraintAxisVertical && !HBHasAmbiguity(preview.view)
        name:@"Accessibility text switches level cards to a single column"];
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
