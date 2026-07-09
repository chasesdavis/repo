#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <sys/utsname.h>

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.julioverne.lowerinstall.plist"
#define PREFS_CHANGED "com.julioverne.lowerinstall/SettingsChanged"

@interface LowerInstallPrefsController : PSListController
@end

@implementation LowerInstallPrefsController {
	UILabel *_titleLabel;
	UILabel *_subtitleLabel;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specs = [NSMutableArray array];
		PSSpecifier *spec;

		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
											  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
											  detail:nil
												cell:PSSwitchCell
												edit:nil];
		[spec setProperty:@"Enabled" forKey:@"key"];
		[spec setProperty:@YES forKey:@"default"];
		[spec setProperty:@"com.julioverne.lowerinstall" forKey:@"defaults"];
		[specs addObject:spec];

		spec = [PSSpecifier groupSpecifierWithName:@"App Store Spoof"];
		[spec setProperty:@"SpoofVersion must be NEWER than your real iOS (default 18.4). After changes: reboot, or NewTerm: killall -9 installd appstored" forKey:@"footerText"];
		[specs addObject:spec];

		struct utsname systemInfo;
		uname(&systemInfo);
		NSString *device = [NSString stringWithUTF8String:systemInfo.machine] ?: @"iPhone15,2";

		spec = [PSSpecifier preferenceSpecifierNamed:@"Spoof iOS Version"
											  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
											  detail:nil
												cell:PSEditTextCell
												edit:nil];
		[spec setProperty:@"SpoofVersion" forKey:@"key"];
		[spec setProperty:@"18.4" forKey:@"default"];
		[spec setProperty:@"com.julioverne.lowerinstall" forKey:@"defaults"];
		[specs addObject:spec];

		spec = [PSSpecifier preferenceSpecifierNamed:@"Spoof Device (machine)"
											  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
											  detail:nil
												cell:PSEditTextCell
												edit:nil];
		[spec setProperty:@"SpoofDevice" forKey:@"key"];
		[spec setProperty:device forKey:@"default"];
		[spec setProperty:@"com.julioverne.lowerinstall" forKey:@"defaults"];
		[specs addObject:spec];

		spec = [PSSpecifier emptyGroupSpecifier];
		[spec setProperty:@"RootHide Bootstrap: ensure daemon injection is active (Bootstrap 2.x). installd + appstored must load this tweak. App Store must be enabled in App List if required." forKey:@"footerText"];
		[specs addObject:spec];

		spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings"
											  target:self
												 set:nil
												 get:nil
											  detail:nil
												cell:PSButtonCell
												edit:nil];
		spec->action = @selector(resetSettings);
		[specs addObject:spec];

		spec = [PSSpecifier emptyGroupSpecifier];
		[spec setProperty:@"Original by julioverne · Rootless/RootHide port for iOS 15–17 Bootstrap" forKey:@"footerText"];
		[specs addObject:spec];

		_specifiers = [specs copy];
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PLIST_PATH] ?: @{};
	id value = prefs[key];
	return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	if (!key) return;
	NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfFile:PLIST_PATH] mutableCopy] ?: [NSMutableDictionary dictionary];
	if (value) prefs[key] = value;
	else [prefs removeObjectForKey:key];
	[prefs writeToFile:PLIST_PATH atomically:YES];
	// Also write CFPreferences so daemons reading the domain see updates
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, CFSTR("com.julioverne.lowerinstall"));
	CFPreferencesAppSynchronize(CFSTR("com.julioverne.lowerinstall"));
	notify_post(PREFS_CHANGED);
}

- (void)resetSettings {
	[@{} writeToFile:PLIST_PATH atomically:YES];
	notify_post(PREFS_CHANGED);
	[self reloadSpecifiers];

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"LowerInstall"
																   message:@"Settings reset. Kill installd / appstored or reboot for a clean state."
															preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"LowerInstall";

	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 110)];
	CGFloat width = UIScreen.mainScreen.bounds.size.width;

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 24, width, 44)];
	_titleLabel.text = @"LowerInstall";
	_titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightUltraLight];
	_titleLabel.textAlignment = NSTextAlignmentCenter;
	_titleLabel.textColor = UIColor.labelColor;

	_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 70, width - 32, 24)];
	_subtitleLabel.text = @"Install apps meant for newer iOS";
	_subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
	_subtitleLabel.textAlignment = NSTextAlignmentCenter;
	_subtitleLabel.textColor = UIColor.secondaryLabelColor;

	[header addSubview:_titleLabel];
	[header addSubview:_subtitleLabel];
	[self.table setTableHeaderView:header];
}

@end
