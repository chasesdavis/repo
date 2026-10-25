// SPDX-License-Identifier: GPL-3.0-only
#import <UIKit/UIKit.h>
@interface AXNRailItem : NSObject
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) UIImage *icon;
@property(nonatomic) NSUInteger count;
@end

@interface AXNRailView : UIView
@property(nonatomic, copy) void (^onSelect)(NSString *bundleID);
// Requests a confirmation; the rail never clears native requests itself.
@property(nonatomic, copy) void (^onRequestClear)(NSString *bundleID);
- (NSArray<NSString *> *)replacementAppsForClearing:(NSString *)bundleID;
- (CGFloat)preferredRailHeight;
- (void)updateWithItems:(NSArray<AXNRailItem *> *)items selected:(NSString *)selected;
@end

