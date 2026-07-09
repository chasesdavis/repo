// LowerInstall 1.4 — RootHide-safe
//
// Download starts then snaps back = appstored queued the job, then installd
// (or AMS) rejected the payload against the REAL iOS version.
//
// 1.4 adds:
//  - installd: force MinimumOSVersion via NSBundle + MIBundle
//  - Logos %hookf MGCopyAnswer (ProductVersion) for store/installd
//  - AMS UA + JSON body rewrite
//  - Injection breadcrumb files so we can see if daemons actually loaded us
//  - Default spoof 99.0.0 (same idea as AppStoreTroller)
//  - Hard deny SpringBoard (no Safe Mode)

#import <Foundation/Foundation.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <sys/utsname.h>
#import <notify.h>
#import <string.h>
#import <dlfcn.h>
#import <os/log.h>
#import <unistd.h>

extern const char *__progname;

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_DOMAIN "com.julioverne.lowerinstall"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"
#define DEFAULT_SPOOF_VERSION @"99.0.0"
#define BREADCRUMB_DIR @"/var/mobile/Library/Logs/LowerInstall"

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

static BOOL LIIsDenied(const char *p) {
	if (!p || !p[0]) return YES;
	static const char *denied[] = {
		"SpringBoard", "backboardd", "UserEventAgent", "Preferences",
		"preferencebundled", "ReportCrash", "mediaserverd", "runningboardd",
		"launchd", "cfprefsd", "logd", "CommCenter", NULL
	};
	for (int i = 0; denied[i]; i++) if (strcmp(p, denied[i]) == 0) return YES;
	return NO;
}

static BOOL LIIsInstalld(const char *p) {
	return p && (strcmp(p, "installd") == 0 || strcmp(p, "installcoordinationd") == 0);
}
static BOOL LIIsStore(const char *p) {
	return p && (strcmp(p, "appstored") == 0 || strcmp(p, "itunesstored") == 0 || strcmp(p, "AppStore") == 0);
}
static BOOL LIIsAllowed(const char *p) { return LIIsInstalld(p) || LIIsStore(p); }

static void LIWriteBreadcrumb(const char *prog, NSString *detail) {
	@autoreleasepool {
		[[NSFileManager defaultManager] createDirectoryAtPath:BREADCRUMB_DIR withIntermediateDirectories:YES attributes:nil error:nil];
		NSString *path = [NSString stringWithFormat:@"%@/%s.loaded", BREADCRUMB_DIR, prog ?: "unknown"];
		NSString *body = [NSString stringWithFormat:@"pid=%d\nprog=%s\nenabled=%d\nspoof=%@\nreal=%@\ndetail=%@\nts=%@\n",
			getpid(), prog ?: "?", gEnabled, gSpoofVersion ?: @"?", gCurrentVersion ?: @"?", detail ?: @"",
			[NSDate date].description];
		[body writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
		// Also a combined status for Settings/Filza
		NSString *status = [NSString stringWithFormat:@"%@/%@.txt", BREADCRUMB_DIR, @"status"];
		NSString *line = [NSString stringWithFormat:@"%@ loaded into %s (spoof %@)\n", [NSDate date], prog ?: "?", gSpoofVersion ?: @"?"];
		NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:status];
		if (!fh) {
			[line writeToFile:status atomically:YES encoding:NSUTF8StringEncoding error:nil];
		} else {
			[fh seekToEndOfFile];
			[fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
			[fh closeFile];
		}
	}
}

#pragma mark - Prefs

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
			// Auto-upgrade weak spoofs that match real OS or are < 18
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

static BOOL LIIsMinOSKey(id key) {
	if (![key isKindOfClass:[NSString class]]) return NO;
	NSString *k = key;
	return [k isEqualToString:@"MinimumOSVersion"]
		|| [k isEqualToString:@"LSMinimumSystemVersion"]
		|| [k isEqualToString:@"MinimumOSVersionString"];
}

#pragma mark - Version string rewrite (UA / JSON)

static NSString *LIRewrite(NSString *value) {
	if (!value.length || !gEnabled) return value;
	NSString *spoof = LISpoof();
	NSString *real = gCurrentVersion ?: LICurrentOSVersion();
	NSMutableString *out = [value mutableCopy];
	if (real.length) {
		[out replaceOccurrencesOfString:real withString:spoof options:0 range:NSMakeRange(0, out.length)];
		[out replaceOccurrencesOfString:[real stringByReplacingOccurrencesOfString:@"." withString:@"_"]
							withString:[spoof stringByReplacingOccurrencesOfString:@"." withString:@"_"]
							   options:0 range:NSMakeRange(0, out.length)];
	}
	NSString *under = [spoof stringByReplacingOccurrencesOfString:@"." withString:@"_"];
	NSArray *pats = @[
		@"iOS/[0-9]+(?:\\.[0-9]+){0,3}",
		@"CPU (?:iPhone )?OS [0-9]+(?:_[0-9]+){0,3}",
		@"iPhone OS [0-9]+(?:_[0-9]+){0,3}",
		@"Version/[0-9]+(?:\\.[0-9]+){0,3}",
		@"\"softwareVersionString\"\\s*:\\s*\"[^\"]+\"",
		@"\"device-software-version\"\\s*:\\s*\"[^\"]+\"",
		@"\"ProductVersion\"\\s*:\\s*\"[^\"]+\"",
		@"\"os-version\"\\s*:\\s*\"[^\"]+\"",
		@"\"platform-version\"\\s*:\\s*\"[^\"]+\"",
		@"\"client-os-version\"\\s*:\\s*\"[^\"]+\"",
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
		[NSString stringWithFormat:@"\"client-os-version\":\"%@\"", spoof],
	];
	for (NSUInteger i = 0; i < pats.count; i++) {
		NSError *e = nil;
		NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pats[i] options:0 error:&e];
		if (re) [re replaceMatchesInString:out options:0 range:NSMakeRange(0, out.length) withTemplate:reps[i]];
	}
	if (gCurrentDevice.length && gSpoofDevice.length && ![gCurrentDevice isEqualToString:gSpoofDevice]) {
		[out replaceOccurrencesOfString:gCurrentDevice withString:gSpoofDevice options:0 range:NSMakeRange(0, out.length)];
	}
	return [out copy];
}

