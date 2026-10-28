#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import "../SO17Prefs.h"

@interface StayOn17PrefsController : PSListController
@end

@implementation StayOn17PrefsController

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
        [spec setProperty:@"globalEnabled" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [spec setProperty:kSO17PrefsDomain forKey:@"defaults"];
        [specs addObject:spec];

        spec = [PSSpecifier groupSpecifierWithName:@"Install helpers"];
        [spec setProperty:@"Store/installd spoof uses default 18.0 unless you enable specific apps below. Respring or kill App Store daemons after changes." forKey:@"footerText"];
        [specs addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Patch MinimumOSVersion on download"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:nil
                                                cell:PSSwitchCell
                                                edit:nil];
        [spec setProperty:@"patchMinimumOSOnDownload" forKey:@"key"];
        [spec setProperty:@NO forKey:@"default"];
        [spec setProperty:kSO17PrefsDomain forKey:@"defaults"];
        [specs addObject:spec];

        spec = [PSSpecifier groupSpecifierWithName:@"Per-app spoof"];
        [spec setProperty:@"Add bundle IDs with stayon17-scan enable <id> or edit plist. Enabled apps get runtime UIDevice/NSProcessInfo spoof." forKey:@"footerText"];
        [specs addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Add bundle ID"
                                              target:self
                                                 set:@selector(addBundleID:specifier:)
                                                 get:nil
                                              detail:nil
                                                cell:PSEditTextCell
                                                edit:nil];
        [spec setProperty:@"newBundleID" forKey:@"key"];
        [specs addObject:spec];

        spec = [PSSpecifier preferenceSpecifierNamed:@"Default spoof version"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:nil
                                                cell:PSEditTextCell
                                                edit:nil];
        [spec setProperty:@"defaultSpoofVersion" forKey:@"key"];
        [spec setProperty:@"18.0" forKey:@"default"];
        [spec setProperty:kSO17PrefsDomain forKey:@"defaults"];
        [specs addObject:spec];

        for (NSString *bid in [[SO17Prefs shared] enabledBundleIDs]) {
            spec = [PSSpecifier preferenceSpecifierNamed:bid
                                                  target:self
                                                     set:@selector(toggleBundle:specifier:)
                                                     get:@selector(readBundleEnabled:)
                                                  detail:nil
                                                    cell:PSSwitchCell
                                                    edit:nil];
            [spec setProperty:bid forKey:@"bundleID"];
            [specs addObject:spec];
            NSDictionary *cache = [[SO17Prefs shared] scanCacheForBundle:bid];
            NSString *verdict = cache[@"verdict"] ?: @"unknown";
            spec = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"Scan: %@", verdict]
                                                  target:self
                                                     set:nil
                                                     get:nil
                                                  detail:nil
                                                    cell:PSStaticTextCell
                                                    edit:nil];
            [specs addObject:spec];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id val = [[SO17Prefs shared] valueForKey:key] ?: [specifier propertyForKey:@"default"];
    return val;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"globalEnabled"]) {
        [[SO17Prefs shared] setGlobalEnabled:[value boolValue]];
    } else if ([key isEqualToString:@"patchMinimumOSOnDownload"]) {
        [[SO17Prefs shared] setPatchMinimumOSOnDownload:[value boolValue]];
    } else {
        [[SO17Prefs shared] writeDict:@{ key: value ?: @"" }];
        [[SO17Prefs shared] postPrefsChanged];
    }
    [self reloadSpecifiers];
}

- (void)addBundleID:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bid = [value isKindOfClass:[NSString class]] ? value : nil;
    if (!bid.length) return;
    [[SO17Prefs shared] setEnabled:YES forBundle:bid spoofVersion:[[SO17Prefs shared] defaultSpoofVersion]];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (id)readBundleEnabled:(PSSpecifier *)specifier {
    NSString *bid = [specifier propertyForKey:@"bundleID"];
    return @([[SO17Prefs shared] isBundleEnabled:bid]);
}

- (void)toggleBundle:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bid = [specifier propertyForKey:@"bundleID"];
    BOOL on = [value boolValue];
    [[SO17Prefs shared] setEnabled:on forBundle:bid spoofVersion:on ? [[SO17Prefs shared] spoofVersionForBundle:bid] : nil];
    _specifiers = nil;
    [self reloadSpecifiers];
}

@end
