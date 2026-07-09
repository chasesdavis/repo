// LowerInstall — rootless / roothide port for iOS 15–17
// Original: julioverne — https://github.com/julioverne/LowerInstall
//
// 1) installd  — relax MI* bundle compatibility / thinning / family checks
// 2) appstored / itunesstored — spoof User-Agent iOS version + machine

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <notify.h>
#import <string.h>

extern const char *__progname;

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"

static BOOL gEnabled = YES;
static NSString *gSpoofDevice = nil;
static NSString *gSpoofVersion = nil;
static NSString *gCurrentDevice = nil;
static NSString *gCurrentVersion = nil;

static NSString *LICurrentOSVersion(void) {
	NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
	if (v.majorVersion == 0) {
		return [[UIDevice currentDevice] systemVersion] ?: @"17.0";
	}
	if (v.patchVersion > 0) {
		return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
	}
	return [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
}

static NSString *LICurrentMachine(void) {
	struct utsname info;
	uname(&info);
	return [NSString stringWithUTF8String:info.machine] ?: @"iPhone";
}

static void LILoadPrefs(void) {
	@autoreleasepool {
		NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH] ?: @{};
		id en = prefs[@"Enabled"];
		gEnabled = (en == nil) ? YES : [en boolValue];

		NSString *dev = prefs[@"SpoofDevice"];
		gSpoofDevice = ([dev isKindOfClass:[NSString class]] && dev.length) ? [dev copy] : [gCurrentDevice copy];

		NSString *ver = prefs[@"SpoofVersion"];
		gSpoofVersion = ([ver isKindOfClass:[NSString class]] && ver.length) ? [ver copy] : [gCurrentVersion copy];
	}
}

static void LIPrefsCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	LILoadPrefs();
}

static BOOL LIForceYesErr(BOOL (*orig)(id, SEL, NSError **), id self, SEL _cmd, NSError **error) {
	if (gEnabled) {
		if (error) *error = nil;
		return YES;
	}
	return orig ? orig(self, _cmd, error) : YES;
}

// Soft-hook helper: swap instance method if present
static void LIHookBool(Class cls, SEL sel, IMP newImp, IMP *outOrig) {
	if (!cls) return;
	Method m = class_getInstanceMethod(cls, sel);
	if (!m) return;
	if (outOrig) *outOrig = method_getImplementation(m);
	method_setImplementation(m, newImp);
}

#pragma mark - Store UA spoof

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		if (gCurrentVersion.length && [value containsString:gCurrentVersion]) {
			NSString *fromVer = [NSString stringWithFormat:@"/%@ ", gCurrentVersion];
			NSString *toVer = [NSString stringWithFormat:@"/%@ ", gSpoofVersion ?: gCurrentVersion];
			value = [value stringByReplacingOccurrencesOfString:fromVer withString:toVer];
		}
		if (gCurrentDevice.length && [value containsString:gCurrentDevice]) {
			NSString *fromDev = [NSString stringWithFormat:@"/%@ ", gCurrentDevice];
			NSString *toDev = [NSString stringWithFormat:@"/%@ ", gSpoofDevice ?: gCurrentDevice];
			value = [value stringByReplacingOccurrencesOfString:fromDev withString:toDev];
		}
	}
	%orig(value, field);
}

%end

%end

#pragma mark - installd

%group InstalldHooks

%hook MIDaemonConfiguration

- (BOOL)skipDeviceFamilyCheck {
	return gEnabled ? YES : %orig;
}

- (BOOL)skipThinningCheck {
	return gEnabled ? YES : %orig;
}

%end

%hook MIBundle

- (NSString *)minimumOSVersion {
	NSString *ret = %orig;
	return gEnabled ? @"2.0" : ret;
}

