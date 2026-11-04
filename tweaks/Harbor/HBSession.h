#import <UIKit/UIKit.h>

@interface HBSession : NSObject
+ (instancetype)sessionForHost:(UIViewController *)host create:(BOOL)create;
+ (void)preferencesChanged;
- (void)begin;
- (void)layout;
- (void)end;
@end
