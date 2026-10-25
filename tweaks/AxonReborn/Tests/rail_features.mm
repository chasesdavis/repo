// SPDX-License-Identifier: GPL-3.0-only
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../Tweak/AXNRailView.h"
#import "../Shared/AXNPreferences.h"
#include <cstdio>
#include <cstdlib>
@interface AXNRailView (FeatureTests)
- (BOOL)interactionActive;
- (void)flushPendingUpdate;
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
@end
@interface FeatureRail : AXNRailView
@property(nonatomic) BOOL simulatedDeceleration;
@end
@implementation FeatureRail
- (BOOL)interactionActive { return self.simulatedDeceleration || [super interactionActive]; }
@end
static void Expect(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "AXN_UI_TEST_FAIL: %s\n", message); fflush(stderr); exit(1); }
}
static NSArray<UIButton *> *Buttons(UIView *view) {
    NSMutableArray *result = [NSMutableArray new];
    for (UIView *child in view.subviews) {
        if ([child isKindOfClass:UIButton.class]) [result addObject:child];
        else [result addObjectsFromArray:Buttons(child)];
    }
    return result;
}
static UIAccessibilityCustomAction *Action(UIButton *button, NSString *name) {
    for (UIAccessibilityCustomAction *action in button.accessibilityCustomActions)
        if ([action.name isEqualToString:name]) return action;
    return nil;
}
static void RunAction(UIButton *button, NSString *name) {
    UIAccessibilityCustomAction *action = Action(button, name);
    Expect(action && action.actionHandler && action.actionHandler(action), "accessibility action failed");
}
void AXNRunRailFeatureTests(UIViewController *parent) {
    fputs("AXN_FEATURE_STAGE: start\n", stderr); fflush(stderr);
    NSArray *keys = @[@"PinnedApps", @"Density", @"Motion", @"Compact", @"ShowCounts", @"ShowAll"];
    NSMutableDictionary *saved = [NSMutableDictionary new];
    for (NSString *key in keys) saved[key] = AXNReadPreference(key, @0);
    AXNWritePreference(@"PinnedApps", @[]); AXNWritePreference(@"Motion", @NO);
    AXNWritePreference(@"ShowAll", @YES); AXNWritePreference(@"Compact", @NO); AXNWritePreference(@"ShowCounts", @YES);
    UIViewController *host = [UIViewController new];
    [parent addChildViewController:host]; host.view.frame = CGRectMake(0, 0, 320, 700);
    [parent.view addSubview:host.view]; [host didMoveToParentViewController:parent];
    FeatureRail *rail = [[FeatureRail alloc] initWithFrame:CGRectZero];
    [host.view addSubview:rail];
    [NSLayoutConstraint activateConstraints:@[
        [rail.leadingAnchor constraintEqualToAnchor:host.view.leadingAnchor],
        [rail.trailingAnchor constraintEqualToAnchor:host.view.trailingAnchor],
        [rail.topAnchor constraintEqualToAnchor:host.view.topAnchor]]];
    AXNRailItem *a = [AXNRailItem new]; a.bundleID = @"test.alpha"; a.name = @"Alpha"; a.count = 1;
    AXNRailItem *b = [AXNRailItem new]; b.bundleID = @"test.beta"; b.name = @"A deliberately long application name"; b.count = 1001;
    [rail updateWithItems:@[a, b] selected:a.bundleID]; [host.view layoutIfNeeded];
    UIButton *alpha = nil, *beta = nil;
    for (UIButton *button in Buttons(rail)) {
        if ([button.accessibilityLabel isEqualToString:a.name]) alpha = button;
        if ([button.accessibilityLabel isEqualToString:b.name]) beta = button;
    }
    Expect(alpha && beta, "feature fixture missing buttons");
    UIStackView *stack = (UIStackView *)alpha.superview;
    Expect([alpha.accessibilityValue isEqualToString:@"1 notification"], "singular count is incorrect");
    __block NSUInteger allTaps = 0;
    rail.onSelect = ^(NSString *app) { if (!app) ++allTaps; };
    fputs("AXN_FEATURE_STAGE: favorites\n", stderr); fflush(stderr);
    RunAction(alpha, @"Pin favorite"); RunAction(beta, @"Pin favorite");
    RunAction(beta, @"Move favorite first");
    Expect(stack.arrangedSubviews[1] == beta, "VoiceOver favorite reorder failed");
    RunAction(alpha, @"Show all notifications");
    Expect(allTaps == 1, "VoiceOver Show All did not reach selection handler");
    RunAction(alpha, @"Unpin favorite"); RunAction(beta, @"Unpin favorite");
    [rail updateWithItems:@[a, b] selected:a.bundleID];
    fputs("AXN_FEATURE_STAGE: coalescing\n", stderr); fflush(stderr);
    [alpha setHighlighted:YES];
    [rail updateWithItems:@[b, a] selected:b.bundleID];
    Expect(stack.arrangedSubviews[1] == alpha && (alpha.accessibilityTraits & UIAccessibilityTraitSelected),
        "arrival disturbed a held capsule");
    [alpha setHighlighted:NO]; [rail flushPendingUpdate];
    Expect(stack.arrangedSubviews[1] == beta && (beta.accessibilityTraits & UIAccessibilityTraitSelected),
        "latest held-touch update did not flush");
    rail.simulatedDeceleration = YES;
    [rail updateWithItems:@[a, b] selected:a.bundleID];
    [rail updateWithItems:@[b, a] selected:nil];
    Expect((beta.accessibilityTraits & UIAccessibilityTraitSelected) != 0, "deceleration changed selection presentation early");
    rail.simulatedDeceleration = NO; [rail scrollViewDidEndDecelerating:nil];
    Expect(!(beta.accessibilityTraits & UIAccessibilityTraitSelected), "scroll completion did not flush latest selection");
    fputs("AXN_FEATURE_STAGE: density\n", stderr); fflush(stderr);
    CGFloat previous = rail.preferredRailHeight, previousWidth = 0;
    for (NSNumber *density in @[@0, @1, @2]) {
        AXNWritePreference(@"Density", density); [rail updateWithItems:@[a, b] selected:b.bundleID];
        [host.view setNeedsLayout]; [host.view layoutIfNeeded];
        Expect(fabs(rail.preferredRailHeight - previous) < 0.5 && fabs(rail.bounds.size.height - rail.preferredRailHeight) < 1,
            "density does not match shared geometry");
        Expect(beta.bounds.size.width > previousWidth, "density did not add horizontal spacing");
        previousWidth = beta.bounds.size.width;
    }
    for (NSString *category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryExtraExtraExtraLarge,
                                 UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        fprintf(stderr, "AXN_FEATURE_STAGE: category %s\n", category.UTF8String); fflush(stderr);
        [parent setOverrideTraitCollection:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:category]
            forChildViewController:host];
        for (NSNumber *width in @[@320, @375, @430]) {
            fprintf(stderr, "AXN_FEATURE_STAGE: width %.0f\n", width.doubleValue); fflush(stderr);
            host.view.frame = CGRectMake(0, 0, width.doubleValue, 700);
            [rail updateWithItems:@[a, b] selected:b.bundleID]; [host.view setNeedsLayout]; [host.view layoutIfNeeded];
            Expect(fabs(rail.bounds.size.width - width.doubleValue) < 1 &&
                   fabs(rail.bounds.size.height - rail.preferredRailHeight) < 1, "large text geometry diverged");
            for (UIButton *button in Buttons(rail)) {
                Expect(button.bounds.size.height >= 48, "capsule touch target too small");
                NSMutableArray *pending = [NSMutableArray arrayWithArray:button.subviews];
                while (pending.count) {
                    UIView *view = pending.lastObject; [pending removeLastObject];
                    if ([view isKindOfClass:UILabel.class] && !view.hidden) {
                        CGRect rect = [view convertRect:view.bounds toView:button];
                        if (rect.origin.y < -0.5 || CGRectGetMaxY(rect) > button.bounds.size.height + 0.5) {
                            UILabel *label = (UILabel *)view;
                            fprintf(stderr, "AXN_GEOMETRY: category=%s width=%.1f rail=%.1f preferred=%.1f button=%.1f label=%s font=%.1f y=%.1f h=%.1f\n",
                                category.UTF8String, width.doubleValue, rail.bounds.size.height, rail.preferredRailHeight,
                                button.bounds.size.height, label.text.UTF8String, label.font.pointSize, rect.origin.y, rect.size.height);
                            fflush(stderr);
                        }
                        Expect(rect.origin.y >= -0.5 && CGRectGetMaxY(rect) <= button.bounds.size.height + 0.5,
                            "large text clipped vertically");
                    }
                    [pending addObjectsFromArray:view.subviews];
                }
            }
        }
    }
    // Even saved beta1 Motion=YES cannot re-enable the removed animations.
    AXNWritePreference(@"Motion", @YES);
    [alpha setHighlighted:YES];
    Expect(CGAffineTransformIsIdentity(alpha.transform) && alpha.layer.animationKeys.count == 0,
        "capsule still scales or springs when pressed");
    [alpha setHighlighted:NO]; ++a.count;
    [rail updateWithItems:@[a, b] selected:a.bundleID];
    NSMutableArray *views = [NSMutableArray arrayWithObject:alpha];
    while (views.count) {
        UIView *view = views.lastObject; [views removeLastObject];
        Expect(view.layer.animationKeys.count == 0, "capsule arrival still animates");
        [views addObjectsFromArray:view.subviews];
    }
    AXNWritePreference(@"ShowAll", @NO); [rail updateWithItems:@[a, b] selected:a.bundleID];
    Expect(Buttons(rail).count == 2 && stack.arrangedSubviews.firstObject == alpha,
        "All switch did not remove just the All capsule");
    RunAction(alpha, @"Show all notifications");
    Expect(allTaps == 2, "hidden All removed recovery action");
    __block NSString *clearApp = nil;
    rail.onRequestClear = ^(NSString *app) { clearApp = app; };
    [rail updateWithItems:@[a, b] selected:nil];
    RunAction(beta, @"Clear app notifications…");
    Expect([clearApp isEqual:b.bundleID], "clear action requested wrong app");
    Expect([[rail replacementAppsForClearing:a.bundleID] isEqual:@[b.bundleID]] &&
        [[rail replacementAppsForClearing:b.bundleID] isEqual:@[a.bundleID]], "neighbor order wrong at ends");
    AXNWritePreference(@"PinnedApps", @[b.bundleID]); [rail updateWithItems:@[a, b] selected:nil];
    Expect([[rail replacementAppsForClearing:b.bundleID] isEqual:@[a.bundleID]], "neighbor order ignored favorites");
    AXNWritePreference(@"PinnedApps", @[]);
    [parent setOverrideTraitCollection:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryLarge]
        forChildViewController:host];
    host.view.frame = CGRectMake(0, 0, 320, 700);
    NSMutableArray *many = [NSMutableArray new];
    for (NSUInteger i = 0; i < 12; ++i) {
        AXNRailItem *item = [AXNRailItem new];
        item.bundleID = [NSString stringWithFormat:@"test.app%lu", (unsigned long)i];
        item.name = [NSString stringWithFormat:@"Application %lu", (unsigned long)i]; item.count = 2; [many addObject:item];
    }
    AXNRailItem *last = many.lastObject;
    [rail updateWithItems:many selected:last.bundleID]; [host.view layoutIfNeeded];
    UIScrollView *scroll = (UIScrollView *)stack.superview;
    [scroll setContentOffset:CGPointMake(MAX(0, scroll.contentSize.width - scroll.bounds.size.width), 0) animated:NO];
    CGFloat endOffset = scroll.contentOffset.x;
    NSString *neighbor = [rail replacementAppsForClearing:last.bundleID].firstObject;
    [many removeLastObject];
    [rail updateWithItems:many selected:neighbor]; [host.view layoutIfNeeded];
    Expect(scroll.contentOffset.x > 100 && scroll.contentOffset.x <= endOffset &&
        fabs(scroll.contentOffset.x - MAX(0, scroll.contentSize.width - scroll.bounds.size.width)) < 1,
        "clearing last capsule jumped to start instead of nearest remaining end");
    [rail updateWithItems:many selected:nil]; [host.view layoutIfNeeded];
    Expect(scroll.contentOffset.x > 100, "hidden All reset horizontal position");
    AXNWritePreference(@"ShowAll", @YES); [rail updateWithItems:@[a, b] selected:b.bundleID];
    [host.view layoutIfNeeded];
    beta = nil;
    for (UIButton *button in Buttons(rail)) if ([button.accessibilityLabel isEqualToString:b.name]) beta = button;
    Expect(Buttons(rail).count == 3 && beta, "All switch could not restore its capsule");
    fputs("AXN_FEATURE_STAGE: preferences and cleanup\n", stderr); fflush(stderr);
    AXNWritePreference(@"ShowCounts", @NO); AXNWritePreference(@"Compact", @YES);
    [rail updateWithItems:@[a, b] selected:b.bundleID]; [host.view layoutIfNeeded];
    Expect([beta.accessibilityValue hasPrefix:@"1001 notifications"], "visual count preference removed accessible count");
    [rail updateWithItems:@[] selected:nil]; Expect(rail.hidden, "empty rail stayed visible");
    [host willMoveToParentViewController:nil]; [host.view removeFromSuperview]; [host removeFromParentViewController];
    for (NSString *key in keys) AXNWritePreference(key, saved[key]);
    puts("AXN_RAIL_FEATURE_TEST_PASS: no capsule animation, equal-height spacing, ShowAll, clear action, neighbor order, end deletion viewport, held touch, VoiceOver and large text");
}

