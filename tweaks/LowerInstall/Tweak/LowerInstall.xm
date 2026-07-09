// LowerInstall 1.3 — RootHide-safe store spoof that can finish installs
//
// Symptom (1.2.1): update starts downloading then snaps back to Update.
// Cause: App Store queues the update, then installd / AMS re-checks real OS
// and aborts. UA-only spoof is not enough; Gestalt + installd must agree.
//
// 1.3:
//  - Logos %hookf MGCopyAnswer (more reliable on ElleKit than raw MSHookFunction)
//  - Spoof version tokens inside HTTP bodies (AMS JSON)
//  - Broader installd / installable hooks for mid-install rejection
//  - Target installcoordinationd as well
//  - Still hard-deny SpringBoard (no Safe Mode)

#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <notify.h>
#import <string.h>
#import <dlfcn.h>
#import <os/log.h>

extern const char *__progname;

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_DOMAIN "com.julioverne.lowerinstall"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"
#define DEFAULT_SPOOF_VERSION @"18.5"

static BOOL gEnabled = YES;
static NSString *gSpoofDevice = nil;
static NSString *gSpoofVersion = nil;
static NSString *gCurrentDevice = nil;
static NSString *gCurrentVersion = nil;

static os_log_t LILog(void) {
	static os_log_t log;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ log = os_log_create("com.chasedavis.lowerinstall", "spoof"); });
	return log;
}

#pragma mark - Process gate

static BOOL LIIsDeniedProcess(const char *prog) {
	if (!prog || !prog[0]) return YES;
	static const char *denied[] = {
		"SpringBoard", "backboardd", "UserEventAgent", "Preferences",
		"preferencebundled", "ReportCrash", "mediaserverd", "runningboardd",
		"launchd", "cfprefsd", "logd", NULL
	};
	for (int i = 0; denied[i]; i++) {
		if (strcmp(prog, denied[i]) == 0) return YES;
	}
	return NO;
}

static BOOL LIIsInstalld(const char *p) { return p && strcmp(p, "installd") == 0; }
static BOOL LIIsInstallCoord(const char *p) { return p && strcmp(p, "installcoordinationd") == 0; }
static BOOL LIIsStore(const char *p) {
	return p && (strcmp(p, "appstored") == 0 || strcmp(p, "itunesstored") == 0 || strcmp(p, "AppStore") == 0);
}
static BOOL LIIsAllowed(const char *p) {
	return LIIsInstalld(p) || LIIsInstallCoord(p) || LIIsStore(p);
}

#pragma mark - Prefs / version helpers

