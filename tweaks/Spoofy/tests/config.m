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
    assert(!SpoofyDiagnosticsEnabled(@{@"Diagnostics":@"YES"}));
    assert(SpoofySaveDiagnostics(path, YES));
    assert(SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert([SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) isEqual:@"18.0"]);
    assert(SpoofySaveEnabled(path, NO));
    assert(SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    assert(SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) == nil);
    assert(SpoofySaveDiagnostics(path, NO));
    assert(!SpoofyDiagnosticsEnabled(SpoofyReadConfig(path)));
    NSString *statusPath = [dir stringByAppendingPathComponent:@"prefs/status.plist"];
    assert(!SpoofyWriteDiagnostic(statusPath, @"untrusted-content"));
    assert(SpoofyWriteDiagnostic(statusPath, @"getter_called"));
    NSDictionary *report = SpoofyReadConfig(statusPath);
    assert([report[@"state"] isEqual:@"getter_called"] && [report[@"timestamp"] isKindOfClass:NSDate.class] && report.count == 5);
    assert(![report[@"deviceVersion"] boolValue] && ![report[@"processVersion"] boolValue] && ![report[@"processMinimum"] boolValue]);
    assert(!SpoofyWriteDiagnosticSnapshot(statusPath, @"getter_called", (SpoofyObservations)(1 << 7)));
    assert(SpoofyWriteDiagnosticSnapshot(statusPath, @"getter_called", SpoofyObservedDeviceVersion | SpoofyObservedProcessMinimum));
    report = SpoofyReadConfig(statusPath);
    assert([report[@"deviceVersion"] boolValue] && ![report[@"processVersion"] boolValue] && [report[@"processMinimum"] boolValue]);
    assert(SpoofyClearDiagnostic(statusPath));
    assert(SpoofyReadConfig(statusPath) == nil);
    assert(SpoofyClearDiagnostic(statusPath));
    assert(!SpoofyClearDiagnostic(@""));
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    puts("Shared config round-trip passed");
} return 0; }
