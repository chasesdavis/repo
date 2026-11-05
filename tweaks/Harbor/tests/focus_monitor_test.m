#import <Foundation/Foundation.h>
#import "FocusChecks.h"
int main(void) { @autoreleasepool {
    __block NSUInteger total=0,failed=0;
    HBRunFocusChecks(^(BOOL passed,NSString *name) { total++; if(!passed) failed++; printf("%s %s\n",passed ? "PASS" : "FAIL",name.UTF8String); });
    printf("Focus coordinator: %lu checks, %lu failures\n",(unsigned long)total,(unsigned long)failed); return failed ? 1 : 0;
} }
