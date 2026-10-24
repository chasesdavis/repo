// SPDX-License-Identifier: GPL-3.0-only
#import "AXNListMount.h"
#import <objc/message.h>
#import <objc/runtime.h>
#include "../Core/InsetReservation.hpp"
#include <string.h>

// iOS 17's master list opts into bottom alignment. A header inset alone does
// not move its short lists under the selector. Use the list's layout switch,
// scoped to this mount, rather than moving notification views by hand.
static BOOL HasAlignmentInterface(UIScrollView *view) {
    Method getter = class_getInstanceMethod(view.class, NSSelectorFromString(@"layoutFromBottom"));
    Method setter = class_getInstanceMethod(view.class, NSSelectorFromString(@"setLayoutFromBottom:"));
    if (!getter || !setter || method_getNumberOfArguments(getter) != 2 || method_getNumberOfArguments(setter) != 3) return NO;
    char type[128] = {};
    method_getReturnType(getter, type, sizeof(type));
    if (!type[0] || !strchr("Bc", type[0])) return NO;
    method_getReturnType(setter, type, sizeof(type));
    if (type[0] != 'v') return NO;
    method_getArgumentType(setter, 2, type, sizeof(type));
    return type[0] && strchr("Bc", type[0]);
}
static BOOL BottomAligned(UIScrollView *view) {
    return ((BOOL (*)(id, SEL))objc_msgSend)(view, NSSelectorFromString(@"layoutFromBottom"));
}
static void SetBottomAligned(UIScrollView *view, BOOL value) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(view, NSSelectorFromString(@"setLayoutFromBottom:"), value);
    [view setNeedsLayout];
}

@interface AXNListMount () {
    axon::InsetReservation _reservation;
    BOOL _updating;
    BOOL _nativeList;
    BOOL _ownsAlignment;
    BOOL _previousBottomAlignment;
}
@property(nonatomic, strong, readwrite) AXNRailView *rail;
@property(nonatomic, weak, readwrite) UIScrollView *scrollView;
@property(nonatomic, strong) NSLayoutConstraint *top;
@property(nonatomic, strong) NSArray<NSLayoutConstraint *> *constraints;
@end
@implementation AXNListMount
- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    if (!(self = [super init])) return nil;
    Class nativeClass = NSClassFromString(@"NCNotificationListView");
    _nativeList = nativeClass && [scrollView isKindOfClass:nativeClass];
    if (_nativeList && !HasAlignmentInterface(scrollView)) return nil;
    _scrollView = scrollView;
    _rail = [[AXNRailView alloc] initWithFrame:CGRectZero];
    _rail.hidden = YES;
    // The header scrolls with the notification content. Its own inset keeps it
    // above the first card; no native views, data sources or delegates are replaced.
    [scrollView addSubview:_rail];
    _top = [_rail.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor];
    _constraints = @[_top,
        [_rail.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:6],
        [_rail.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-6]];
    [NSLayoutConstraint activateConstraints:_constraints];
    return self;
}
- (BOOL)updateVisible:(BOOL)visible {
    UIScrollView *scrollView = self.scrollView;
    if (_updating || !scrollView || (visible && self.rail.superview != scrollView)) return NO;
    _updating = YES;
    if (_nativeList) {
        @try {
            if (visible) {
                if (!_ownsAlignment) {
                    _previousBottomAlignment = BottomAligned(scrollView);
                    _ownsAlignment = YES;
                }
                if (BottomAligned(scrollView)) SetBottomAligned(scrollView, NO);
            } else if (_ownsAlignment) {
                // If native code already changed this back, leave its value.
                if (!BottomAligned(scrollView)) SetBottomAligned(scrollView, _previousBottomAlignment);
                _ownsAlignment = NO;
            }
        } @catch (NSException *exception) {
            (void)exception; visible = NO;
        }
    }
    CGFloat height = visible ? self.rail.preferredRailHeight : 0;
    UIEdgeInsets inset = scrollView.contentInset;
    CGFloat next = _reservation.update(inset.top, height);
    CGPoint offset = scrollView.contentOffset;
    BOOL atTop = fabs(offset.y + scrollView.adjustedContentInset.top) < 2;
    CGFloat delta = next - inset.top;
    self.rail.hidden = !visible;
    self.top.constant = -height;
    if (fabs(delta) > 0.25) {
        inset.top = next;
        scrollView.contentInset = inset;
        // Reveal the new header at rest, but never move a user's active scroll.
        if (atTop && !scrollView.tracking && !scrollView.dragging && !scrollView.decelerating)
            scrollView.contentOffset = CGPointMake(offset.x, offset.y - delta);
    }
    if (visible) [scrollView bringSubviewToFront:self.rail];
    _updating = NO;
    return visible && self.rail.window && self.rail.bounds.size.width > 0 && self.rail.bounds.size.height > 0;
}
- (BOOL)showSelection {
    UIScrollView *scrollView = self.scrollView;
    if (!scrollView.window || self.rail.hidden || self.rail.superview != scrollView ||
        scrollView.tracking || scrollView.dragging || scrollView.decelerating) return NO;
    // Run after filtering/reveal and native layout, once per explicit selection.
    // A short app must not inherit the old offset from a much longer list.
    [self updateVisible:YES];
    [scrollView layoutIfNeeded];
    if (self.rail.hidden) return NO;
    [scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, -scrollView.adjustedContentInset.top) animated:NO];
    [scrollView setNeedsLayout];
    [scrollView layoutIfNeeded];
    return YES;
}
- (void)detach {
    [self updateVisible:NO];
    [NSLayoutConstraint deactivateConstraints:self.constraints];
    [self.rail removeFromSuperview];
}
- (void)dealloc {
    [self detach];
}
@end