- (NSArray *)supportedDevices {
	NSArray *ret = %orig ?: @[];
	if (!gEnabled) return ret;
	NSString *machine = gCurrentDevice ?: LICurrentMachine();
	if (machine && ![ret containsObject:machine]) {
		NSMutableArray *mut = [ret mutableCopy];
		[mut addObject:machine];
		return [mut copy];
	}
	return ret;
}

- (BOOL)isCompatibleWithDeviceFamily:(int)device {
	return gEnabled ? YES : %orig;
}

- (BOOL)isApplicableToCurrentDeviceFamilyWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)isApplicableToCurrentOSVersionWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)isApplicableToOSVersion:(id)arg1 error:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)isApplicableToCurrentDeviceCapabilitiesWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)thinningMatchesCurrentDeviceWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)validateAppMetadataWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)validatePluginMetadataWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

%end

%hook MIInstallableBundle

- (BOOL)_validateApplicationIdentifierForNewBundleSigningInfo:(id)arg1 error:(NSError **)arg2 {
	if (gEnabled) { if (arg2) *arg2 = nil; return YES; }
	return %orig;
}

- (BOOL)_verifyBundleMetadataWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)_verifySubBundleMetadataWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

- (BOOL)_isValidWatchKitApp:(id)arg1 withVersion:(id)arg2 installableSigningInfo:(id)arg3 error:(NSError **)arg4 {
	if (gEnabled) { if (arg4) *arg4 = nil; return YES; }
	return %orig;
}

%end

%hook MIExecutableBundle

- (BOOL)hasOnlyAllowedWatchKitAppInfoPlistKeysForWatchKitVersion:(id)arg1 error:(NSError **)arg2 {
	if (gEnabled) { if (arg2) *arg2 = nil; return YES; }
	return %orig;
}

%end

%hook MIPluginKitPluginBundle

- (BOOL)validateBundleMetadataWithError:(NSError **)error {
	if (gEnabled) { if (error) *error = nil; return YES; }
	return %orig;
}

%end

%end

// Soft-hook extra selectors that differ across iOS 15–17 (no hard link if missing)
static BOOL (*orig_isApplicableToCurrentDeviceWithError)(id, SEL, NSError **) = NULL;
static BOOL hook_isApplicableToCurrentDeviceWithError(id self, SEL _cmd, NSError **error) {
	return LIForceYesErr(orig_isApplicableToCurrentDeviceWithError, self, _cmd, error);
}

static BOOL (*orig_isCompatibleWithCurrentDeviceFamilyWithError)(id, SEL, NSError **) = NULL;
static BOOL hook_isCompatibleWithCurrentDeviceFamilyWithError(id self, SEL _cmd, NSError **error) {
	return LIForceYesErr(orig_isCompatibleWithCurrentDeviceFamilyWithError, self, _cmd, error);
}

static void LISoftHookInstalldExtras(void) {
	Class miBundle = objc_getClass("MIBundle");
	LIHookBool(miBundle, @selector(isApplicableToCurrentDeviceWithError:), (IMP)hook_isApplicableToCurrentDeviceWithError, (IMP *)&orig_isApplicableToCurrentDeviceWithError);
	LIHookBool(miBundle, @selector(isCompatibleWithCurrentDeviceFamilyWithError:), (IMP)hook_isCompatibleWithCurrentDeviceFamilyWithError, (IMP *)&orig_isCompatibleWithCurrentDeviceFamilyWithError);
}

%ctor {
	@autoreleasepool {
		gCurrentDevice = [LICurrentMachine() copy];
		gCurrentVersion = [LICurrentOSVersion() copy];
		LILoadPrefs();

		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			LIPrefsCallback,
			CFSTR(PREFS_CHANGED),
			NULL,
			CFNotificationSuspensionBehaviorCoalesce
		);

		const char *prog = __progname ?: "";
		if (strcmp(prog, "installd") == 0) {
			%init(InstalldHooks);
			LISoftHookInstalldExtras();
		} else {
			// appstored, itunesstored, App Store app process
			%init(StoreHooks);
		}
	}
}