static NSString *LICurrentOSVersion(void) {
	NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
	if (v.majorVersion == 0) return @"17.0";
	if (v.patchVersion > 0)
		return [NSString stringWithFormat:@"%ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
	return [NSString stringWithFormat:@"%ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
}

static NSString *LICurrentMachine(void) {
	struct utsname info;
	uname(&info);
	return [NSString stringWithUTF8String:info.machine] ?: @"iPhone15,2";
}

static id LIPrefObject(NSString *key) {
	CFPropertyListRef cf = CFPreferencesCopyAppValue((__bridge CFStringRef)key, CFSTR(PREFS_DOMAIN));
	if (cf) return CFBridgingRelease(cf);
	return [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH][key];
}

static void LILoadPrefs(void) {
	@autoreleasepool {
		id en = LIPrefObject(@"Enabled");
		gEnabled = (en == nil) ? YES : [en boolValue];

		NSString *dev = LIPrefObject(@"SpoofDevice");
		gSpoofDevice = ([dev isKindOfClass:[NSString class]] && dev.length) ? [dev copy] : [gCurrentDevice copy];

		NSString *ver = LIPrefObject(@"SpoofVersion");
		if ([ver isKindOfClass:[NSString class]] && ver.length) {
			if ((gCurrentVersion && [ver isEqualToString:gCurrentVersion]) ||
				[ver compare:@"18.0" options:NSNumericSearch] == NSOrderedAscending) {
				gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
			} else {
				gSpoofVersion = [ver copy];
			}
		} else {
			gSpoofVersion = [DEFAULT_SPOOF_VERSION copy];
		}
	}
}

static void LIPrefsCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
	LILoadPrefs();
}

static NSString *LISpoof(void) {
	if (!gEnabled) return gCurrentVersion ?: @"17.0";
	NSString *v = gSpoofVersion.length ? gSpoofVersion : DEFAULT_SPOOF_VERSION;
	if ([v rangeOfString:@"."].location == NSNotFound) v = [v stringByAppendingString:@".0"];
	return v;
}

/// Replace every occurrence of the real OS version string with spoof in free text / JSON / UA.
static NSString *LIRewriteVersionTokens(NSString *value) {
	if (!value.length || !gEnabled) return value;
	NSString *spoof = LISpoof();
	NSString *real = gCurrentVersion ?: LICurrentOSVersion();
	NSMutableString *out = [value mutableCopy];

	// Direct real → spoof
	if (real.length) {
		[out replaceOccurrencesOfString:real withString:spoof options:0 range:NSMakeRange(0, out.length)];
		// underscored form 17_0_3
		NSString *realU = [real stringByReplacingOccurrencesOfString:@"." withString:@"_"];
		NSString *spoofU = [spoof stringByReplacingOccurrencesOfString:@"." withString:@"_"];
		[out replaceOccurrencesOfString:realU withString:spoofU options:0 range:NSMakeRange(0, out.length)];
	}

	// Canonical patterns even if real string differs slightly (17.0 vs 17.0.0)
	NSString *under = [spoof stringByReplacingOccurrencesOfString:@"." withString:@"_"];
	NSArray *patterns = @[
		@"iOS/[0-9]+(?:\\.[0-9]+){0,3}",
		@"CPU (?:iPhone )?OS [0-9]+(?:_[0-9]+){0,3}",
		@"iPhone OS [0-9]+(?:_[0-9]+){0,3}",
		@"Version/[0-9]+(?:\\.[0-9]+){0,3}",
		@"\"softwareVersionString\"\\s*:\\s*\"[^\"]+\"",
		@"\"device-software-version\"\\s*:\\s*\"[^\"]+\"",
		@"\"ProductVersion\"\\s*:\\s*\"[^\"]+\"",
		@"\"os-version\"\\s*:\\s*\"[^\"]+\"",
		@"\"platform-version\"\\s*:\\s*\"[^\"]+\"",
	];
	NSArray *reps = @[
		[NSString stringWithFormat:@"iOS/%@", spoof],
		[NSString stringWithFormat:@"CPU iPhone OS %@", under],
		[NSString stringWithFormat:@"iPhone OS %@", under],
		[NSString stringWithFormat:@"Version/%@", spoof],
		[NSString stringWithFormat:@"\"softwareVersionString\":\"%@\"", spoof],
		[NSString stringWithFormat:@"\"device-software-version\":\"%@\"", spoof],
		[NSString stringWithFormat:@"\"ProductVersion\":\"%@\"", spoof],
		[NSString stringWithFormat:@"\"os-version\":\"%@\"", spoof],
		[NSString stringWithFormat:@"\"platform-version\":\"%@\"", spoof],
	];
	for (NSUInteger i = 0; i < patterns.count; i++) {
		NSError *err = nil;
		NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:patterns[i] options:0 error:&err];
		if (!re) continue;
		[re replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:reps[i]];
	}

	if (gCurrentDevice.length && gSpoofDevice.length && ![gCurrentDevice isEqualToString:gSpoofDevice]) {
		[out replaceOccurrencesOfString:gCurrentDevice withString:gSpoofDevice options:0 range:NSMakeRange(0, out.length)];
	}
	return [out copy];
}

