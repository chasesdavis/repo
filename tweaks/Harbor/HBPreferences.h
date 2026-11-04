#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString *const HBPreferencesDomain;
FOUNDATION_EXPORT NSString *const HBPreferencesChanged;
FOUNDATION_EXPORT void HBReloadPreferences(void);
FOUNDATION_EXPORT BOOL HBEnabled(void);
FOUNDATION_EXPORT BOOL HBHapticsEnabled(void);
FOUNDATION_EXPORT UIColor *HBAccentColor(void);
FOUNDATION_EXPORT NSString *HBPalette(void);
FOUNDATION_EXPORT void HBSetPreference(NSString *key, id value);
