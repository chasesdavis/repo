#import "SO17Prefs.h"
#import <notify.h>

NSString * const kSO17PrefsDomain = @"com.chase.stayon17";
NSString * const kSO17PrefsChangedNotification = @"com.chase.stayon17/prefschanged";
static NSString * const kSO17PrefsPath = @"/var/mobile/Library/Preferences/com.chase.stayon17.plist";

@interface SO17Prefs ()
@property (nonatomic, strong) NSDictionary *cache;
@end

@implementation SO17Prefs

+ (instancetype)shared {
    static SO17Prefs *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[SO17Prefs alloc] init]; [s reload]; });
    return s;
}

- (void)reload {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kSO17PrefsPath];
    self.cache = d ?: @{};
}

- (id)val:(NSString *)key { return self.cache[key]; }
- (id)valueForKey:(NSString *)key { return [self val:key]; }

- (void)writeDict:(NSDictionary *)patch {
    NSMutableDictionary *m = [self.cache mutableCopy] ?: [NSMutableDictionary dictionary];
    [m addEntriesFromDictionary:patch];
    self.cache = m;
    [m writeToFile:kSO17PrefsPath atomically:YES];
    CFPreferencesSetMultiple((__bridge CFDictionaryRef)patch, NULL, (__bridge CFStringRef)kSO17PrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((__bridge CFStringRef)kSO17PrefsDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

- (BOOL)globalEnabled { id v = [self val:@"globalEnabled"]; return v ? [v boolValue] : YES; }
- (BOOL)patchMinimumOSOnDownload { return [[self val:@"patchMinimumOSOnDownload"] boolValue]; }
- (BOOL)marketingVersionOnly { id v = [self val:@"marketingVersionOnly"]; return v ? [v boolValue] : YES; }
- (NSArray<NSString *> *)enabledBundleIDs { id v = [self val:@"enabledBundleIDs"]; return [v isKindOfClass:[NSArray class]] ? v : @[]; }
- (BOOL)isBundleEnabled:(NSString *)bundleID { return bundleID.length && [[self enabledBundleIDs] containsObject:bundleID]; }
- (NSString *)defaultSpoofVersion { return @"18.0"; }
- (NSString *)spoofVersionForBundle:(NSString *)bundleID {
    NSDictionary *map = [self val:@"spoofVersionByBundle"];
    if ([map isKindOfClass:[NSDictionary class]]) {
        NSString *v = map[bundleID];
        if ([v isKindOfClass:[NSString class]] && v.length) return v;
    }
    return [self defaultSpoofVersion];
}
- (NSDictionary *)scanCacheForBundle:(NSString *)bundleID {
    NSDictionary *all = [self val:@"scanCacheByBundle"];
    return ([all isKindOfClass:[NSDictionary class]] && all[bundleID]) ? all[bundleID] : @{};
}
- (void)setScanCache:(NSDictionary *)cache forBundle:(NSString *)bundleID {
    NSMutableDictionary *all = [[self val:@"scanCacheByBundle"] mutableCopy] ?: [NSMutableDictionary dictionary];
    all[bundleID] = cache ?: @{};
    [self writeDict:@{ @"scanCacheByBundle": all }];
}
- (void)setEnabled:(BOOL)enabled forBundle:(NSString *)bundleID spoofVersion:(NSString *)version {
    NSMutableArray *ids = [[self enabledBundleIDs] mutableCopy] ?: [NSMutableArray array];
    if (enabled) { if (![ids containsObject:bundleID]) [ids addObject:bundleID]; }
    else { [ids removeObject:bundleID]; }
    NSMutableDictionary *map = [[self val:@"spoofVersionByBundle"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (enabled && version.length) map[bundleID] = version; else [map removeObjectForKey:bundleID];
    [self writeDict:@{ @"enabledBundleIDs": ids, @"spoofVersionByBundle": map }];
    [self postPrefsChanged];
}
- (void)setGlobalEnabled:(BOOL)enabled { [self writeDict:@{ @"globalEnabled": @(enabled) }]; [self postPrefsChanged]; }
- (void)setPatchMinimumOSOnDownload:(BOOL)enabled { [self writeDict:@{ @"patchMinimumOSOnDownload": @(enabled) }]; [self postPrefsChanged]; }
- (void)postPrefsChanged {
    notify_post([kSO17PrefsChangedNotification UTF8String]);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)kSO17PrefsChangedNotification, NULL, NULL, true);
}
@end

NSString *SO17CurrentProcessBundleID(void) { return [[NSBundle mainBundle] bundleIdentifier]; }

BOOL SO17IsInstallWhitelistProcess(NSString *bundleID, const char *progname) {
    if (progname && (!strcmp(progname, "installd") || !strcmp(progname, "installcoordinationd") || !strcmp(progname, "appstored") || !strcmp(progname, "itunesstored"))) return YES;
    return [bundleID isEqualToString:@"com.apple.AppStore"];
}

static BOOL SO17DeniedProg(const char *p) {
    if (!p) return YES;
    static const char *denied[] = { "SpringBoard", "backboardd", "Preferences", "ReportCrash", "launchd", NULL };
    for (int i = 0; denied[i]; i++) if (!strcmp(p, denied[i])) return YES;
    return NO;
}

BOOL SO17ShouldSpoofInCurrentProcess(void) {
    SO17Prefs *prefs = [SO17Prefs shared];
    if (!prefs.globalEnabled) return NO;
    extern const char *__progname;
    if (SO17DeniedProg(__progname)) return NO;
    NSString *bid = SO17CurrentProcessBundleID();
    if (SO17IsInstallWhitelistProcess(bid, __progname)) return YES;
    return [prefs isBundleEnabled:bid];
}

NSString *SO17EffectiveSpoofVersion(void) {
    SO17Prefs *prefs = [SO17Prefs shared];
    NSString *bid = SO17CurrentProcessBundleID();
    extern const char *__progname;
    if ([prefs isBundleEnabled:bid]) return [prefs spoofVersionForBundle:bid];
    if (SO17IsInstallWhitelistProcess(bid, __progname)) return [prefs defaultSpoofVersion];
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    return [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
}

NSOperatingSystemVersion SO17SpoofedOSVersion(void) {
    NSString *s = SO17EffectiveSpoofVersion();
    NSOperatingSystemVersion v = {0};
    NSArray *parts = [s componentsSeparatedByString:@"."];
    if (parts.count > 0) v.majorVersion = [parts[0] integerValue];
    if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
    if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
    return v;
}
