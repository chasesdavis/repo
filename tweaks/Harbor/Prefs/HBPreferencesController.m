#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../HBPreferences.h"

@interface HBPreferencesController : PSListController
@end
@implementation HBPreferencesController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        for (PSSpecifier *specifier in _specifiers) {
            if ([specifier.identifier isEqualToString:@"runtimeStatus"]) {
                [specifier setProperty:HBRuntimeStatusSummary() forKey:@"footerText"];
            }
        }
    }
    return _specifiers;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}
- (void)refreshRuntimeStatus { [self reloadSpecifiers]; }
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:NSString.class]) return nil;
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)HBPreferencesDomain));
    return value ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    HBSetPreference([specifier propertyForKey:@"key"], value);
}
@end
