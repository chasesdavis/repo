// SPDX-License-Identifier: GPL-3.0-only
// Public UIKit integration test. Does not emulate SpringBoard private APIs.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "../Tweak/AXNListMount.h"
#import "../Tweak/AXNListResolver.h"
#import "../Shared/AXNPreferences.h"
#include <cstdio>
#include <cstdlib>

extern void AXNRunPreferenceTests(void);
extern void AXNRunRailFeatureTests(UIViewController *parent);
extern void AXNRunRuntimeTests(void (^completion)(void));
@interface AXNRailView (TestControls)
- (void)togglePin:(NSString *)bundle;
@end

static void Check(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
// A geometry fixture reproduces the bottom-aligned short-list gap seen on
// device. This is not an implementation of Apple's private list/model.
@interface NCNotificationListView : UIScrollView
@property(nonatomic) BOOL layoutFromBottom;
@property(nonatomic, strong) UIView *fixtureCards;
@property(nonatomic) CGFloat fixtureHeight;
@property(nonatomic) BOOL simulateTracking;
@end
@implementation NCNotificationListView
- (BOOL)isTracking { return self.simulateTracking || [super isTracking]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.fixtureCards) return;
    CGFloat bottom = self.bounds.size.height - self.contentInset.top - self.contentInset.bottom - 53;
    CGFloat start = self.layoutFromBottom ? MAX(0, bottom - self.fixtureHeight) : 0;
    self.fixtureCards.frame = CGRectMake(10, start, self.bounds.size.width - 20, self.fixtureHeight);
    self.contentSize = CGSizeMake(self.bounds.size.width, start + self.fixtureHeight);
}
@end
@interface TestOwner : UIViewController
@property(nonatomic, strong) id masterListView;
@end
@implementation TestOwner @end
@interface WrongGetterOwner : UIViewController @end
@implementation WrongGetterOwner
- (NSUInteger)masterListView { return 42; }
- (id)scrollView { [NSException raise:@"test" format:@"unavailable getter"]; return nil; }
@end
static id WrongAlignmentGetter(id self, SEL command) { (void)self; (void)command; return @"wrong type"; }
@interface TestDelegate : UIResponder <UIApplicationDelegate, UICollectionViewDataSource>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation TestDelegate
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return 3; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
    return [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:path];
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    fputs("AXN_UI_STAGE: application launched\n", stderr); fflush(stderr);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        fputs("AXN_UI_TEST_FAIL: application test watchdog expired; see last stage marker\n", stderr); fflush(stderr); exit(1);
    });
    AXNRunPreferenceTests();
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *controller = [UIViewController new];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(280, 90);
    UICollectionView *list = [[UICollectionView alloc] initWithFrame:controller.view.bounds collectionViewLayout:layout];
    list.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    list.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    list.contentInset = UIEdgeInsetsMake(24, 3, 8, 4);
    list.dataSource = self;
    [list registerClass:UICollectionViewCell.class forCellWithReuseIdentifier:@"cell"];
    [controller.view addSubview:list];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        fputs("AXN_UI_STAGE: mounting collection\n", stderr); fflush(stderr);
        [list layoutIfNeeded];
        list.contentOffset = CGPointMake(0, -24);
        AXNListMount *mount = [[AXNListMount alloc] initWithScrollView:list];
        AXNRailItem *item = [AXNRailItem new]; item.bundleID = @"example.test"; item.name = @"Test"; item.count = 3;
        [mount.rail updateWithItems:@[item] selected:nil];
        [mount updateVisible:YES];
        [list layoutIfNeeded];
        Check([mount updateVisible:YES], "mounted selector has no visible layout");
        __block NSString *tapped = nil;
        __block NSUInteger taps = 0;
        mount.rail.onSelect = ^(NSString *app) { tapped = app; ++taps; };
        NSMutableArray<UIView *> *buttonSearch = [NSMutableArray arrayWithObject:mount.rail];
        UIButton *appButton = nil, *allButton = nil;
        while (buttonSearch.count) {
            UIView *view = buttonSearch.lastObject; [buttonSearch removeLastObject];
            if ([view isKindOfClass:UIButton.class]) {
                if ([view.accessibilityLabel isEqual:@"Test"]) appButton = (UIButton *)view;
                if ([view.accessibilityLabel isEqual:@"All"]) allButton = (UIButton *)view;
            } else [buttonSearch addObjectsFromArray:view.subviews];
        }
        [appButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        Check(taps == 1 && [tapped isEqual:@"example.test"], "app capsule did not dispatch selection");
        [allButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        Check(taps == 2 && tapped == nil, "All capsule did not dispatch reset");
        fputs("AXN_UI_STAGE: capsule controls\n", stderr); fflush(stderr);
        NSArray *savedPins = AXNReadPreference(@"PinnedApps", @[]);
        AXNWritePreference(@"PinnedApps", @[]);
        AXNRailItem *secondItem = [AXNRailItem new]; secondItem.bundleID = @"example.second";
        secondItem.name = @"Messages"; secondItem.count = 12;
        secondItem.icon = [UIImage systemImageNamed:@"bubble.left.and.bubble.right.fill"];
        [mount.rail updateWithItems:@[item, secondItem] selected:secondItem.bundleID];
        UIStackView *capsules = (UIStackView *)appButton.superview;
        Check([capsules.arrangedSubviews containsObject:appButton], "count updates replaced an existing control");
        UIButton *secondButton = (UIButton *)capsules.arrangedSubviews.lastObject;
        Check((secondButton.accessibilityTraits & UIAccessibilityTraitSelected) != 0 && secondButton.menu.children.count == 3,
            "selected capsule or long-press controls missing");
        [mount.rail togglePin:secondItem.bundleID];
        Check(capsules.arrangedSubviews[1] == secondButton && [secondButton.accessibilityValue containsString:@"pinned"],
            "pin did not move favorite first");
        [mount.rail updateWithItems:@[secondItem, item] selected:secondItem.bundleID];
        Check(capsules.arrangedSubviews[1] == secondButton, "favorite ordering did not survive refresh");
        [mount.rail layoutIfNeeded];
        fputs("AXN_UI_STAGE: capture preview\n", stderr); fflush(stderr);
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat]; format.scale = 1;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:mount.rail.bounds.size format:format];
        UIImage *preview = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [UIColor.blackColor setFill]; UIRectFill(mount.rail.bounds);
            [mount.rail.layer renderInContext:context.CGContext];
            (void)context;
        }];
        printf("AXN_RAIL_PREVIEW:%s\n", [UIImagePNGRepresentation(preview) base64EncodedStringWithOptions:0].UTF8String);
        fputs("AXN_UI_STAGE: preview complete\n", stderr); fflush(stderr);
        [mount.rail togglePin:secondItem.bundleID];
        Check(![AXNReadPreference(@"PinnedApps", @[]) containsObject:secondItem.bundleID], "unpin did not persist");
        AXNWritePreference(@"PinnedApps", savedPins);
        [mount.rail updateWithItems:@[item] selected:nil];
        Check(mount.rail.superview == list, "selector is not in the notification collection");
        CGFloat expected = mount.rail.preferredRailHeight;
        Check(fabs(list.contentInset.top - 24 - expected) < 0.5, "missing reserved inset");
        UICollectionViewLayoutAttributes *first = [list layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        Check(CGRectGetMaxY(mount.rail.frame) <= CGRectGetMinY(first.frame) + 0.5, "selector overlaps the first card");
        for (int i = 0; i < 100; ++i) { [list setNeedsLayout]; [list layoutIfNeeded]; [mount updateVisible:YES]; }
        Check(fabs(list.contentInset.top - 24 - expected) < 0.5, "layout accumulated padding");
        CGRect resized = list.frame; resized.size.width = 320; list.frame = resized;
        [list layoutIfNeeded]; [mount updateVisible:YES];
        Check(fabs(mount.rail.bounds.size.width - 308) < 0.5, "selector width did not adapt");
        [mount updateVisible:NO];
        Check(mount.rail.hidden && fabs(list.contentInset.top - 24) < 0.5, "disable did not restore padding");
        Check(list.contentInset.left == 3 && list.contentInset.bottom == 8 && list.contentInset.right == 4, "native insets changed");
        [mount updateVisible:YES]; [mount detach];
        Check(mount.rail.superview == nil && fabs(list.contentInset.top - 24) < 0.5, "detach failed");
        [list removeFromSuperview];
        // NCNotificationListView is a UIScrollView, not a UICollectionView.
        TestOwner *nativeOwner = [TestOwner new];
        [controller addChildViewController:nativeOwner];
        nativeOwner.view.frame = controller.view.bounds;
        [controller.view addSubview:nativeOwner.view];
        [nativeOwner didMoveToParentViewController:controller];
        NCNotificationListView *native = [[NCNotificationListView alloc] initWithFrame:CGRectMake(0, 0, 375, 812)];
        native.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        native.contentInset = UIEdgeInsetsMake(196, 2, 66, 1);
        native.contentOffset = CGPointMake(0, -196);
        native.layoutFromBottom = YES; native.fixtureHeight = 123;
        UILabel *card = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 90)];
        card.text = @"SECRET_NOTIFICATION_TEXT";
        card.accessibilityIdentifier = @"SECRET_IDENTIFIER";
        [native addSubview:card]; native.fixtureCards = card;
        [nativeOwner.view addSubview:native]; nativeOwner.masterListView = native;
        [native layoutIfNeeded];
        CGFloat beforeY = [native convertRect:card.frame toView:nativeOwner.view].origin.y;
        Check(fabs(beforeY - 570) < 1, "fixture did not reproduce device bottom-aligned group");
        // The old inset-only header leaves the card at the same screen Y.
        native.contentInset = UIEdgeInsetsMake(196 + expected, 2, 66, 1);
        native.contentOffset = CGPointMake(0, -196 - expected);
        [native setNeedsLayout]; [native layoutIfNeeded];
        Check(fabs([native convertRect:card.frame toView:nativeOwner.view].origin.y - beforeY) < 1,
            "fixture did not reproduce inset-only failure");
        Check(card.frame.origin.y > 250, "fixture lost the large gap beneath a header ending at content Y=0");
        native.contentInset = UIEdgeInsetsMake(196, 2, 66, 1);
        native.contentOffset = CGPointMake(0, -196);
        Check(AXNResolveList(nativeOwner) == native, "named native scroll getter not resolved");
        // Multiple unrelated collections must not obscure the named native list.
        [nativeOwner.view addSubview:list];
        Check(AXNResolveList(nativeOwner) == native, "unrelated collection changed resolution");
        [list removeFromSuperview];
        nativeOwner.masterListView = nil;
        Check(AXNResolveList(nativeOwner) == native, "unique named-class fallback failed");
        NCNotificationListView *second = [NCNotificationListView new];
        [nativeOwner.view addSubview:second];
        Check(AXNResolveList(nativeOwner) == nil, "ambiguous native lists accepted");
        nativeOwner.masterListView = native;
        Check(AXNResolveList(nativeOwner) == native, "named getter lost to ambiguous tree");
        [second removeFromSuperview];
        AXNListMount *nativeMount = [[AXNListMount alloc] initWithScrollView:native];
        [nativeMount.rail updateWithItems:@[item] selected:nil];
        [nativeMount updateVisible:YES]; [native layoutIfNeeded];
        Check([nativeMount updateVisible:YES], "native scroll selector has no layout");
        Check(!native.layoutFromBottom, "master list is still bottom aligned");
        Check(fabs(CGRectGetMaxY(nativeMount.rail.frame) - CGRectGetMinY(card.frame)) < 0.5, "short selected group is not directly beneath selector");
        Check(fabs(native.contentOffset.y + 196 + expected) < 0.5, "resting scroll did not reveal header");
        Check(card.superview == native, "mount reparented a native card");
        // Density changes must retain Slim's proven clock clearance and card origin.
        CGFloat slimY = [nativeMount.rail convertRect:nativeMount.rail.bounds toView:nativeOwner.view].origin.y;
        CGFloat slimHeight = nativeMount.rail.bounds.size.height;
        CGFloat slimCardY = [native convertRect:card.frame toView:nativeOwner.view].origin.y;
        for (NSNumber *density in @[@1, @2, @0]) {
            AXNWritePreference(@"Density", density);
            [nativeMount.rail updateWithItems:@[item] selected:nil];
            [nativeMount updateVisible:YES]; [native layoutIfNeeded];
            CGRect inOwner = [nativeMount.rail convertRect:nativeMount.rail.bounds toView:nativeOwner.view];
            Check(fabs(inOwner.origin.y - slimY) < 0.5 && fabs(inOwner.size.height - slimHeight) < 0.5,
                "Balanced/Roomy moved selector toward clock or increased its height");
            Check(fabs([native convertRect:card.frame toView:nativeOwner.view].origin.y - slimCardY) < 0.5,
                "density changed native card position");
        }
        // Large and small app selections must start at the same place, and
        // switching from a long, scrolled list must expose the new selection.
        for (NSNumber *height in @[@123, @2100, @71, @600, @0, @123]) {
            native.fixtureHeight = height.doubleValue;
            native.contentOffset = CGPointMake(0, 700);
            [native setNeedsLayout];
            Check([nativeMount showSelection], "selection did not reset viewport");
            Check(fabs(native.contentOffset.y + native.adjustedContentInset.top) < 0.5, "selected app inherited a stale scroll offset");
            Check(fabs(card.frame.origin.y - CGRectGetMaxY(nativeMount.rail.frame)) < 0.5, "selection size reintroduced a gap");
        }
        native.simulateTracking = YES; native.contentOffset = CGPointMake(0, 120);
        Check(![nativeMount showSelection] && native.contentOffset.y == 120, "selection interrupted a finger gesture");
        native.simulateTracking = NO;
        [nativeMount showSelection];
        NSString *report = AXNDescribeLayout(nativeOwner, native, nativeMount.rail);
        Check([report containsString:@"masterListView=NCNotificationListView"], "report lacks native getter class");
        Check(![report containsString:@"SECRET"], "report included notification text or identifiers");
        for (int i = 0; i < 100; ++i) { [native setNeedsLayout]; [native layoutIfNeeded]; [nativeMount updateVisible:YES]; }
        Check(fabs(native.contentInset.top - 196 - expected) < 0.5, "native scroll accumulated padding");
        // Use an actual scrollable list for offset preservation. A positive
        // offset on the 123-point fixture is overscroll; UIKit may clamp it.
        native.fixtureHeight = 2100;
        [native setNeedsLayout]; [native layoutIfNeeded];
        native.contentOffset = CGPointMake(0, 150);
        [nativeMount updateVisible:NO];
        Check(native.layoutFromBottom, "hide did not restore native bottom alignment");
        Check(fabs(native.contentOffset.y - 150) < 0.5, "hide moved a scrolled list");
        Check(![nativeMount showSelection], "hidden mount reset viewport");
        [nativeMount updateVisible:YES];
        Check(!native.layoutFromBottom, "show did not reactivate top alignment");
        Check(fabs(native.contentOffset.y - 150) < 0.5, "show moved a scrolled list");
        native.layoutFromBottom = YES; // Native master reconfiguration.
        [nativeMount updateVisible:YES];
        Check(!native.layoutFromBottom, "native reconfiguration disabled active mount alignment");
        [nativeMount detach];
        Check(native.layoutFromBottom && fabs(native.contentInset.top - 196) < 0.5 && native.contentInset.bottom == 66, "detach did not restore native alignment and insets");
        native.layoutFromBottom = NO;
        nativeMount = [[AXNListMount alloc] initWithScrollView:native];
        [nativeMount.rail updateWithItems:@[item] selected:nil];
        [nativeMount updateVisible:YES]; [nativeMount detach];
        Check(!native.layoutFromBottom, "detach overwrote an initially top-aligned list");
        native.layoutFromBottom = YES;
        nativeMount = [[AXNListMount alloc] initWithScrollView:native];
        [nativeMount.rail updateWithItems:@[item] selected:nil]; [nativeMount updateVisible:YES];
        [nativeMount.rail removeFromSuperview]; [nativeMount detach];
        Check(native.layoutFromBottom && fabs(native.contentInset.top - 196) < 0.5,
            "externally removed rail leaked alignment or inset ownership");
        Class invalidClass = objc_allocateClassPair(NCNotificationListView.class, "WrongAlignmentList", 0);
        class_addMethod(invalidClass, NSSelectorFromString(@"layoutFromBottom"), (IMP)WrongAlignmentGetter, "@@:");
        objc_registerClassPair(invalidClass);
        NCNotificationListView *invalid = [[invalidClass alloc] initWithFrame:CGRectZero];
        Check([[AXNListMount alloc] initWithScrollView:invalid] == nil, "unsafe alignment getter accepted");
        [native removeFromSuperview];
        Check(AXNResolveList(nativeOwner) == nil, "foreign native getter accepted");
        UIScrollView *unrelated = [[UIScrollView alloc] initWithFrame:nativeOwner.view.bounds];
        [nativeOwner.view addSubview:unrelated]; nativeOwner.masterListView = unrelated;
        Check(AXNResolveList(nativeOwner) == nil, "arbitrary scroll view accepted");
        WrongGetterOwner *wrong = [WrongGetterOwner new]; [wrong loadViewIfNeeded];
        Check(AXNResolveList(wrong) == nil, "unsafe getter accepted");
        NSString *request = AXNBeginDiagnosticQuery();
        AXNPublishDiagnosticReport(AXNDiagnosticReady, report);
        Check([AXNReadDiagnosticResponse(request)[@"report"] isEqual:report], "diagnostic round trip failed");
        NSString *nextRequest = AXNBeginDiagnosticQuery();
        Check(!AXNReadDiagnosticResponse(request) && !AXNReadDiagnosticResponse(nextRequest), "stale diagnostic accepted");
        AXNPublishDiagnosticReport(AXNDiagnosticCollection, report);
        Check(AXNReadDiagnosticResponse(nextRequest) != nil && AXNReadDiagnosticResponse(request) == nil, "response correlation failed");
        fputs("AXN_UI_STAGE: feature tests\n", stderr); fflush(stderr);
        AXNRunRailFeatureTests(controller);
        fputs("AXN_UI_STAGE: runtime tests\n", stderr); fflush(stderr);
        AXNRunRuntimeTests(^{
        puts("AXN_UI_TEST_PASS: bottom-aligned gap regression; short/long selection positioning; gesture preservation; alignment/inset restoration; resolver guards; layout privacy; diagnostic correlation");
        fflush(stdout); exit(0);
        });
    });
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(TestDelegate.class)); }
}

