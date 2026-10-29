#import <UIKit/UIKit.h>

@interface LumenCard : NSObject
+ (void)presentForPill:(NSString *)pill inView:(UIView *)container;
+ (void)dismissVisible;
@end
