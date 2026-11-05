#import <UIKit/UIKit.h>

@interface HBSession : NSObject
+ (instancetype)sessionForHost:(UIViewController *)host create:(BOOL)create;
+ (void)preferencesChanged;
- (void)begin;
- (void)layout;
- (void)scrollPositionChanged;
- (BOOL)ownsTouchView:(UIView *)view recognizer:(UIGestureRecognizer *)recognizer;
- (BOOL)ownsGestureStart:(UIGestureRecognizer *)recognizer;
- (void)end;
@end
