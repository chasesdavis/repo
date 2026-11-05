// Simulator-only interactive fixture. None of the simulated Focus modes ship.
#define main HBGestureFixtureMain
#import "GestureMain.m"
#undef main
#import "HBProfileStore.h"
#import "HBFocusMonitor.h"

@interface HBProfilesHost : HBFixtureHost
@property(nonatomic,strong) UIButton *focusFixtureButton;
@property(nonatomic) NSUInteger focusStep;
@property(nonatomic) BOOL deliveredEditingEvent;
@property(nonatomic,copy) NSDictionary *realFocus;
@end
@implementation HBProfilesHost
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    HBFocusMonitor *monitor = [self.dashboard valueForKey:@"focusMonitor"];
    __weak typeof(self) weakSelf = self;
    BOOL simulated = [NSProcessInfo.processInfo.arguments containsObject:@"--focus-fixture"];
    monitor.onChange = ^(NSDictionary *snapshot) { weakSelf.realFocus = snapshot; if (!simulated) [weakSelf.dashboard acceptFocusSnapshot:snapshot]; };
    if (simulated) {
        self.focusFixtureButton = [UIButton buttonWithType:UIButtonTypeSystem]; self.focusFixtureButton.frame = CGRectMake(20, 118, self.view.bounds.size.width-40, 44); self.focusFixtureButton.tintColor = UIColor.whiteColor;
        [self.focusFixtureButton addTarget:self action:@selector(cycleFocus) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:self.focusFixtureButton]; [self applySimulatedFocus];
    }
}
- (void)cycleFocus { self.focusStep = (self.focusStep + 1) % 3; [self applySimulatedFocus]; }
- (void)applySimulatedFocus {
    NSArray *labels = @[@"Simulated Focus: Off", @"Simulated Focus: Work", @"Simulated Focus: Unavailable"];
    [self.focusFixtureButton setTitle:labels[self.focusStep] forState:UIControlStateNormal];
    [self.dashboard acceptFocusSnapshot:@{@"available":@(self.focusStep != 2), @"active":@(self.focusStep == 1), @"identifier":self.focusStep == 1 ? @"fixture.focus.work" : @"", @"name":@"Simulated Work", @"status":labels[self.focusStep], @"modes":@[@{@"id":@"fixture.focus.work", @"name":@"Simulated Work"}, @{@"id":@"fixture.focus.personal", @"name":@"Simulated Personal"}]}];
}
- (void)saveMetrics {
    [super saveMetrics]; if (!self.dashboard) return;
    if (!self.deliveredEditingEvent && [self.dashboard valueForKey:@"editor"] && [NSProcessInfo.processInfo.arguments containsObject:@"--focus-during-edit"]) {
        self.deliveredEditingEvent = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ self.focusStep = 1; [self applySimulatedFocus]; });
    }
    NSMutableDictionary *report = [@{@"scope":@"Actual UIKit editing and HID touches; injected Focus is explicitly simulated", @"library":HBLoadProfileLibrary(), @"displayedProfile":self.dashboard.profile ?: @{}, @"focus":self.dashboard.focusSnapshot ?: @{}, @"realFocusProbe":self.realFocus ?: @{}, @"editing":@([self.dashboard valueForKey:@"editor"] != nil), @"pendingProfile":[self.dashboard valueForKey:@"pendingProfile"] ?: @NO} mutableCopy];
    UINavigationController *navigation = (id)self.dashboard.presentedViewController;
    if ([navigation isKindOfClass:UINavigationController.class]) {
        UIViewController *top = navigation.topViewController;
        for (UIView *view in top.view.subviews) if ([view isKindOfClass:UIScrollView.class] && [view.accessibilityIdentifier isEqual:@"harbor.focus.diagnostics"]) {
            UIScrollView *scroll = (id)view; UILabel *text;
            for (UIView *child in scroll.subviews) if ([child isKindOfClass:UILabel.class]) { text = (id)child; break; }
            report[@"diagnosticsView"] = @{@"offset":@(scroll.contentOffset.y),@"contentHeight":@(scroll.contentSize.height),@"height":@(scroll.bounds.size.height),@"fontSize":@(text.font.pointSize),@"category":text.traitCollection.preferredContentSizeCategory,@"text":text.text ?: @"",@"copyMatches":[top.navigationItem.rightBarButtonItem.title isEqual:@"Copied"] ? @([UIPasteboard.generalPasteboard.string isEqual:text.text]) : @NO};
        }
    }
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"profile-interactions.json"];
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:path atomically:YES];
}
@end
@interface HBProfilesApp : HBFixtureApp @end
@implementation HBProfilesApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--reset-profiles"]) { CFPreferencesSetAppValue(CFSTR("profileLibrary"),NULL,(__bridge CFStringRef)HBPreferencesDomain); CFPreferencesSetAppValue(CFSTR("profileBackup"),NULL,(__bridge CFStringRef)HBPreferencesDomain); CFPreferencesAppSynchronize((__bridge CFStringRef)HBPreferencesDomain); }
    CGRect frame = UIScreen.mainScreen.bounds; if ([NSProcessInfo.processInfo.arguments containsObject:@"--short"]) frame.size.height = 568;
    self.window = [[UIWindow alloc] initWithFrame:frame];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--large"]) self.window.traitOverrides.preferredContentSizeCategory = UIContentSizeCategoryAccessibilityExtraExtraExtraLarge;
    self.window.rootViewController = [HBProfilesHost new]; [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(HBProfilesApp.class)); } }
