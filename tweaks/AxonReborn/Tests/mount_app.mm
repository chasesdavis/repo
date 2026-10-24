// SPDX-License-Identifier: GPL-3.0-only
// Public UIKit integration test. Does not emulate SpringBoard private APIs.
#import <UIKit/UIKit.h>
#import "../Tweak/AXNListMount.h"
#include <cstdio>
#include <cstdlib>

static void Check(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
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
        AXNListMount *mount = [[AXNListMount alloc] initWithCollection:list];
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
        puts("AXN_UI_TEST_PASS: mounting, card separation, repeated layout, resize, disable and detach");
        fflush(stdout); exit(0);
    });
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(TestDelegate.class)); }
}