static NSData *LIRewriteBodyData(NSData *data) {
	if (!gEnabled || data.length == 0 || data.length > 2 * 1024 * 1024) return data; // skip huge
	// Only rewrite if looks like text/json
	const uint8_t *b = (const uint8_t *)data.bytes;
	if (b[0] != '{' && b[0] != '[' && b[0] != '<' && !(b[0] >= 0x20 && b[0] < 0x7f)) return data;
	NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!s) return data;
	NSString *out = LIRewriteVersionTokens(s);
	if ([out isEqualToString:s]) return data;
	return [out dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - MGCopyAnswer via Logos hookf

// Declared for %hookf — linked from libMobileGestalt (C ABI)
#ifdef __cplusplus
extern "C" {
#endif
CFTypeRef MGCopyAnswer(CFStringRef key);
#ifdef __cplusplus
}
#endif

%group GestaltHooks

%hookf(CFTypeRef, MGCopyAnswer, CFStringRef key) {
	if (gEnabled && key) {
		if (CFEqual(key, CFSTR("ProductVersion")) || CFEqual(key, CFSTR("ProductVersionExtra"))) {
			NSString *v = LISpoof();
			return CFStringCreateWithCString(kCFAllocatorDefault, v.UTF8String, kCFStringEncodingUTF8);
		}
	}
	return %orig;
}

%end

#pragma mark - UIDevice

static NSString *(*orig_uiSysVer)(id, SEL) = NULL;
static NSString *hook_uiSysVer(id self, SEL _cmd) {
	if (gEnabled) return LISpoof();
	return orig_uiSysVer ? orig_uiSysVer(self, _cmd) : LICurrentOSVersion();
}

static void LITryHook(Class cls, SEL sel, IMP neu, IMP *orig) {
	if (!cls || !class_getInstanceMethod(cls, sel)) return;
	MSHookMessageEx(cls, sel, neu, orig);
}

static void LIHookUIDevice(void) {
	Class c = objc_getClass("UIDevice");
	if (c) LITryHook(c, @selector(systemVersion), (IMP)hook_uiSysVer, (IMP *)&orig_uiSysVer);
}

#pragma mark - installd / installcoordination soft hooks

#define LI_BOOL0(name) \
static BOOL (*orig_##name)(id, SEL) = NULL; \
static BOOL hook_##name(id self, SEL _cmd) { \
	if (gEnabled) return YES; \
	return orig_##name ? orig_##name(self, _cmd) : YES; \
}

#define LI_BOOL_ERR(name) \
static BOOL (*orig_##name)(id, SEL, NSError **) = NULL; \
static BOOL hook_##name(id self, SEL _cmd, NSError **e) { \
	if (gEnabled) { if (e) *e = nil; return YES; } \
	return orig_##name ? orig_##name(self, _cmd, e) : YES; \
}

LI_BOOL0(skipFam)
LI_BOOL0(skipThin)
LI_BOOL_ERR(famErr)
LI_BOOL_ERR(osErr)
LI_BOOL_ERR(capErr)
LI_BOOL_ERR(thinErr)
LI_BOOL_ERR(valApp)
LI_BOOL_ERR(valPlug)
LI_BOOL_ERR(devErr)
LI_BOOL_ERR(verifyMeta)
LI_BOOL_ERR(verifySub)
LI_BOOL_ERR(installErr)
LI_BOOL_ERR(launchErr)

static NSString *(*orig_minOS)(id, SEL) = NULL;
static NSString *hook_minOS(id self, SEL _cmd) {
	if (gEnabled) return @"2.0";
	return orig_minOS ? orig_minOS(self, _cmd) : @"2.0";
}

static NSArray *(*orig_devices)(id, SEL) = NULL;
static NSArray *hook_devices(id self, SEL _cmd) {
	NSArray *ret = orig_devices ? orig_devices(self, _cmd) : @[];
	if (!gEnabled) return ret;
	NSString *machine = gCurrentDevice ?: LICurrentMachine();
	if (machine && ![ret containsObject:machine]) {
		NSMutableArray *mut = [ret mutableCopy] ?: [NSMutableArray array];
		[mut addObject:machine];
		return [mut copy];
	}
	return ret;
}

static BOOL (*orig_osVerErr)(id, SEL, id, NSError **) = NULL;
static BOOL hook_osVerErr(id self, SEL _cmd, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_osVerErr ? orig_osVerErr(self, _cmd, a, e) : YES;
}

static BOOL (*orig_compatFam)(id, SEL, int) = NULL;
static BOOL hook_compatFam(id self, SEL _cmd, int f) {
	if (gEnabled) return YES;
	return orig_compatFam ? orig_compatFam(self, _cmd, f) : YES;
}

static void LIInstallInstalldHooks(void) {
	Class miBundle = objc_getClass("MIBundle");
	Class miInstallable = objc_getClass("MIInstallableBundle");
	Class miCfg = objc_getClass("MIDaemonConfiguration");
	Class miInstaller = objc_getClass("MIInstaller");
	Class miClient = objc_getClass("MIClientConnection");

	if (miCfg) {
		LITryHook(miCfg, @selector(skipDeviceFamilyCheck), (IMP)hook_skipFam, (IMP *)&orig_skipFam);
		LITryHook(miCfg, @selector(skipThinningCheck), (IMP)hook_skipThin, (IMP *)&orig_skipThin);
	}
	if (miBundle) {
		LITryHook(miBundle, @selector(minimumOSVersion), (IMP)hook_minOS, (IMP *)&orig_minOS);
		LITryHook(miBundle, @selector(supportedDevices), (IMP)hook_devices, (IMP *)&orig_devices);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceFamilyWithError:), (IMP)hook_famErr, (IMP *)&orig_famErr);
		LITryHook(miBundle, @selector(isApplicableToCurrentOSVersionWithError:), (IMP)hook_osErr, (IMP *)&orig_osErr);
		LITryHook(miBundle, @selector(isApplicableToOSVersion:error:), (IMP)hook_osVerErr, (IMP *)&orig_osVerErr);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceCapabilitiesWithError:), (IMP)hook_capErr, (IMP *)&orig_capErr);
		LITryHook(miBundle, @selector(thinningMatchesCurrentDeviceWithError:), (IMP)hook_thinErr, (IMP *)&orig_thinErr);
		LITryHook(miBundle, @selector(validateAppMetadataWithError:), (IMP)hook_valApp, (IMP *)&orig_valApp);
		LITryHook(miBundle, @selector(validatePluginMetadataWithError:), (IMP)hook_valPlug, (IMP *)&orig_valPlug);
		LITryHook(miBundle, @selector(isApplicableToCurrentDeviceWithError:), (IMP)hook_devErr, (IMP *)&orig_devErr);
		LITryHook(miBundle, @selector(isCompatibleWithDeviceFamily:), (IMP)hook_compatFam, (IMP *)&orig_compatFam);
	}
	if (miInstallable) {
		// Only bypass *validation* — never skip the real performInstallation (would brick the update flow)
		LITryHook(miInstallable, @selector(_verifyBundleMetadataWithError:), (IMP)hook_verifyMeta, (IMP *)&orig_verifyMeta);
		LITryHook(miInstallable, @selector(_verifySubBundleMetadataWithError:), (IMP)hook_verifySub, (IMP *)&orig_verifySub);
	}
	(void)miInstaller;
	(void)miClient;
	(void)hook_installErr;
	(void)hook_launchErr;
	os_log(LILog(), "installd hooks miBundle=%d miInstallable=%d", miBundle != nil, miInstallable != nil);
}

