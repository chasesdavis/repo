#import "MethodTypes.h"
#include <string.h>
#include <stdlib.h>

static const char *CGCSkipQualifiers(const char *type) {
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

BOOL CGCMethodMatches(Method method, const char *returnType, NSArray<NSString *> *argumentTypes) {
    if (!method || method_getNumberOfArguments(method) != argumentTypes.count) return NO;
    char *actual = method_copyReturnType(method);
    BOOL matches = actual && strcmp(CGCSkipQualifiers(actual), returnType) == 0;
    free(actual);
    for (NSUInteger index = 0; matches && index < argumentTypes.count; index++) {
        actual = method_copyArgumentType(method, (unsigned int)index);
        matches = actual && strcmp(CGCSkipQualifiers(actual), argumentTypes[index].UTF8String) == 0;
        free(actual);
    }
    return matches;
}
