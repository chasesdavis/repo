#import <Foundation/Foundation.h>
#import <objc/runtime.h>

FOUNDATION_EXPORT BOOL CGCMethodMatches(Method method, const char *returnType, NSArray<NSString *> *argumentTypes);