#pragma mark - Store request hooks

%group StoreHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LIRewriteVersionTokens(value);
	}
	%orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
		value = LIRewriteVersionTokens(value);
	}
	%orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary *)headerFields {
	if (gEnabled && headerFields.count) {
		NSMutableDictionary *mut = [headerFields mutableCopy];
		for (NSString *key in headerFields) {
			if ([key caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
				id v = headerFields[key];
				if ([v isKindOfClass:[NSString class]]) mut[key] = LIRewriteVersionTokens(v);
			}
		}
		headerFields = mut;
	}
	%orig(headerFields);
}

- (void)setHTTPBody:(NSData *)data {
	if (gEnabled && data.length) data = LIRewriteBodyData(data);
	%orig(data);
}

%end

// NSString formatting of version in AMS blobs sometimes goes through stringByAppending*
// Catch dictionary serialization used for request bodies
%hook NSJSONSerialization

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
	NSData *data = %orig;
	if (gEnabled && data.length) {
		NSData *rewritten = LIRewriteBodyData(data);
		if (rewritten != data) return rewritten;
	}
	return data;
}

%end

%end

#pragma mark - ctor

%ctor {
	@autoreleasepool {
		const char *prog = __progname ?: "";

		if (LIIsDeniedProcess(prog)) return;
		if (!LIIsAllowed(prog)) return;

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

		os_log(LILog(), "1.3 active in %{public}s spoof=%{public}@ real=%{public}@", prog, LISpoof(), gCurrentVersion);

		// Gestalt for anyone allowed (store + installd + installcoordinationd)
		%init(GestaltHooks);

		if (LIIsInstalld(prog) || LIIsInstallCoord(prog)) {
			LIInstallInstalldHooks();
			return;
		}

		if (LIIsStore(prog)) {
			LIHookUIDevice();
			%init(StoreHooks);
			return;
		}
	}
}
