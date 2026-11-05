#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSArray<NSString *> *HBSectionKeys(void);
FOUNDATION_EXPORT NSString *HBSectionName(NSString *key);
FOUNDATION_EXPORT NSDictionary *HBThemePresets(void);
FOUNDATION_EXPORT NSDictionary *HBDefaultLibrary(NSString *legacyPalette);
FOUNDATION_EXPORT NSDictionary *HBNormalizeLibrary(id value);
// Versioned, explicit opt-in. Legacy matching flags did not authorize the reader.
FOUNDATION_EXPORT BOOL HBFocusAccessEnabled(NSDictionary *library);
FOUNDATION_EXPORT NSDictionary *HBNormalizeProfile(id value);
FOUNDATION_EXPORT NSDictionary *HBProfileWithID(NSDictionary *library, NSString *identifier);
FOUNDATION_EXPORT NSDictionary *HBResolvedProfile(NSDictionary *library, NSDictionary *focus);
FOUNDATION_EXPORT NSDictionary *HBLibraryReplacingProfile(NSDictionary *library, NSDictionary *profile);
