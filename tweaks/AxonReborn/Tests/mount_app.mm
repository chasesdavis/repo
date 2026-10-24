// SPDX-License-Identifier: GPL-3.0-only
// Public UIKit integration test. Does not emulate SpringBoard private APIs.
#import <UIKit/UIKit.h>
#import "../Tweak/AXNListMount.h"
#import "../Tweak/AXNListResolver.h"
#import "../Shared/AXNPreferences.h"
#include <cstdio>
#include <cstdlib>

static void Check(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
// Test doubles exercise getter selection and the UIScrollView mount only.
// They do not emulate Apple's private list layout or notification model.
@interface NCNotificationListView : UIScrollView @end
@implementation NCNotificationListView @end
@interface TestOwner : UIViewController
@property(nonatomic, strong) id masterListView;
@end
@implementation TestOwner @end
@interface WrongGetterOwner : UIViewController @end
@implementation WrongGetterOwner
- (NSUInteger)masterListView { return 42; }
- (id)scrollView { [NSException raise:@"test" format:@"unavailable getter"]; return nil; }
@end
@interface TestDelegate : UIResponder <UIApplicationDelegate, UICollectionViewDataSource>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation TestDelegate
- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section { return 3; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)view cellForItemAtIndexPath:(NSIndexPath *)path {
    return [view dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:path];
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
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
        [list layoutIfNeeded];
        list.contentOffset = CGPointMake(0, -24);
        AXNListMount *mount = [[AXNListMount alloc] initWithScrollView:list];
        AXNRailItem *item = [AXNRailItem new]; item.bundleID = @"example.test"; item.name = @"Test"; item.count = 3;
        [mount.rail updateWithItems:@[item] selected:nil];
        [mount updateVisible:YES];
        [list layoutIfNeeded];
        Check([mount updateVisible:YES], "mounted selector has no visible layout");
        Check(mount.rail.superview == list, "selector is not in the notification collection");
        CGFloat expected = MAX(106, [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize * 2 + 68);
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
        NCNotificationListView *native = [[NCNotificationListView alloc] initWithFrame:nativeOwner.view.bounds];
        native.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        native.contentInset = UIEdgeInsetsMake(12, 2, 9, 1);
        native.contentSize = CGSizeMake(native.bounds.size.width, 1200);
        native.contentOffset = CGPointMake(0, -12);
        UILabel *card = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 90)];
        card.text = @"SECRET_NOTIFICATION_TEXT";
        card.accessibilityIdentifier = @"SECRET_IDENTIFIER";
        [native addSubview:card];
        [nativeOwner.view addSubview:native]; nativeOwner.masterListView = native;
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
        Check(CGRectGetMaxY(nativeMount.rail.frame) <= CGRectGetMinY(card.frame) + 0.5, "native scroll header overlaps card");
        Check(fabs(native.contentOffset.y + 12 + expected) < 0.5, "resting scroll did not reveal header");
        NSString *report = AXNDescribeLayout(nativeOwner, native, nativeMount.rail);
        Check([report containsString:@"masterListView=NCNotificationListView"], "report lacks native getter class");
        Check(![report containsString:@"SECRET"], "report included notification text or identifiers");
        for (int i = 0; i < 100; ++i) { [native setNeedsLayout]; [native layoutIfNeeded]; [nativeMount updateVisible:YES]; }
        Check(fabs(native.contentInset.top - 12 - expected) < 0.5, "native scroll accumulated padding");
        native.contentOffset = CGPointMake(0, 150);
        [nativeMount updateVisible:NO];
        Check(fabs(native.contentOffset.y - 150) < 0.5, "hide moved a scrolled list");
        [nativeMount updateVisible:YES];
        Check(fabs(native.contentOffset.y - 150) < 0.5, "show moved a scrolled list");
        [nativeMount detach];
        Check(fabs(native.contentInset.top - 12) < 0.5 && native.contentInset.bottom == 9, "native scroll detach changed insets");
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
        puts("AXN_UI_TEST_PASS: collection and native-class scroll mounts; resolver guards; layout privacy; diagnostic correlation");
        fflush(stdout); exit(0);
    });
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(TestDelegate.class)); }
}
