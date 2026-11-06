#import <Foundation/Foundation.h>
#define SPOOFY_CONFIG_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.compat.plist"
#define SPOOFY_DIAGNOSTIC_PATH @"/var/mobile/Library/Preferences/com.chasedavis.spoofy.diagnostics.plist"
typedef NS_OPTIONS(NSUInteger, SpoofyObservations) {
    SpoofyObservedDeviceVersion = 1 << 0,
    SpoofyObservedProcessVersion = 1 << 1,
    SpoofyObservedProcessMinimum = 1 << 2,
};
typedef NS_OPTIONS(NSUInteger, SpoofyHookChecks) {
    SpoofyHookChecksMeasured = 1 << 0,
    SpoofyProcessVersionHookChanged = 1 << 1,
    SpoofyProcessMinimumHookChanged = 1 << 2,
};
typedef NS_OPTIONS(NSUInteger, SpoofyCallCategories) {
    SpoofyDeviceDiagnostic = 1 << 0,
    SpoofyDeviceUnknown = 1 << 1,
    SpoofyProcessDiagnostic = 1 << 2,
    SpoofyProcessUnknown = 1 << 3,
    SpoofyMinimumDiagnostic = 1 << 4,
    SpoofyMinimumUnknown = 1 << 5,
};
#ifdef __cplusplus
extern "C" {
#endif
BOOL SpoofySaveEnabled(NSString *path, BOOL enabled);
BOOL SpoofySaveDiagnostics(NSString *path, BOOL enabled);
BOOL SpoofyDiagnosticsEnabled(id config);
BOOL SpoofySaveCallCategories(NSString *path, BOOL enabled);
BOOL SpoofyCallCategoriesEnabled(id config);
BOOL SpoofyShouldCollectCallCategories(id config, BOOL diagnosticSessionActive);
BOOL SpoofyWriteDiagnostic(NSString *path, NSString *state);
BOOL SpoofyWriteDiagnosticSnapshot(NSString *path, NSString *state, SpoofyObservations observations);
BOOL SpoofyWriteDiagnosticWithHooks(NSString *path, NSString *state, SpoofyObservations observations, SpoofyHookChecks hooks);
BOOL SpoofyWriteDiagnosticWithCategories(NSString *path, NSString *state, SpoofyObservations observations, SpoofyHookChecks hooks, BOOL categoriesEnabled, SpoofyCallCategories categories);
BOOL SpoofyDiagnosticBool(id value, BOOL *result);
BOOL SpoofyDiagnosticMayStart(BOOL requested, BOOL reportExists, BOOL reportStateKnown);
BOOL SpoofyDiagnosticReportExists(NSString *path, BOOL *exists);
BOOL SpoofyClearDiagnostic(NSString *path);
NSDictionary *SpoofyReadConfig(NSString *path);
#ifdef __cplusplus
}
#endif
