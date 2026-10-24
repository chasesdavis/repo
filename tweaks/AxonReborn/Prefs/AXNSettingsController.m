// SPDX-License-Identifier: GPL-3.0-only
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../Shared/AXNPreferences.h"
@interface AXNSettingsController : PSListController
@end
@implementation AXNSettingsController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    AXNSynchronizePreferences();
    return AXNReadPreference([specifier propertyForKey:@"key"], [specifier propertyForKey:@"default"]);
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    AXNWritePreference([specifier propertyForKey:@"key"], value);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Axon Reborn";
}
@end
