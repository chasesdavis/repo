#import <UIKit/UIKit.h>

/// Drives the status bar pill overlay and its cards.
@interface LumenPill : NSObject
+ (instancetype)shared;
/// Rebuild the pill from current prefs and readings.
- (void)attach;
- (void)refresh;
- (void)teardown;
/// Cycle to the next enabled pill, then re-render.
- (void)cyclePill;
/// Present the card for the active pill.
- (void)openCard;
@end
