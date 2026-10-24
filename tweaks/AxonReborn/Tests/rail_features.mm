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
    NSArray *keys = @[@"PinnedApps", @"Density", @"Motion", @"Compact", @"ShowCounts"];
    NSMutableDictionary *saved = [NSMutableDictionary new];
    for (NSString *key in keys) saved[key] = AXNReadPreference(key, @0);
    AXNWritePreference(@"PinnedApps", @[]); AXNWritePreference(@"Motion", @NO);
    AXNWritePreference(@"Compact", @NO); AXNWritePreference(@"ShowCounts", @YES);
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
    CGFloat previous = 0, previousCapsule = 0;
    for (NSNumber *density in @[@0, @1, @2]) {
        AXNWritePreference(@"Density", density); [rail updateWithItems:@[a, b] selected:b.bundleID];
        [host.view setNeedsLayout]; [host.view layoutIfNeeded];
        Expect(rail.preferredRailHeight > previous && fabs(rail.bounds.size.height - rail.preferredRailHeight) < 1,
            "density does not match shared geometry");
        Expect(beta.bounds.size.height > previousCapsule, "density expanded header whitespace instead of capsules");
        previousCapsule = beta.bounds.size.height; previous = rail.preferredRailHeight;
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
    fputs("AXN_FEATURE_STAGE: preferences and cleanup\n", stderr); fflush(stderr);
    AXNWritePreference(@"ShowCounts", @NO); AXNWritePreference(@"Compact", @YES);
    [rail updateWithItems:@[a, b] selected:b.bundleID]; [host.view layoutIfNeeded];
    Expect([beta.accessibilityValue hasPrefix:@"1001 notifications"], "visual count preference removed accessible count");
    [rail updateWithItems:@[] selected:nil]; Expect(rail.hidden, "empty rail stayed visible");
    [host willMoveToParentViewController:nil]; [host.view removeFromSuperview]; [host removeFromParentViewController];
    for (NSString *key in keys) AXNWritePreference(key, saved[key]);
    puts("AXN_RAIL_FEATURE_TEST_PASS: held touch, scroll coalescing, VoiceOver actions, favorites, densities, large text and narrow widths");
}
