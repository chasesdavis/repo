#import <Foundation/Foundation.h>
#define SPOOFY_CONFIG_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.compat.plist"
#ifdef __cplusplus
extern "C" {
#endif
BOOL SpoofySaveEnabled(NSString *path, BOOL enabled);
NSDictionary *SpoofyReadConfig(NSString *path);
#ifdef __cplusplus
}
#endif
