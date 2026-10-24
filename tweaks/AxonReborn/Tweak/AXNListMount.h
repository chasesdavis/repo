// SPDX-License-Identifier: GPL-3.0-only
#import "AXNRailView.h"
@interface AXNListMount : NSObject
@property(nonatomic, strong, readonly) AXNRailView *rail;
@property(nonatomic, weak, readonly) UICollectionView *collection;
- (instancetype)initWithCollection:(UICollectionView *)collection;
- (BOOL)updateVisible:(BOOL)visible;
- (void)detach;
@end
