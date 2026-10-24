// SPDX-License-Identifier: GPL-3.0-only
#import "AXNListMount.h"
#include "../Core/InsetReservation.hpp"

@interface AXNListMount () {
    axon::InsetReservation _reservation;
    BOOL _updating;
}
@property(nonatomic, strong, readwrite) AXNRailView *rail;
@property(nonatomic, weak, readwrite) UIScrollView *scrollView;
@property(nonatomic, strong) NSLayoutConstraint *top;
@property(nonatomic, strong) NSArray<NSLayoutConstraint *> *constraints;
@end
@implementation AXNListMount
- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    if (!(self = [super init])) return nil;
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
    if (_updating || !scrollView || self.rail.superview != scrollView) return NO;
    _updating = YES;
    CGFloat height = visible ? MAX(106, [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize * 2 + 68) : 0;
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
        if (atTop && !scrollView.dragging && !scrollView.decelerating)
            scrollView.contentOffset = CGPointMake(offset.x, offset.y - delta);
    }
    if (visible) [scrollView bringSubviewToFront:self.rail];
    _updating = NO;
    return visible && self.rail.window && self.rail.bounds.size.width > 0 && self.rail.bounds.size.height > 0;
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
