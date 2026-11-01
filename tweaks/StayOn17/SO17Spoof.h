#pragma once
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void SO17ReloadSpoofState(void);
BOOL SO17SpoofActive(void);
NSString *SO17SpoofVersionString(void);
NSString *SO17RealVersionString(void);
NSString *SO17RewriteString(NSString *value);
NSData *SO17RewriteData(NSData *data);
BOOL SO17IsMinimumOSKey(NSString *key);

#ifdef __cplusplus
}
#endif
