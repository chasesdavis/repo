#import <UIKit/UIKit.h>
@class HBNativeControls;

@interface HBProfileEditorController : UIViewController
- (instancetype)initWithLibrary:(NSDictionary *)library profileID:(NSString *)identifier focus:(NSDictionary *)focus;
@property (nonatomic, strong) HBNativeControls *nativeControls;
@property (nonatomic, copy) void (^onFinish)(BOOL saved);
@property (nonatomic, copy) void (^onRefreshFocus)(void);
@property (nonatomic, copy) void (^onPauseFocus)(void);
- (void)updateFocusSnapshot:(NSDictionary *)snapshot;
@end
