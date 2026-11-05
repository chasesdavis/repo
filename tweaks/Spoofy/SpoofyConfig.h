#import <Foundation/Foundation.h>
#define SPOOFY_CONFIG_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.compat.plist"
#define SPOOFY_DIAGNOSTIC_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.diagnostics.plist"
typedef NS_OPTIONS(NSUInteger, SpoofyObservations) {
    SpoofyObservedDeviceVersion = 1 << 0,
    SpoofyObservedProcessVersion = 1 << 1,
    SpoofyObservedProcessMinimum = 1 << 2,
};
#ifdef __cplusplus
extern "C" {
#endif
BOOL SpoofySaveEnabled(NSString *path, BOOL enabled);
BOOL SpoofySaveDiagnostics(NSString *path, BOOL enabled);
BOOL SpoofyDiagnosticsEnabled(id config);
BOOL SpoofyWriteDiagnostic(NSString *path, NSString *state);
BOOL SpoofyWriteDiagnosticSnapshot(NSString *path, NSString *state, SpoofyObservations observations);
BOOL SpoofyClearDiagnostic(NSString *path);
NSDictionary *SpoofyReadConfig(NSString *path);
#ifdef __cplusplus
}
#endif
