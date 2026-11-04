#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../HBPreferences.h"

@interface HBPreferencesController : PSListController
@end
@implementation HBPreferencesController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,
        (__bridge CFStringRef)HBPreferencesDomain));
    return value ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    HBSetPreference([specifier propertyForKey:@"key"], value);
}
@end
