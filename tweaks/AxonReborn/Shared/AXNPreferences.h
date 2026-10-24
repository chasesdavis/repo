// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString * const AXNPreferencesDomain;
FOUNDATION_EXPORT NSString * const AXNPreferencesChanged;
FOUNDATION_EXPORT id AXNReadPreference(NSString *key, id fallback);
FOUNDATION_EXPORT void AXNWritePreference(NSString *key, id value);
FOUNDATION_EXPORT void AXNSynchronizePreferences(void);
