#import "SO17Spoof.h"
#import "SO17Prefs.h"
#import <sys/utsname.h>

static BOOL gActive = NO;
static NSString *gReal = nil;
static NSString *gSpoof = nil;

NSString *SO17RealVersionString(void) {
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (v.patchVersion > 0)
        return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
    return [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
}

void SO17ReloadSpoofState(void) {
    [[SO17Prefs shared] reload];
    gReal = SO17RealVersionString();
    gActive = SO17ShouldSpoofInCurrentProcess();
    gSpoof = gActive ? SO17EffectiveSpoofVersion() : gReal;
    if (gSpoof.length && [gSpoof rangeOfString:@"."].location == NSNotFound)
        gSpoof = [gSpoof stringByAppendingString:@".0"];
}

BOOL SO17SpoofActive(void) { return gActive; }
NSString *SO17SpoofVersionString(void) { return gSpoof ?: SO17RealVersionString(); }

BOOL SO17IsMinimumOSKey(NSString *key) {
    if (![key isKindOfClass:[NSString class]]) return NO;
    return [key isEqualToString:@"MinimumOSVersion"]
        || [key isEqualToString:@"LSMinimumSystemVersion"]
        || [key isEqualToString:@"MinimumOSVersionString"];
}

NSString *SO17RewriteString(NSString *value) {
    if (!gActive || !value.length) return value;
    NSString *spoof = SO17SpoofVersionString();
    NSString *real = gReal ?: SO17RealVersionString();
    NSMutableString *out = [value mutableCopy];
    if (real.length) [out replaceOccurrencesOfString:real withString:spoof options:0 range:NSMakeRange(0, out.length)];
    NSString *under = [spoof stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    NSString *realUnder = [real stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    if (realUnder.length) [out replaceOccurrencesOfString:realUnder withString:under options:0 range:NSMakeRange(0, out.length)];
    return [out copy];
}

NSData *SO17RewriteData(NSData *data) {
    if (!gActive || data.length == 0 || data.length > 2 * 1024 * 1024) return data;
    const uint8_t *b = data.bytes;
    if (b[0] != '{' && b[0] != '[') return data;
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s) return data;
    NSString *o = SO17RewriteString(s);
    return [o isEqualToString:s] ? data : [o dataUsingEncoding:NSUTF8StringEncoding];
}
