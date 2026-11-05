#import <UIKit/UIKit.h>

// Adapts already-loaded Apple controls. No radio state caches or private setters.
@interface HBNativeControls : NSObject
@property (nonatomic, weak) UIViewController *collection;
- (UIControl *)buttonForKey:(NSString *)key;
- (BOOL)activateKey:(NSString *)key;
@end