static NSData *LIRewriteData(NSData *data) {
	if (!gEnabled || data.length == 0 || data.length > 2*1024*1024) return data;
	const uint8_t *b = (const uint8_t *)data.bytes;
	if (b[0] != '{' && b[0] != '[' && !(b[0] >= 0x20 && b[0] < 0x7f)) return data;
	NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!s) return data;
	NSString *o = LIRewrite(s);
	if ([o isEqualToString:s]) return data;
	return [o dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Gestalt

#ifdef __cplusplus
extern "C" {
#endif
CFTypeRef MGCopyAnswer(CFStringRef key);
#ifdef __cplusplus
}
#endif

%group GestaltHooks
%hookf(CFTypeRef, MGCopyAnswer, CFStringRef key) {
	if (gEnabled && key && (CFEqual(key, CFSTR("ProductVersion")) || CFEqual(key, CFSTR("ProductVersionExtra")))) {
		NSString *v = LISpoof();
		return CFStringCreateWithCString(kCFAllocatorDefault, v.UTF8String, kCFStringEncodingUTF8);
	}
	return %orig;
}
%end

#pragma mark - UIDevice

static NSString *(*orig_ui)(id, SEL) = NULL;
static NSString *hook_ui(id self, SEL _cmd) {
	return gEnabled ? LISpoof() : (orig_ui ? orig_ui(self, _cmd) : LICurrentOSVersion());
}
static void LITryHook(Class c, SEL s, IMP n, IMP *o) {
	if (c && class_getInstanceMethod(c, s)) MSHookMessageEx(c, s, n, o);
}

#pragma mark - installd: MI* + NSBundle MinimumOSVersion

static NSString *(*orig_minOS)(id, SEL) = NULL;
static NSString *hook_minOS(id self, SEL _cmd) {
	return gEnabled ? @"2.0" : (orig_minOS ? orig_minOS(self, _cmd) : @"2.0");
}

static NSArray *(*orig_devs)(id, SEL) = NULL;
static NSArray *hook_devs(id self, SEL _cmd) {
	NSArray *ret = orig_devs ? orig_devs(self, _cmd) : @[];
	if (!gEnabled) return ret;
	NSString *m = gCurrentDevice ?: LICurrentMachine();
	if (m && ![ret containsObject:m]) {
		NSMutableArray *a = [ret mutableCopy] ?: [NSMutableArray array];
		[a addObject:m];
		return a;
	}
	return ret;
}

#define LI_YES_ERR(n) \
static BOOL (*orig_##n)(id, SEL, NSError **) = NULL; \
static BOOL hook_##n(id self, SEL _cmd, NSError **e) { \
	if (gEnabled) { if (e) *e = nil; return YES; } \
	return orig_##n ? orig_##n(self, _cmd, e) : YES; \
}
LI_YES_ERR(famErr) LI_YES_ERR(osErr) LI_YES_ERR(capErr) LI_YES_ERR(thinErr)
LI_YES_ERR(valApp) LI_YES_ERR(valPlug) LI_YES_ERR(devErr) LI_YES_ERR(vMeta) LI_YES_ERR(vSub)

static BOOL (*orig_osVer)(id, SEL, id, NSError **) = NULL;
static BOOL hook_osVer(id s, SEL c, id a, NSError **e) {
	if (gEnabled) { if (e) *e = nil; return YES; }
	return orig_osVer ? orig_osVer(s, c, a, e) : YES;
}
static BOOL (*orig_fam)(id, SEL, int) = NULL;
static BOOL hook_fam(id s, SEL c, int f) { return gEnabled ? YES : (orig_fam ? orig_fam(s, c, f) : YES); }
static BOOL (*orig_skipF)(id, SEL) = NULL;
static BOOL hook_skipF(id s, SEL c) { return gEnabled ? YES : (orig_skipF ? orig_skipF(s, c) : NO); }
static BOOL (*orig_skipT)(id, SEL) = NULL;
static BOOL hook_skipT(id s, SEL c) { return gEnabled ? YES : (orig_skipT ? orig_skipT(s, c) : NO); }

// NSBundle Info.plist reads (installd path)
static id (*orig_bundleInfo)(id, SEL, NSString *) = NULL;
static id hook_bundleInfo(id self, SEL _cmd, NSString *key) {
	if (gEnabled && LIIsMinOSKey(key)) return @"2.0";
	return orig_bundleInfo ? orig_bundleInfo(self, _cmd, key) : nil;
}

// NSDictionary path — installd reads Info.plist into dicts; key-scoped only
static id (*orig_dictKey)(id, SEL, id) = NULL;
static id hook_dictKey(id self, SEL _cmd, id key) {
	id r = orig_dictKey ? orig_dictKey(self, _cmd, key) : nil;
	if (gEnabled && LIIsMinOSKey(key) && r != nil) return @"2.0";
	return r;
}
static id (*orig_mdictKey)(id, SEL, id) = NULL;
static id hook_mdictKey(id self, SEL _cmd, id key) {
	id r = orig_mdictKey ? orig_mdictKey(self, _cmd, key) : nil;
	if (gEnabled && LIIsMinOSKey(key) && r != nil) return @"2.0";
	return r;
}

static void LIInstallInstalldHooks(void) {
	Class miB = objc_getClass("MIBundle");
	Class miI = objc_getClass("MIInstallableBundle");
	Class miC = objc_getClass("MIDaemonConfiguration");
	Class nsb = objc_getClass("NSBundle");
	Class nsd = objc_getClass("NSDictionary");
	Class nsm = objc_getClass("NSMutableDictionary");

	if (miC) {
		LITryHook(miC, @selector(skipDeviceFamilyCheck), (IMP)hook_skipF, (IMP *)&orig_skipF);
		LITryHook(miC, @selector(skipThinningCheck), (IMP)hook_skipT, (IMP *)&orig_skipT);
	}
	if (miB) {
		LITryHook(miB, @selector(minimumOSVersion), (IMP)hook_minOS, (IMP *)&orig_minOS);
		LITryHook(miB, @selector(supportedDevices), (IMP)hook_devs, (IMP *)&orig_devs);
		LITryHook(miB, @selector(isApplicableToCurrentDeviceFamilyWithError:), (IMP)hook_famErr, (IMP *)&orig_famErr);
		LITryHook(miB, @selector(isApplicableToCurrentOSVersionWithError:), (IMP)hook_osErr, (IMP *)&orig_osErr);
		LITryHook(miB, @selector(isApplicableToOSVersion:error:), (IMP)hook_osVer, (IMP *)&orig_osVer);
		LITryHook(miB, @selector(isApplicableToCurrentDeviceCapabilitiesWithError:), (IMP)hook_capErr, (IMP *)&orig_capErr);
		LITryHook(miB, @selector(thinningMatchesCurrentDeviceWithError:), (IMP)hook_thinErr, (IMP *)&orig_thinErr);
		LITryHook(miB, @selector(validateAppMetadataWithError:), (IMP)hook_valApp, (IMP *)&orig_valApp);
		LITryHook(miB, @selector(validatePluginMetadataWithError:), (IMP)hook_valPlug, (IMP *)&orig_valPlug);
		LITryHook(miB, @selector(isApplicableToCurrentDeviceWithError:), (IMP)hook_devErr, (IMP *)&orig_devErr);
		LITryHook(miB, @selector(isCompatibleWithDeviceFamily:), (IMP)hook_fam, (IMP *)&orig_fam);
	}
	if (miI) {
		LITryHook(miI, @selector(_verifyBundleMetadataWithError:), (IMP)hook_vMeta, (IMP *)&orig_vMeta);
		LITryHook(miI, @selector(_verifySubBundleMetadataWithError:), (IMP)hook_vSub, (IMP *)&orig_vSub);
	}
	// Critical: Info.plist MinimumOSVersion readers inside installd only
	if (nsb) LITryHook(nsb, @selector(objectForInfoDictionaryKey:), (IMP)hook_bundleInfo, (IMP *)&orig_bundleInfo);
	if (nsd) LITryHook(nsd, @selector(objectForKey:), (IMP)hook_dictKey, (IMP *)&orig_dictKey);
	if (nsm && nsm != nsd) LITryHook(nsm, @selector(objectForKey:), (IMP)hook_mdictKey, (IMP *)&orig_mdictKey);

	os_log(LILog(), "installd hooks ready miBundle=%d", miB != nil);
}

#pragma mark - Store hooks

%group StoreHooks

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame)
		value = LIRewrite(value);
	%orig(value, field);
}
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	if (gEnabled && field && value && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame)
		value = LIRewrite(value);
	%orig(value, field);
}
- (void)setHTTPBody:(NSData *)data {
	if (gEnabled && data.length) data = LIRewriteData(data);
	%orig(data);
}
- (void)setAllHTTPHeaderFields:(NSDictionary *)h {
	if (gEnabled && h.count) {
		NSMutableDictionary *m = [h mutableCopy];
		for (NSString *k in h) {
			if ([k caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame && [h[k] isKindOfClass:[NSString class]])
				m[k] = LIRewrite(h[k]);
		}
		h = m;
	}
	%orig(h);
}
%end

%hook NSJSONSerialization
+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
	NSData *d = %orig;
	if (gEnabled && d.length) {
		NSData *r = LIRewriteData(d);
		if (r != d) return r;
	}
	return d;
}
%end

