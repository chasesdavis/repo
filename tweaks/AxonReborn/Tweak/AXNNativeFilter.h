// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
@interface AXNNativeFilter : NSObject
@property(nonatomic, readonly) BOOL available;
@property(nonatomic, readonly) NSUInteger appliedCount;
- (instancetype)initWithOwner:(id)owner;
// Restore only rules this instance applied. Existing native exclusions win.
- (BOOL)applyHiddenApps:(NSSet<NSString *> *)apps preservingNativeApps:(NSSet<NSString *> *)nativeApps;
@property(nonatomic, readonly, copy) NSString *revealStatus;
- (BOOL)revealHistory;
@end
