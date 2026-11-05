#import "SpoofyPolicy.h"

NSString *SpoofyReplacement(id config, NSString *bundleID, NSOperatingSystemVersion actualOS) {
    if (![bundleID isEqualToString:@"com.apple.AppStore"] ||
        actualOS.majorVersion != 17 || actualOS.minorVersion != 0 || actualOS.patchVersion != 0 ||
        ![config isKindOfClass:NSDictionary.class]) return nil;
    // Require an actual plist boolean, not a truthy string or number.
    id enabled = config[@"Enabled"];
    if (!enabled || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID() ||
        ![enabled boolValue]) return nil;
    id version = config[@"ReportedVersion"];
    if (![version isKindOfClass:NSString.class] || [version length] > 10) return nil;
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:
        @"^(?:17|18|26)\\.(?:0|[1-9][0-9]?)(?:\\.(?:0|[1-9][0-9]?))?$" options:0 error:NULL];
    NSRange full = NSMakeRange(0, [version length]);
    NSTextCheckingResult *match = [pattern firstMatchInString:version options:0 range:full];
    if (!match || !NSEqualRanges(match.range, full)) return nil;
    NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
    if (parts[0].integerValue == 17 && parts[1].integerValue == 0 &&
        (parts.count < 3 || parts[2].integerValue == 0)) return nil;
    return [version copy];
}
