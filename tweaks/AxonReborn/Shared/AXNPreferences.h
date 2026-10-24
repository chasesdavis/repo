// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString * const AXNPreferencesDomain;
FOUNDATION_EXPORT NSString * const AXNPreferencesChanged;
FOUNDATION_EXPORT id AXNReadPreference(NSString *key, id fallback);
FOUNDATION_EXPORT void AXNWritePreference(NSString *key, id value);
FOUNDATION_EXPORT void AXNSynchronizePreferences(void);
// Fixed diagnostic states only. No notification content or identifiers cross processes.
typedef NS_ENUM(NSUInteger, AXNDiagnosticState) {
    AXNDiagnosticWaiting, AXNDiagnosticDisabled, AXNDiagnosticClasses,
    AXNDiagnosticSignatures, AXNDiagnosticSnapshot, AXNDiagnosticRequest,
    AXNDiagnosticMount, AXNDiagnosticEmpty, AXNDiagnosticReady,
    AXNDiagnosticReplay, AXNDiagnosticOS, AXNDiagnosticCollection,
    AXNDiagnosticGeometry, AXNDiagnosticStateCount
};
FOUNDATION_EXPORT NSString * const AXNDiagnosticQuery;
FOUNDATION_EXPORT NSString *AXNDiagnosticReply(NSUInteger state);
FOUNDATION_EXPORT NSString *AXNDiagnosticMessage(NSUInteger state);
