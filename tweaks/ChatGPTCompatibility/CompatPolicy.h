#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const CGCBundleIdentifier;
FOUNDATION_EXPORT NSString *const CGCTargetVersion;
FOUNDATION_EXPORT BOOL CGCPreferencesEnabled(id preferences);
FOUNDATION_EXPORT BOOL CGCRuntimeAllowed(NSString *process, NSString *machine, NSOperatingSystemVersion version);
FOUNDATION_EXPORT BOOL CGCRequestTargetsChatGPT(NSURLRequest *request);
FOUNDATION_EXPORT NSURLRequest *CGCPreparedRequest(NSURLRequest *request, BOOL enabled);
FOUNDATION_EXPORT NSString *CGCPreparedHeaderValue(NSURLRequest *request, NSDictionary *purchaseParameters, NSString *field, NSString *value, BOOL enabled);
FOUNDATION_EXPORT BOOL CGCBundleMatchesTarget(NSString *identifier, NSURL *bundleURL);
FOUNDATION_EXPORT id CGCInstallerVersion(id minimumVersion, id originalVersion, NSString *identifier, NSURL *bundleURL, BOOL enabled);
