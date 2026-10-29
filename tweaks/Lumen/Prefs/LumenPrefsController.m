#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../LumenPrefs.h"

static NSString *const kLumenDonateURL = @"https://paypal.me/chasesdavis";

@interface LumenPrefsController : PSListController
@end

@implementation LumenPrefsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];
        [specifiers addObjectsFromArray:[self rootSpecifiers]];
        _specifiers = specifiers;
    }
    return _specifiers;
}

- (NSArray *)rootSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];

    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Lumen"];
    [group setProperty:@"A smart pill on the status bar clock. Free, always." forKey:@"footerText"];
    [specs addObject:group];

    [specs addObject:[self switchSpecifier:@"Enabled" key:@"enabled" fallback:YES]];
    [specs addObject:[self switchSpecifier:@"Hide the clock behind the pill" key:@"hideClock" fallback:YES]];

    PSSpecifier *pillGroup = [PSSpecifier groupSpecifierWithName:@"Pills"];
    [pillGroup setProperty:@"Long press the pill to cycle. Tap opens its card." forKey:@"footerText"];
    [specs addObject:pillGroup];

    NSArray *pills = @[
        @[ @"time", @"Time" ],
        @[ @"date", @"Date" ],
        @[ @"battery", @"Battery" ],
        @[ @"playing", @"Now playing" ],
        @[ @"network", @"Network speed" ],
        @[ @"storage", @"Storage" ],
        @[ @"countdown", @"Countdown" ],
        @[ @"message", @"Quick message" ],
    ];
    for (NSArray *pill in pills) {
        NSString *key = [@"pill." stringByAppendingString:pill[0]];
        BOOL fallback = ![pill[0] isEqualToString:@"message"] && ![pill[0] isEqualToString:@"countdown"];
        [specs addObject:[self switchSpecifier:pill[1] key:key fallback:fallback]];
    }

    PSSpecifier *appearance = [PSSpecifier groupSpecifierWithName:@"Appearance"];
    [appearance setProperty:@"0.0 is fully transparent, 0.9 is nearly solid." forKey:@"footerText"];
    [specs addObject:appearance];

    [specs addObject:[self switchSpecifier:@"Custom accent color" key:@"customColor" fallback:NO]];

    PSSpecifier *hex = [PSSpecifier preferenceSpecifierNamed:@"Accent hex"
                                                      target:self
                                                         set:@selector(setPreferenceValue:specifier:)
                                                         get:@selector(readPreferenceValue:)
                                                      detail:nil
                                                        cell:PSListItemCell
                                                        edit:nil];
    [hex setProperty:@"accentHex" forKey:@"key"];
    [hex setProperty:@"#5CC7FA" forKey:@"placeholder"];
    [hex setProperty:@YES forKey:@"isHex"];
    [specs addObject:hex];

    PSSpecifier *countdown = [PSSpecifier preferenceSpecifierNamed:@"Countdown date"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSListItemCell
                                                              edit:nil];
    [countdown setProperty:@"countdownDateText" forKey:@"key"];
    [countdown setProperty:@"YYYY-MM-DD" forKey:@"placeholder"];
    [specs addObject:countdown];

    PSSpecifier *opacity = [PSSpecifier preferenceSpecifierNamed:@"Pill opacity"
                                                          target:self
                                                             set:@selector(setPreferenceValue:specifier:)
                                                             get:@selector(readPreferenceValue:)
                                                          detail:nil
                                                            cell:PSSliderCell
                                                            edit:nil];
    [opacity setProperty:@"pillOpacity" forKey:@"key"];
    [opacity setProperty:@0.0 forKey:@"min"];
    [opacity setProperty:@0.9 forKey:@"max"];
    [opacity setProperty:@0.05 forKey:@"step"];
    [opacity setProperty:@0.34 forKey:@"default"];
    [specs addObject:opacity];

    PSSpecifier *scale = [PSSpecifier preferenceSpecifierNamed:@"Text scale"
                                                        target:self
                                                           set:@selector(setPreferenceValue:specifier:)
                                                           get:@selector(readPreferenceValue:)
                                                        detail:nil
                                                          cell:PSSliderCell
                                                          edit:nil];
    [scale setProperty:@"fontScale" forKey:@"key"];
    [scale setProperty:@0.8 forKey:@"min"];
    [scale setProperty:@1.3 forKey:@"max"];
    [scale setProperty:@0.05 forKey:@"step"];
    [scale setProperty:@1.0 forKey:@"default"];
    [specs addObject:scale];

    PSSpecifier *support = [PSSpecifier groupSpecifierWithName:@"Support"];
    [support setProperty:@"Lumen is free. If it earns a place on your status bar, a donation keeps it maintained." forKey:@"footerText"];
    [specs addObject:support];

    PSSpecifier *donate = [PSSpecifier preferenceSpecifierNamed:@"Donate"
                                                         target:self
                                                            set:nil
                                                            get:nil
                                                         detail:nil
                                                           cell:PSButtonCell
                                                           edit:nil];
    donate->action = @selector(openDonation);
    [specs addObject:donate];

    return specs;
}

- (PSSpecifier *)switchSpecifier:(NSString *)name key:(NSString *)key fallback:(BOOL)fallback {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:LumenDomain forKey:@"defaults"];
    [specifier setProperty:@(fallback) forKey:@"default"];
    return specifier;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    if ([[specifier propertyForKey:@"key"] isEqualToString:@"countdownDateText"]) {
        NSDate *date = LumenCountdownDate();
        if (!date) {
            return @"";
        }
        static NSDateFormatter *formatter;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            formatter = [NSDateFormatter new];
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd";
        });
        return [formatter stringFromDate:date];
    }
    id value = [super readPreferenceValue:specifier];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    if ([[specifier propertyForKey:@"key"] isEqualToString:@"countdownDateText"]) {
        [self storeCountdownFromText:value];
    }
    LumenReloadPrefs();
}

/// The pill reads a timestamp; the field takes a plain date for sanity.
- (void)storeCountdownFromText:(NSString *)text {
    static NSDateFormatter *parser;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        parser = [NSDateFormatter new];
        parser.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        parser.dateFormat = @"yyyy-MM-dd";
    });
    NSDate *date = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] length]
        ? [parser dateFromString:text]
        : nil;
    LumenSetPref(@"countdownDate", date ? @([date timeIntervalSince1970]) : nil);
}

- (void)openDonation {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kLumenDonateURL]
                                       options:@{}
                             completionHandler:nil];
}

@end
