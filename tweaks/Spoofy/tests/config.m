#import "../SpoofyConfig.h"
#import "../SpoofyPolicy.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *path = [dir stringByAppendingPathComponent:@"prefs/config.plist"];
    NSOperatingSystemVersion os = {17,0,0};
    assert(SpoofyReadConfig(path) == nil);
    assert(!SpoofySaveEnabled(@"", YES));
    assert(SpoofySaveEnabled(path, YES));
    assert([SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) isEqual:@"18.0"]);
    assert(!SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(!SpoofyCallCategoriesEnabled(SpoofyReadConfig(path)));
    assert(!SpoofyCallCategoriesEnabled(@{@"CallCategories":@"YES"}));
    assert(!SpoofyDiagnosticsEnabled(@{@"Diagnostics":@"YES"}));
    assert(SpoofySaveDiagnostics(path, YES));
    assert(SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(SpoofySaveCallCategories(path, YES));
    assert(SpoofyCallCategoriesEnabled(SpoofyReadConfig(path)));
    assert(SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(SpoofyShouldCollectCallCategories(SpoofyReadConfig(path), YES));
    assert(!SpoofyShouldCollectCallCategories(SpoofyReadConfig(path), NO));
    assert([SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) isEqual:@"18.0"]);
    assert(SpoofySaveEnabled(path, NO));
    assert(SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(SpoofyCallCategoriesEnabled(SpoofyReadConfig(path)));
    assert(SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) == nil);
    assert(SpoofySaveDiagnostics(path, NO));
    assert(!SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(SpoofyCallCategoriesEnabled(SpoofyReadConfig(path)));
    assert(!SpoofyShouldCollectCallCategories(SpoofyReadConfig(path), YES));
    assert(SpoofySaveCallCategories(path, NO));
    assert(!SpoofyCallCategoriesEnabled(SpoofyReadConfig(path)));
    NSString *statusPath = [dir stringByAppendingPathComponent:@"prefs/status.plist"];
    BOOL exists = YES;
    assert(SpoofyDiagnosticReportExists(statusPath, &exists) && !exists);
    assert(!SpoofyDiagnosticReportExists(@"", &exists));
    assert(!SpoofyDiagnosticReportExists(statusPath, NULL));
    assert(!SpoofyWriteDiagnostic(statusPath, @"untrusted-content"));
    assert(SpoofyWriteDiagnostic(statusPath, @"getter_called"));
    assert(SpoofyDiagnosticReportExists(statusPath, &exists) && exists);
    NSDictionary *report = SpoofyReadConfig(statusPath);
    assert([report[@"state"] isEqual:@"getter_called"] && [report[@"timestamp"] isKindOfClass:NSDate.class] && report.count == 8);
    assert(![report[@"deviceVersion"] boolValue] && ![report[@"processVersion"] boolValue] && ![report[@"processMinimum"] boolValue]);
    assert(!SpoofyWriteDiagnosticSnapshot(statusPath, @"getter_called", (SpoofyObservations)(1 << 7)));
    assert(SpoofyWriteDiagnosticSnapshot(statusPath, @"getter_called", SpoofyObservedDeviceVersion | SpoofyObservedProcessMinimum));
    report = SpoofyReadConfig(statusPath);
    assert([report[@"deviceVersion"] boolValue] && ![report[@"processVersion"] boolValue] && [report[@"processMinimum"] boolValue]);
    assert(![report[@"processHooksMeasured"] boolValue]);
    assert(!SpoofyWriteDiagnosticWithHooks(statusPath, @"getter_called", 0, SpoofyProcessVersionHookChanged));
    assert(!SpoofyWriteDiagnosticWithHooks(statusPath, @"getter_called", 0, (SpoofyHookChecks)(1 << 9)));
    assert(SpoofyWriteDiagnosticWithHooks(statusPath, @"hook_change_observed", 0, SpoofyHookChecksMeasured | SpoofyProcessVersionHookChanged));
    report = SpoofyReadConfig(statusPath);
    assert([report[@"processHooksMeasured"] boolValue] && [report[@"processVersionHookChanged"] boolValue] && ![report[@"processMinimumHookChanged"] boolValue]);
    assert(!SpoofyWriteDiagnosticWithCategories(statusPath, @"getter_called", 0, 0, NO, SpoofyDeviceDiagnostic));
    assert(!SpoofyWriteDiagnosticWithCategories(statusPath, @"getter_called", 0, 0, YES, (SpoofyCallCategories)(1 << 8)));
    assert(SpoofyWriteDiagnosticWithCategories(statusPath, @"getter_called", 0, 0, YES, SpoofyDeviceDiagnostic | SpoofyMinimumUnknown));
    NSDictionary *categoryReport = SpoofyReadConfig(statusPath);
    assert(categoryReport.count == 14);
    assert([categoryReport[@"categoryDeviceDiagnostic"] boolValue] && [categoryReport[@"categoryMinimumUnknown"] boolValue]);
    assert(![categoryReport[@"categoryDeviceUnknown"] boolValue] && ![categoryReport[@"categoryProcessDiagnostic"] boolValue]);
    for (NSString *key in @[@"categoryDeviceDiagnostic", @"categoryDeviceUnknown", @"categoryProcessDiagnostic", @"categoryProcessUnknown", @"categoryMinimumDiagnostic", @"categoryMinimumUnknown"]) {
        assert(CFGetTypeID((__bridge CFTypeRef)categoryReport[key]) == CFBooleanGetTypeID());
    }
    for (NSString *key in @[@"deviceVersion", @"processVersion", @"processMinimum", @"processHooksMeasured", @"processVersionHookChanged", @"processMinimumHookChanged"]) {
        assert(CFGetTypeID((__bridge CFTypeRef)report[key]) == CFBooleanGetTypeID());
    }
    // Real beta 3/4 report payloads contained integers, not booleans.
    NSDictionary *legacyValues = @{@"yes": [NSNumber numberWithInt:1], @"no": [NSNumber numberWithInt:0]};
    assert([legacyValues writeToFile:statusPath atomically:YES]);
    NSDictionary *legacy = SpoofyReadConfig(statusPath);
    BOOL decoded = NO;
    NSData *legacyBytes = [NSData dataWithContentsOfFile:statusPath];
    BOOL legacyExists = NO;
    BOOL legacyKnown = SpoofyDiagnosticReportExists(statusPath, &legacyExists);
    assert(!SpoofyDiagnosticMayStart(YES, legacyExists, legacyKnown));
    assert([legacyBytes isEqual:[NSData dataWithContentsOfFile:statusPath]]);
    assert(SpoofyDiagnosticBool(legacy[@"yes"], &decoded) && decoded);
    assert(SpoofyDiagnosticBool(legacy[@"no"], &decoded) && !decoded);
    NSDictionary *legacyReport = @{@"deviceVersion": @1, @"processVersion": @0, @"processMinimum": @1, @"processHooksMeasured": @1, @"processVersionHookChanged": @1, @"processMinimumHookChanged": @0};
    assert([legacyReport writeToFile:statusPath atomically:YES]);
    legacy = SpoofyReadConfig(statusPath);
    for (NSString *key in legacyReport) {
        assert(SpoofyDiagnosticBool(legacy[key], &decoded));
        assert(decoded == [legacyReport[key] boolValue]);
    }
    assert(SpoofyDiagnosticBool(@YES, &decoded) && decoded);
    assert(SpoofyDiagnosticBool(@NO, &decoded) && !decoded);
    for (id invalid in @[@2, @(-1), @1.0, @"1", NSNull.null]) assert(!SpoofyDiagnosticBool(invalid, &decoded));
    assert(!SpoofyDiagnosticBool(nil, &decoded) && !SpoofyDiagnosticBool(@YES, NULL));
    assert(SpoofyDiagnosticMayStart(YES, NO, YES));
    assert(!SpoofyDiagnosticMayStart(NO, NO, YES));
    assert(!SpoofyDiagnosticMayStart(YES, YES, YES));
    assert(!SpoofyDiagnosticMayStart(YES, NO, NO));
    assert(SpoofyClearDiagnostic(statusPath));
    assert(SpoofyReadConfig(statusPath) == nil);
    assert(SpoofyClearDiagnostic(statusPath));
    assert(!SpoofyClearDiagnostic(@""));
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    puts("Shared config round-trip passed");
} return 0; }
