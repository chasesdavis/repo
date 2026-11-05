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
    assert(SpoofySaveEnabled(path, NO));
    assert(SpoofyReplacement(SpoofyReadConfig(path), @"com.apple.AppStore", os) == nil);
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    puts("Shared config round-trip passed");
} return 0; }
