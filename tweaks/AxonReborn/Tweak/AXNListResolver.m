// SPDX-License-Identifier: GPL-3.0-only
#import "AXNListResolver.h"
#import "AXNRailView.h"
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

static id ReadViewGetter(id owner, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(owner), selector);
    if (!method || method_getNumberOfArguments(method) != 2) return nil;
    char type[128] = {}; method_getReturnType(method, type, sizeof(type));
    const char *value = type;
    while (*value && strchr("rnNoORV", *value)) ++value;
    if (*value != '@') return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)(owner, selector); }
    @catch (NSException *exception) { (void)exception; return nil; }
}
static BOOL IsNativeList(id candidate) {
    Class native = NSClassFromString(@"NCNotificationListView");
    return native && [candidate isKindOfClass:native] && [candidate isKindOfClass:UIScrollView.class];
}
static BOOL BelongsToRoot(UIView *candidate, UIView *root) {
    return root && (candidate == root || [candidate isDescendantOfView:root]);
}
UIScrollView *AXNResolveList(UIViewController *owner) {
    UIView *root = owner.viewIfLoaded;
    if (!root) return nil;
    // iOS 17 runtime headers declare masterListView as NCNotificationListView,
    // a UIScrollView subclass, and scrollView as the public-facing list getter.
    // Source: MTACS/iOS-17-Runtime-Headers, UserNotificationsUIKit.framework.
    for (NSString *getter in @[@"masterListView", @"scrollView"]) {
        id candidate = ReadViewGetter(owner, getter);
        if (IsNativeList(candidate) && BelongsToRoot(candidate, root)) return candidate;
    }
    // Keep a checked collection getter for alternate adapters. Do not select
    // an arbitrary collection (or scroll view) nested inside a notification card.
    id collection = ReadViewGetter(owner, @"collectionView");
    if ([collection isKindOfClass:UICollectionView.class] && BelongsToRoot(collection, root)) return collection;
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    UIScrollView *found = nil;
    NSUInteger visited = 0;
    while (pending.count && visited++ < 256) {
        UIView *view = pending.lastObject; [pending removeLastObject];
        if ([view isKindOfClass:AXNRailView.class]) continue;
        if (IsNativeList(view)) {
            if (found) return nil;
            found = (UIScrollView *)view;
        } else if (![view isKindOfClass:UIScrollView.class]) {
            [pending addObjectsFromArray:view.subviews];
        }
    }
    return pending.count ? nil : found;
}
static NSString *Geometry(UIView *view) {
    if (!view) return @"nil";
    CGRect frame = view.frame, bounds = view.bounds;
    return [NSString stringWithFormat:@"%@ frame=(%.0f,%.0f,%.0f,%.0f) bounds=(%.0f,%.0f,%.0f,%.0f) window=%d hidden=%d alpha=%.2f",
        NSStringFromClass(view.class), frame.origin.x, frame.origin.y, frame.size.width, frame.size.height,
        bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height,
        view.window != nil, view.hidden, view.alpha];
}
NSString *AXNDescribeLayout(UIViewController *owner, UIScrollView *list, UIView *rail) {
    NSMutableString *report = [NSMutableString stringWithFormat:@"Axon alpha4 layout\nowner=%@\n", NSStringFromClass(owner.class) ?: @"nil"];
    for (NSString *getter in @[@"masterListView", @"scrollView", @"collectionView"]) {
        id value = ReadViewGetter(owner, getter);
        [report appendFormat:@"%@=%@\n", getter, value ? NSStringFromClass([value class]) : @"nil"];
    }
    [report appendFormat:@"selected=%@\nrail=%@\n", Geometry(list), Geometry(rail)];
    if (list) [report appendFormat:@"inset=(%.0f,%.0f,%.0f,%.0f) offset=(%.0f,%.0f) content=(%.0f,%.0f) railInViewport=%d\n",
        list.contentInset.top, list.contentInset.left, list.contentInset.bottom, list.contentInset.right,
        list.contentOffset.x, list.contentOffset.y, list.contentSize.width, list.contentSize.height,
        rail && rail.superview == list && CGRectIntersectsRect(list.bounds, rail.frame)];
    // Stop at scroll views, including the selected list: never walk card content.
    NSMutableArray<UIView *> *pending = [NSMutableArray new];
    if (owner.viewIfLoaded) [pending addObject:owner.viewIfLoaded];
    NSUInteger visited = 0;
    while (pending.count && visited++ < 20 && report.length < 6000) {
        UIView *view = pending.firstObject; [pending removeObjectAtIndex:0];
        [report appendFormat:@"view %lu: %@\n", (unsigned long)visited, Geometry(view)];
        if (![view isKindOfClass:UIScrollView.class] && ![view isKindOfClass:AXNRailView.class]) {
            NSUInteger room = 20 - MIN((NSUInteger)20, visited + pending.count);
            [pending addObjectsFromArray:[view.subviews subarrayWithRange:NSMakeRange(0, MIN(room, view.subviews.count))]];
        }
    }
    return report;
}
