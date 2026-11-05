#import <Foundation/Foundation.h>
#define SPOOFY_CONFIG_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.compat.plist"
#define SPOOFY_DIAGNOSTIC_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.diagnostics.plist"
#ifdef __cplusplus
extern "C" {
#endif
BOOL SpoofySaveEnabled(NSString *path, BOOL enabled);
BOOL SpoofySaveDiagnostics(NSString *path, BOOL enabled);
BOOL SpoofyDiagnosticsEnabled(id config);
BOOL SpoofyWriteDiagnostic(NSString *path, NSString *state);
NSDictionary *SpoofyReadConfig(NSString *path);
#ifdef __cplusplus
}
#endif
