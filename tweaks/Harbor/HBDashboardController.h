#import <UIKit/UIKit.h>
#import "HBMediaProvider.h"
#import "HBNativeControls.h"

typedef NS_ENUM(NSInteger, HBSystemDestination) {
    HBSystemDestinationAll, HBSystemDestinationConnections, HBSystemDestinationFocus, HBSystemDestinationVolume,
    HBSystemDestinationFlashlight, HBSystemDestinationTimer, HBSystemDestinationCalculator, HBSystemDestinationCamera,
    HBSystemDestinationRecording, HBSystemDestinationRemote, HBSystemDestinationHearing, HBSystemDestinationBrightness
};

@interface HBDashboardController : UIViewController
@property (nonatomic, copy) void (^openSystemControls)(HBSystemDestination destination);
@property (nonatomic, strong) HBNativeControls *nativeControls;
@property (nonatomic) BOOL previewMode;
@property (nonatomic, copy, readonly) NSDictionary *profile;
@property (nonatomic, copy, readonly) NSDictionary *focusSnapshot;
- (CGRect)previewSheetFrame;
- (void)applyProfile:(NSDictionary *)profile expanded:(BOOL)expanded;
// Shared ingress for the read-only monitor and isolated simulator fixtures.
- (void)acceptFocusSnapshot:(NSDictionary *)snapshot;
// True only inside Harbor's interactive sheet; native status/edge dismissal stays native.
- (BOOL)containsInteractionPoint:(CGPoint)point;
// Only Harbor's backdrop is moved; Apple's background/headers remain in place.
- (void)useBackdropHost:(UIView *)host;
- (void)setDashboardActive:(BOOL)active;
- (void)applyAppearance;
// Also used by the standalone preview harness; production data comes from MediaRemote.
- (void)displayMedia:(HBMediaSnapshot *)snapshot;
@end
