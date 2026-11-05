#import "HBFocusMonitor.h"
#import "HBVersion.h"
#import <TargetConditionals.h>
#import <objc/message.h>
#import <dlfcn.h>

static const char *Unqualified(const char *type) { while (*type && strchr("rnNoORV", *type)) type++; return type; }
static BOOL Signature(id target, SEL selector, char result, NSArray<NSString *> *arguments) {
    NSMethodSignature *s = [target methodSignatureForSelector:selector];
    if (!s || s.numberOfArguments != arguments.count + 2) return NO;
    char actual = *Unqualified(s.methodReturnType);
    if (result == 'B' ? (actual != 'B' && actual != 'c') : actual != result) return NO;
    for (NSUInteger i = 0; i < arguments.count; i++) {
        const char *type = Unqualified([s getArgumentTypeAtIndex:i + 2]);
        if (arguments[i].length == 1 ? *type != [arguments[i] characterAtIndex:0] : strcmp(type, arguments[i].UTF8String)) return NO;
    }
    return YES;
}
static id Object(id target, NSString *name) {
    SEL s = NSSelectorFromString(name); return Signature(target, s, '@', @[]) ? ((id(*)(id,SEL))objc_msgSend)(target,s) : nil;
}
static id Service(NSString *name) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb", RTLD_LAZY | RTLD_LOCAL); });
    Class c = NSClassFromString(name); SEL s = NSSelectorFromString(@"serviceForClientIdentifier:");
    return Signature(c, s, '@', @[@"@"]) ? ((id(*)(id,SEL,id))objc_msgSend)(c,s,@"com.chasedavis.harbor") : nil;
}
static NSString *String(id value) { return [value isKindOfClass:NSString.class] && [value length] <= 200 ? value : nil; }
static NSDictionary *ErrorDetails(NSError *error, NSUInteger depth) {
    if (!error || depth > 2) return @{};
    NSString *message = error.localizedDescription ?: @"";
    NSMutableDictionary *details = [@{@"domain":error.domain ?: @"", @"code":@(error.code), @"description":[message substringToIndex:MIN(message.length,300)]} mutableCopy];
    if (error.localizedFailureReason) details[@"reason"] = [error.localizedFailureReason substringToIndex:MIN(error.localizedFailureReason.length,300)];
    if ([error.userInfo[NSUnderlyingErrorKey] isKindOfClass:NSError.class]) details[@"underlying"] = ErrorDetails(error.userInfo[NSUnderlyingErrorKey],depth+1);
    return details;
}
static NSDictionary *Issue(NSString *status, NSError *error) { return @{@"status":status, @"error":ErrorDetails(error,0)}; }
static void OnMain(dispatch_block_t block) { if (NSThread.isMainThread) block(); else dispatch_async(dispatch_get_main_queue(),block); }
static NSDictionary *Unavailable(NSString *status) { return @{@"available":@NO, @"active":@NO, @"identifier":@"", @"name":@"", @"status":status}; }
NSDictionary *HBFocusDisabledSnapshot(void) {
    return @{@"available":@NO, @"active":@NO, @"identifier":@"", @"name":@"", @"modes":@[], @"liveUpdates":@NO, @"disabled":@YES,
        @"status":@"Automatic Focus matching is off. Choose a layout manually from Saved profiles."};
}
static NSArray *Modes(NSArray *input) {
    NSMutableArray *modes = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    if (![input isKindOfClass:NSArray.class]) return modes;
    for (id value in input) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSString *key = String(value[@"id"]), *name = String(value[@"name"]);
        if (!key.length || !name.length || [seen containsObject:key]) continue;
        [seen addObject:key]; [modes addObject:@{@"id":key,@"name":name}]; if (modes.count == 32) break;
    }
    return modes;
}

@interface HBFocusListener : NSObject
@property (nonatomic, copy) void (^update)(void);
@end
@implementation HBFocusListener
- (void)stateService:(id)service didReceiveDoNotDisturbStateUpdate:(id)update { if (self.update) self.update(); }
@end

