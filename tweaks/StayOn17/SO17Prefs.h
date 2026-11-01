#pragma once
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSString * const kSO17PrefsDomain;
extern NSString * const kSO17PrefsChangedNotification;

typedef NS_ENUM(NSInteger, SO17ScanVerdict) {
    SO17ScanVerdictLikelyOK = 0,
    SO17ScanVerdictSpoofOnly = 1,
    SO17ScanVerdictNotFeasible = 2
};

@interface SO17Prefs : NSObject
+ (instancetype)shared;
- (void)reload;
- (BOOL)globalEnabled;
- (BOOL)patchMinimumOSOnDownload;
- (BOOL)marketingVersionOnly;
- (NSArray<NSString *> *)enabledBundleIDs;
- (BOOL)isBundleEnabled:(NSString *)bundleID;
- (NSString *)spoofVersionForBundle:(NSString *)bundleID;
- (NSString *)defaultSpoofVersion;
- (NSDictionary *)scanCacheForBundle:(NSString *)bundleID;
- (void)setScanCache:(NSDictionary *)cache forBundle:(NSString *)bundleID;
- (void)setEnabled:(BOOL)enabled forBundle:(NSString *)bundleID spoofVersion:(NSString *)version;
- (void)setGlobalEnabled:(BOOL)enabled;
- (void)setPatchMinimumOSOnDownload:(BOOL)enabled;
- (void)postPrefsChanged;
- (id)valueForKey:(NSString *)key;
- (void)writeDict:(NSDictionary *)patch;
@end

BOOL SO17IsInstallWhitelistProcess(NSString *bundleID, const char *progname);
BOOL SO17ShouldSpoofInCurrentProcess(void);
NSString *SO17CurrentProcessBundleID(void);
NSString *SO17EffectiveSpoofVersion(void);
NSOperatingSystemVersion SO17SpoofedOSVersion(void);

#ifdef __cplusplus
}
#endif