// App Store UI: also force min-OS reads when browsing (harmless if not present)
%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
	id r = %orig;
	// Do NOT rewrite arbitrary bundles in App Store UI — only system version presentation
	return r;
}
%end

%end

#pragma mark - ctor

%ctor {
	@autoreleasepool {
		const char *prog = __progname ?: "";
		if (LIIsDenied(prog)) return;
		if (!LIIsAllowed(prog)) return;

		gCurrentDevice = [LICurrentMachine() copy];
		gCurrentVersion = [LICurrentOSVersion() copy];
		LILoadPrefs();

		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
			LIPrefsCallback, CFSTR(PREFS_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);

		// Always write breadcrumb first so user can verify injection even if hooks fail
		LIWriteBreadcrumb(prog, @"ctor");

		%init(GestaltHooks);

		if (LIIsInstalld(prog)) {
			LIInstallInstalldHooks();
			LIWriteBreadcrumb(prog, @"installd-hooks-installed");
			return;
		}

		if (LIIsStore(prog)) {
			Class uid = objc_getClass("UIDevice");
			if (uid) LITryHook(uid, @selector(systemVersion), (IMP)hook_ui, (IMP *)&orig_ui);
			%init(StoreHooks);
			LIWriteBreadcrumb(prog, @"store-hooks-installed");
			return;
		}
	}
}
