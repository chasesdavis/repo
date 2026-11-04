#import <UIKit/UIKit.h>
#import "HBMediaProvider.h"

typedef NS_ENUM(NSInteger, HBSystemDestination) {
    HBSystemDestinationAll, HBSystemDestinationConnections, HBSystemDestinationFocus, HBSystemDestinationVolume
};

@interface HBDashboardController : UIViewController
@property (nonatomic, copy) void (^openSystemControls)(HBSystemDestination destination);
// Only Harbor's backdrop is moved; Apple's background/headers remain in place.
- (void)useBackdropHost:(UIView *)host;
- (void)setDashboardActive:(BOOL)active;
- (void)applyAppearance;
// Also used by the standalone preview harness; production data comes from MediaRemote.
- (void)displayMedia:(HBMediaSnapshot *)snapshot;
@end
