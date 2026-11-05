#import "HBProfileModel.h"
FOUNDATION_EXPORT NSDictionary *HBLoadProfileLibrary(void);
FOUNDATION_EXPORT BOOL HBSaveProfileLibrary(NSDictionary *library, NSNumber *expectedRevision, NSError **error);
