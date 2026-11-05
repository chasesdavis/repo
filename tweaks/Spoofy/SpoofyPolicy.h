#import <Foundation/Foundation.h>
// Returns a validated replacement, or nil for pass-through. Pure policy shared by tests.
#ifdef __cplusplus
extern "C" {
#endif
NSString *SpoofyReplacement(id config, NSString *bundleID, NSOperatingSystemVersion actualOS);
#ifdef __cplusplus
}
#endif