// Each channel has one bounded serial worker. A blocked optional service cannot
// hold up a state read. The coordinator never queues an unbounded set of retries.
@interface HBDNDFocusReader : NSObject <HBFocusReading>
@property (nonatomic, strong) dispatch_queue_t stateQueue, modesQueue, updatesQueue;
@property (nonatomic, strong) id updateService;
@property (nonatomic, strong) HBFocusListener *listener;
@property (nonatomic) NSUInteger updatesEpoch;
@property (nonatomic) NSUInteger readsEpoch;
@property (nonatomic) BOOL cleanupQueued;
@end
@implementation HBDNDFocusReader
- (instancetype)init {
    if ((self = [super init])) {
        _stateQueue = dispatch_queue_create("com.chasedavis.harbor.focus.state",DISPATCH_QUEUE_SERIAL);
        _modesQueue = dispatch_queue_create("com.chasedavis.harbor.focus.modes",DISPATCH_QUEUE_SERIAL);
        _updatesQueue = dispatch_queue_create("com.chasedavis.harbor.focus.updates",DISPATCH_QUEUE_SERIAL);
    } return self;
}
- (void)readState:(void (^)(NSDictionary *))completion {
    NSUInteger epoch; @synchronized (self) { epoch = self.readsEpoch; }
    dispatch_async(self.stateQueue, ^{
        NSDictionary *result;
        @synchronized (self) { if (epoch != self.readsEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
        @try {
            id service = Service(@"DNDStateService"); SEL query = NSSelectorFromString(@"queryCurrentStateWithError:");
            @synchronized (self) { if (epoch != self.readsEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
            if (!Signature(service,query,'@',@[@"^@"])) result = @{@"issue":Issue(@"interface-unavailable",nil)};
            else {
                NSError *error = nil; id state = ((id(*)(id,SEL,NSError **))objc_msgSend)(service,query,&error);
                SEL activeSelector = NSSelectorFromString(@"isActive");
                if (error || !state) result = @{@"issue":Issue(@"query-failed",error)};
                else if (!Signature(state,activeSelector,'B',@[])) result = @{@"issue":Issue(@"state-interface-changed",nil)};
                else {
                    BOOL active = ((BOOL(*)(id,SEL))objc_msgSend)(state,activeSelector);
                    NSString *identifier = String(Object(state,@"activeModeIdentifier"));
                    NSString *name = String(Object(Object(Object(state,@"activeModeConfiguration"),@"mode"),@"name"));
                    result = @{@"available":@YES,@"active":@(active),@"identifier":identifier ?: @"",@"name":name ?: @""};
                }
            }
        } @catch (__unused NSException *e) { result = @{@"issue":Issue(@"interface-exception",nil)}; }
        completion(result);
    });
}
- (void)readModes:(void (^)(NSDictionary *))completion {
    NSUInteger epoch; @synchronized (self) { epoch = self.readsEpoch; }
    dispatch_async(self.modesQueue, ^{
        NSDictionary *result;
        @synchronized (self) { if (epoch != self.readsEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
        @try {
            id service = Service(@"DNDModeConfigurationService"); SEL query = NSSelectorFromString(@"modeConfigurationsReturningError:");
            @synchronized (self) { if (epoch != self.readsEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
            if (!Signature(service,query,'@',@[@"^@"])) result = @{@"issue":Issue(@"interface-unavailable",nil)};
            else {
                NSError *error = nil; id configs = ((id(*)(id,SEL,NSError **))objc_msgSend)(service,query,&error);
                if (error || !configs) result = @{@"issue":Issue(@"query-failed",error)};
                else if (![configs isKindOfClass:NSDictionary.class] && ![configs isKindOfClass:NSArray.class]) result = @{@"issue":Issue(@"unexpected-result",nil)};
                else {
                    NSArray *values = [configs isKindOfClass:NSDictionary.class] ? [configs allValues] : configs;
                    NSMutableArray *modes = [NSMutableArray array];
                    for (id configuration in values) {
                        id mode = Object(configuration,@"mode"); NSString *key = String(Object(mode,@"modeIdentifier")), *name = String(Object(mode,@"name"));
                        if (key.length && name.length) [modes addObject:@{@"id":key,@"name":name}];
                        if (modes.count == 32) break;
                    }
                    result = @{@"modes":Modes(modes)};
                }
            }
        } @catch (__unused NSException *e) { result = @{@"issue":Issue(@"interface-exception",nil)}; }
        completion(result);
    });
}
- (void)beginUpdates:(void (^)(void))update completion:(void (^)(NSDictionary *))completion {
    NSUInteger epoch;
    @synchronized (self) { epoch = ++self.updatesEpoch; }
    dispatch_async(self.updatesQueue, ^{
        NSDictionary *result;
        @synchronized (self) { if (epoch != self.updatesEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
        @try {
            self.updateService = Service(@"DNDStateService"); SEL add = NSSelectorFromString(@"addStateUpdateListener:error:");
            @synchronized (self) { if (epoch != self.updatesEpoch) { completion(@{@"issue":Issue(@"cancelled",nil)}); return; } }
            if (!Signature(self.updateService,add,'B',@[@"@",@"^@"])) result = @{@"issue":Issue(@"interface-unavailable",nil)};
            else {
                self.listener = [HBFocusListener new]; self.listener.update = update;
                NSError *error = nil; BOOL ok = ((BOOL(*)(id,SEL,id,NSError **))objc_msgSend)(self.updateService,add,self.listener,&error);
                result = ok && !error ? @{@"liveUpdates":@YES} : @{@"issue":Issue(@"registration-failed",error)};
            }
        } @catch (__unused NSException *e) { result = @{@"issue":Issue(@"interface-exception",nil)}; }
        BOOL cancelled;
        @synchronized (self) { cancelled = epoch != self.updatesEpoch; }
        if (cancelled) { [self removeUpdates]; result = @{@"issue":Issue(@"cancelled",nil)}; }
        completion(result);
    });
}
- (void)removeUpdates {
    @try {
        SEL remove = NSSelectorFromString(@"removeStateUpdateListener:");
        if (self.listener && Signature(self.updateService,remove,'v',@[@"@"])) ((void(*)(id,SEL,id))objc_msgSend)(self.updateService,remove,self.listener);
    } @catch (__unused NSException *e) {}
    self.listener = nil; self.updateService = nil;
}
- (void)endUpdates {
    @synchronized (self) {
        self.updatesEpoch++;
        if (self.cleanupQueued) return;
        self.cleanupQueued = YES;
    }
    dispatch_async(self.updatesQueue, ^{
        [self removeUpdates];
        @synchronized (self) { self.cleanupQueued = NO; }
    });
}
- (void)cancelPendingReads { @synchronized (self) { self.readsEpoch++; } }
@end

@interface HBFocusMonitor ()
@property (nonatomic, copy, readwrite) NSDictionary *snapshot;
@property (nonatomic, strong) id<HBFocusReading> reader;
@property (nonatomic, copy) void (^schedule)(NSTimeInterval,dispatch_block_t);
@property (nonatomic) NSTimeInterval deadline;
@property (nonatomic) BOOL running, querying, queryAgain, expired;
@property (nonatomic) BOOL updatesPending, updatesAttempted, updatesExpired, liveUpdates;
@property (nonatomic) BOOL modesPending, modesAttempted, modesExpired;
@property (nonatomic) NSUInteger generation, requestID, updatesID, modesID;
@property (nonatomic, copy) NSDictionary *state, *stateIssue, *updatesIssue, *modesIssue;
@property (nonatomic, copy) NSArray *knownModes;
@property (nonatomic, copy) NSString *checkedAt;
@end
@implementation HBFocusMonitor
- (instancetype)init {
    return [self initWithReader:[HBDNDFocusReader new] deadline:2 scheduler:^(NSTimeInterval delay,dispatch_block_t block) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(),block);
    }];
}
- (instancetype)initWithReader:(id<HBFocusReading>)reader deadline:(NSTimeInterval)deadline scheduler:(void (^)(NSTimeInterval,dispatch_block_t))scheduler {
    if ((self = [super init])) {
        _reader = reader; _deadline = MAX(0.01,deadline); _schedule = [scheduler copy];
        _snapshot = Unavailable(@"Focus has not been checked yet.");
    } return self;
}
- (void)publish {
    if (!self.running) return;
    NSMutableDictionary *snapshot = [self.state mutableCopy];
    BOOL available = [snapshot[@"available"] boolValue], active = [snapshot[@"active"] boolValue];
    NSMutableArray *modes = [NSMutableArray array];
    if (available) {
        if (active) [modes addObject:@{@"id":snapshot[@"identifier"],@"name":[snapshot[@"name"] length] ? snapshot[@"name"] : @"Current Focus"}];
        [modes addObjectsFromArray:self.knownModes ?: @[]];
        snapshot[@"status"] = [NSString stringWithFormat:@"%@%@",active ? [NSString stringWithFormat:@"Current Focus: %@.",[snapshot[@"name"] length] ? snapshot[@"name"] : @"Active"] : @"Focus is off. Your default profile is selected.",
            self.liveUpdates ? @"" : (self.updatesPending && !self.updatesExpired ? @" Checking live updates…" : @" Live updates unavailable; reopen Harbor to refresh.")];
    }
    snapshot[@"modes"] = Modes(modes); snapshot[@"liveUpdates"] = @(available && self.liveUpdates);
    snapshot[@"diagnostics"] = @{@"version":@HARBOR_VERSION,@"environment":TARGET_OS_SIMULATOR ? @"Simulator" : (TARGET_OS_IOS ? @"Device" : @"Host test"),
        @"process":NSProcessInfo.processInfo.processName,@"runtime":NSProcessInfo.processInfo.operatingSystemVersionString,
        @"checkedAt":self.checkedAt ?: @"Not completed",@"state":self.stateIssue ?: Issue(@"not-checked",nil),
        @"updates":self.updatesIssue ?: Issue(@"not-checked",nil),@"catalog":self.modesIssue ?: Issue(@"not-checked",nil)};
    if ([self.snapshot isEqual:snapshot]) return;
    self.snapshot = snapshot; if (self.onChange) self.onChange(snapshot);
}
- (void)start {
    NSCAssert(NSThread.isMainThread,@"Focus lifecycle runs on main");
    if (self.running) return;
    self.running = YES; self.generation++; self.queryAgain = NO;
    self.state = Unavailable(@"Checking Focus. Using your default profile until iOS replies.");
    self.stateIssue = Issue(@"checking",nil); self.updatesIssue = self.modesIssue = Issue(@"not-checked",nil);
    self.updatesAttempted = self.modesAttempted = self.liveUpdates = NO; self.knownModes = @[]; self.checkedAt = nil;
    [self publish];
    // An old blocked read retains its worker; reopening must not add new workers.
    if (self.querying) [self armDeadline:self.requestID generation:self.generation];
    [self refresh];
}
- (void)armDeadline:(NSUInteger)request generation:(NSUInteger)generation {
    __weak typeof(self) weakSelf = self;
    self.schedule(self.deadline, ^{
        typeof(self) self = weakSelf;
        if (!self.running || self.generation != generation || !self.querying || self.requestID != request) return;
        self.expired = YES; self.stateIssue = Issue(@"timeout",nil);
        self.state = Unavailable(@"Focus did not reply in time. Your default profile stays selected. A pending read must finish before Harbor can retry.");
        [self publish];
    });
}
- (void)refresh {
    NSCAssert(NSThread.isMainThread,@"Focus lifecycle runs on main");
    if (!self.running) return;
    if (self.querying) { self.queryAgain = YES; return; }
    self.querying = YES; self.queryAgain = self.expired = NO;
    self.stateIssue = Issue(@"checking",nil); [self publish];
    NSUInteger request = ++self.requestID, generation = self.generation;
    [self armDeadline:request generation:generation];
    __weak typeof(self) weakSelf = self;
    [self.reader readState:^(NSDictionary *result) { OnMain(^{
        typeof(self) self = weakSelf;
        if (!self || !self.querying || request != self.requestID) return;
        self.querying = NO;
        if (!self.running) return;
        // Ignore stale replies, including any request whose deadline expired.
        if (generation != self.generation || self.queryAgain || self.expired) {
            if (generation != self.generation || self.queryAgain) [self refresh];
            return;
        }
        self.checkedAt = [[NSISO8601DateFormatter new] stringFromDate:NSDate.date];
        BOOL available = [result[@"available"] boolValue], active = [result[@"active"] boolValue];
        NSString *identifier = String(result[@"identifier"]), *name = String(result[@"name"]);
        if (available && (!active || identifier.length)) {
            self.state = @{@"available":@YES,@"active":@(active),@"identifier":active ? identifier : @"",@"name":active ? (name ?: @"") : @""};
            self.stateIssue = Issue(@"ok",nil); [self publish]; [self startCapabilities];
        } else {
            self.state = Unavailable(available ? @"iOS did not expose the active Focus identifier. Your default profile stays selected." : @"Focus could not be read. Your default profile stays selected. See Focus diagnostics for details.");
            self.stateIssue = result[@"issue"] ?: Issue(available ? @"missing-identifier" : @"query-failed",nil);
            self.liveUpdates = NO; self.updatesID++; [self.reader endUpdates];
            self.updatesIssue = Issue(@"state-unavailable",nil); [self publish];
        }
    }); }];
}
- (void)startCapabilities {
    __weak typeof(self) weakSelf = self;
    NSUInteger generation = self.generation;
    if (!self.updatesAttempted && !self.updatesPending) {
        self.updatesAttempted = self.updatesPending = YES; self.updatesExpired = NO;
        self.updatesIssue = Issue(@"checking",nil); NSUInteger token = ++self.updatesID;
        self.schedule(self.deadline, ^{
            typeof(self) self = weakSelf;
            if (!self.running || self.generation != generation || self.updatesID != token || !self.updatesPending) return;
            self.updatesExpired = YES; self.updatesIssue = Issue(@"timeout",nil); [self publish];
        });
        [self.reader beginUpdates:^{ OnMain(^{
            typeof(self) self = weakSelf;
            if (self.running && self.generation == generation && self.updatesID == token && !self.updatesExpired) [self refresh];
        }); } completion:^(NSDictionary *result) { OnMain(^{
            typeof(self) self = weakSelf; if (!self) return;
            self.updatesPending = NO;
            if (!self.running || self.generation != generation || self.updatesID != token || self.updatesExpired) {
                [self.reader endUpdates];
                if (self.running && [self.state[@"available"] boolValue]) [self startCapabilities];
                return;
            }
            self.liveUpdates = [result[@"liveUpdates"] boolValue]; self.updatesIssue = self.liveUpdates ? Issue(@"ok",nil) : result[@"issue"] ?: Issue(@"registration-failed",nil);
            if (!self.liveUpdates) [self.reader endUpdates];
            [self publish];
            // Close the gap between the first read and observer registration.
            if (self.liveUpdates) [self refresh];
        }); }];
    }
    if (!self.modesAttempted && !self.modesPending) {
        self.modesAttempted = self.modesPending = YES; self.modesExpired = NO;
        self.modesIssue = Issue(@"checking",nil); NSUInteger token = ++self.modesID;
        self.schedule(self.deadline, ^{
            typeof(self) self = weakSelf;
            if (!self.running || self.generation != generation || self.modesID != token || !self.modesPending) return;
            self.modesExpired = YES; self.modesIssue = Issue(@"timeout",nil); [self publish];
        });
        [self.reader readModes:^(NSDictionary *result) { OnMain(^{
            typeof(self) self = weakSelf; if (!self) return;
            self.modesPending = NO;
            if (!self.running || self.generation != generation || self.modesID != token || self.modesExpired) {
                if (self.running && [self.state[@"available"] boolValue]) [self startCapabilities];
                return;
            }
            self.knownModes = Modes(result[@"modes"]); self.modesIssue = result[@"issue"] ?: Issue(@"ok",nil); [self publish];
        }); }];
    }
    [self publish];
}
- (void)stop {
    NSCAssert(NSThread.isMainThread,@"Focus lifecycle runs on main");
    if (!self.running) return;
    self.running = NO; self.generation++; self.updatesID++; self.modesID++; self.queryAgain = self.liveUpdates = NO;
    [self.reader cancelPendingReads];
    [self.reader endUpdates];
}
- (void)dealloc { [_reader cancelPendingReads]; [_reader endUpdates]; }
@end

NSString *HBFocusDiagnosticSummary(NSDictionary *snapshot) {
    if ([snapshot[@"disabled"] boolValue]) return [NSString stringWithFormat:@"Harbor %s\n\n%@\n\nHarbor starts no new Focus reads or subscriptions while automatic matching is disabled. A read already in progress may finish; its result is ignored and any existing listener is removed. This does not change your system Focus settings.\n\nManual profile selection and the native Focus controls remain available. Enabling the switch and saving opts into read-only mode matching; real device behavior is still unverified.",HARBOR_VERSION,snapshot[@"status"]];
    NSDictionary *d = snapshot[@"diagnostics"];
    if (!d) return @"No Focus read has completed in this session. Open Harbor to check the service.";
    NSMutableString *text = [NSMutableString stringWithFormat:@"Harbor %@ · %@\n%@\nProcess: %@\nLast completed read: %@\n\n%@\n",d[@"version"],d[@"environment"],d[@"runtime"],d[@"process"],d[@"checkedAt"],snapshot[@"status"]];
    for (NSString *key in @[@"state",@"updates",@"catalog"]) {
        NSDictionary *issue = d[key]; [text appendFormat:@"\n%@: %@",[key capitalizedString],issue[@"status"]];
        NSDictionary *error = issue[@"error"];
        for (NSUInteger depth = 0; depth < 3 && [error count]; depth++) {
            [text appendFormat:@"\n%@ (%@): %@",error[@"domain"],error[@"code"],error[@"description"]];
            if ([error[@"reason"] length] && ![error[@"description"] containsString:error[@"reason"]]) [text appendFormat:@"\n%@",error[@"reason"]]; error = error[@"underlying"];
        }
    }
    [text appendString:@"\n\nUnavailable is different from Focus being off. Saved links are preserved, and Harbor uses your default profile when it cannot read an exact mode. Preview app access does not establish SpringBoard support on your phone."];
    return text;
}
