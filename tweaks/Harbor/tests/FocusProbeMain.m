// Read-only diagnostic app. Does not change Focus, identity, signing, or privileges.
#import <UIKit/UIKit.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
static NSDictionary *DescribeError(NSError *error, NSUInteger depth) {
    if (!error || depth > 3) return @{};
    NSMutableDictionary *d = [@{@"domain":error.domain, @"code":@(error.code), @"description":error.localizedDescription ?: @""} mutableCopy];
    if (error.localizedFailureReason) d[@"reason"] = error.localizedFailureReason;
    if ([error.userInfo[NSUnderlyingErrorKey] isKindOfClass:NSError.class]) d[@"underlying"] = DescribeError(error.userInfo[NSUnderlyingErrorKey],depth+1);
    return d;
}
@interface HBFocusProbe : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation HBFocusProbe
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; UIViewController *vc = [UIViewController new]; vc.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.window.bounds,24,120)]; label.text = @"Read-only Focus diagnostic…"; label.numberOfLines=0; [vc.view addSubview:label]; self.window.rootViewController=vc; [self.window makeKeyAndVisible];
    NSString *version = UIDevice.currentDevice.systemVersion, *bundle = NSBundle.mainBundle.bundleIdentifier;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        NSMutableDictionary *report = [@{@"runtime":version, @"bundle":bundle, @"process":NSProcessInfo.processInfo.processName, @"requestedAuthorization":@NO} mutableCopy];
        @try {
            INFocusStatusCenter *center = INFocusStatusCenter.defaultCenter;
            report[@"publicAPI"] = @{@"authorizationStatus":@(center.authorizationStatus), @"isFocused":center.focusStatus.isFocused ?: NSNull.null};
        } @catch (NSException *e) { report[@"publicAPIException"] = e.reason ?: e.name; }
        void *framework = dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb", RTLD_LAZY|RTLD_LOCAL);
        report[@"frameworkLoaded"] = @(framework != NULL);
        Class cls = NSClassFromString(@"DNDStateService"); SEL factory=NSSelectorFromString(@"serviceForClientIdentifier:"), query=NSSelectorFromString(@"queryCurrentStateWithError:");
        report[@"classAvailable"] = @(cls != nil);
        @try {
            if ([cls respondsToSelector:factory]) {
                id service = ((id(*)(id,SEL,id))objc_msgSend)(cls,factory,@"com.chasedavis.harbor");
                NSMethodSignature *signature=[service methodSignatureForSelector:query]; NSMutableArray *args=[NSMutableArray array]; for(NSUInteger i=0;i<signature.numberOfArguments;i++) [args addObject:@([signature getArgumentTypeAtIndex:i])];
                report[@"querySignature"] = @{@"return":signature ? @(signature.methodReturnType) : @"", @"arguments":args};
                if (signature.numberOfArguments == 3 && signature.methodReturnType[0]=='@' && strstr([signature getArgumentTypeAtIndex:2],"^@")) {
                    NSError *error=nil; CFTimeInterval start=CACurrentMediaTime(); id state=((id(*)(id,SEL,NSError **))objc_msgSend)(service,query,&error);
                    report[@"queryMilliseconds"]=@((CACurrentMediaTime()-start)*1000); report[@"queryError"]=DescribeError(error,0); report[@"returnedState"]=@(state!=nil);
                    if (state) report[@"stateClass"]=NSStringFromClass([state class]);
                }
            }
        } @catch(NSException *e) { report[@"privateAPIException"]=e.reason?:e.name; }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
            NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"focus-probe.json"];
            [data writeToFile:path atomically:YES]; label.text=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]; label.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]; NSLog(@"FOCUS_PROBE_COMPLETE %@",report);
        });
    }); return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(HBFocusProbe.class)); } }
