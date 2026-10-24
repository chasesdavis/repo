// SPDX-License-Identifier: GPL-3.0-only
#import "AXNRailView.h"
@interface AXNListMount : NSObject
@property(nonatomic, strong, readonly) AXNRailView *rail;
@property(nonatomic, weak, readonly) UIScrollView *scrollView;
- (instancetype)initWithScrollView:(UIScrollView *)scrollView;
- (BOOL)updateVisible:(BOOL)visible;
- (BOOL)showSelection;
- (void)detach;
@end
