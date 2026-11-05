#import "HBFocusMonitor.h"
#import "HBProfileModel.h"

// Controllable asynchronous service boundary; no guessed system modes or APIs.
// Deliveries and deadlines are explicitly interleaved against the real monitor.
@interface HBTestFocusReader : NSObject <HBFocusReading>
@property (nonatomic, strong) NSMutableArray *states, *catalogs, *registrations, *updates;
@property (nonatomic) NSUInteger stops;
@property (nonatomic) NSUInteger cancellations;
@end
@implementation HBTestFocusReader
- (instancetype)init { if ((self = [super init])) { _states=[NSMutableArray new]; _catalogs=[NSMutableArray new]; _registrations=[NSMutableArray new]; _updates=[NSMutableArray new]; } return self; }
- (void)readState:(void (^)(NSDictionary *))completion { [self.states addObject:[completion copy]]; }
- (void)readModes:(void (^)(NSDictionary *))completion { [self.catalogs addObject:[completion copy]]; }
- (void)beginUpdates:(void (^)(void))update completion:(void (^)(NSDictionary *))completion { [self.updates addObject:[update copy]]; [self.registrations addObject:[completion copy]]; }
- (void)endUpdates { self.stops++; }
- (void)cancelPendingReads { self.cancellations++; }
@end

@interface HBFocusFixture : NSObject
@property (nonatomic, strong) HBFocusMonitor *monitor;
@property (nonatomic, strong) HBTestFocusReader *reader;
@property (nonatomic, strong) NSMutableArray *timers, *snapshots;
@end
@implementation HBFocusFixture
- (instancetype)init {
    if ((self = [super init])) {
        _reader=[HBTestFocusReader new]; _timers=[NSMutableArray new]; _snapshots=[NSMutableArray new];
        __weak typeof(self) weakSelf=self;
        _monitor=[[HBFocusMonitor alloc] initWithReader:_reader deadline:2 scheduler:^(NSTimeInterval delay,dispatch_block_t block) { [weakSelf.timers addObject:[block copy]]; }];
        _monitor.onChange=^(NSDictionary *snapshot) { [weakSelf.snapshots addObject:snapshot]; };
        [_monitor start];
    } return self;
}
@end

static NSDictionary *HBTestFocus(NSString *identifier) { return @{@"available":@YES,@"active":@(identifier.length>0),@"identifier":identifier ?: @"",@"name":identifier ?: @""}; }
static void HBDeliver(NSMutableArray *calls,NSUInteger index,NSDictionary *result) { void (^block)(NSDictionary *)=calls[index]; block(result); }
static void HBFire(NSMutableArray *calls,NSUInteger index) { dispatch_block_t block=calls[index]; block(); }

static void HBRunFocusChecks(void (^check)(BOOL,NSString *)) {
    NSDictionary *work=HBTestFocus(@"fixture.work"), *home=HBTestFocus(@"fixture.home"), *off=HBTestFocus(nil);
    NSDictionary *error=@{@"issue":@{@"status":@"query-failed",@"error":@{@"domain":@"BSServiceConnectionErrorDomain",@"code":@3,@"description":@"XPC reply failed"}}};
    HBFocusFixture *f=[HBFocusFixture new];
    check(![f.monitor.snapshot[@"available"] boolValue] && f.reader.states.count==1,@"Focus starts unavailable with one read");
    HBDeliver(f.reader.states,0,work);
    check([f.monitor.snapshot[@"identifier"] isEqual:@"fixture.work"] && f.reader.catalogs.count==1 && f.reader.registrations.count==1,@"Valid state publishes before optional services finish");
    HBDeliver(f.reader.registrations,0,@{@"liveUpdates":@YES});
    check(f.reader.states.count==2,@"Observer registration triggers a fresh read to close the initial gap");
    HBFire(f.timers,0); // Deadline for completed query A while B is still pending.
    check([f.monitor.snapshot[@"available"] boolValue],@"Completed query deadline cannot invalidate a newer query");
    HBDeliver(f.reader.states,1,home);
    check([f.monitor.snapshot[@"identifier"] isEqual:@"fixture.home"],@"Post-registration refresh selects the current mode");
    HBFire(f.timers,1); HBFire(f.timers,2); // Observer done; catalog still pending.
    check([f.monitor.snapshot[@"available"] boolValue] && [f.monitor.snapshot[@"liveUpdates"] boolValue] && [f.monitor.snapshot[@"diagnostics"][@"catalog"][@"status"] isEqual:@"timeout"],@"Catalog timeout preserves the current mode and live updates");
    HBDeliver(f.reader.catalogs,0,@{@"modes":@[@{@"id":@"late",@"name":@"Late"}]});
    check([f.monitor.snapshot[@"modes"] count]==1 && [f.monitor.snapshot[@"modes"][0][@"id"] isEqual:@"fixture.home"],@"Late catalog result is ignored while the actual current mode stays linkable");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBFire(f.timers,0);
    check([f.monitor.snapshot[@"diagnostics"][@"state"][@"status"] isEqual:@"timeout"],@"Current read deadline publishes an explicit unavailable state");
    for (NSUInteger i=0;i<100;i++) [f.monitor refresh];
    check(f.reader.states.count==1,@"One hundred refreshes cannot pile up blocked reads");
    HBDeliver(f.reader.states,0,work);
    check(![f.monitor.snapshot[@"available"] boolValue] && f.reader.states.count==2,@"Late state is discarded and coalesced refresh starts exactly once");
    HBDeliver(f.reader.states,1,home);
    check([f.monitor.snapshot[@"identifier"] isEqual:@"fixture.home"],@"A new successful read recovers after timeout");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBFire(f.timers,0); HBDeliver(f.reader.states,0,work);
    check(![f.monitor.snapshot[@"available"] boolValue] && f.reader.states.count==1,@"Late reply alone does not silently recover or retry an expired request");
    [f.monitor refresh]; HBDeliver(f.reader.states,1,off);
    check([f.monitor.snapshot[@"available"] boolValue] && ![f.monitor.snapshot[@"active"] boolValue],@"Explicit refresh can recover to a verified Focus-off state");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,work); HBDeliver(f.reader.registrations,0,@{@"liveUpdates":@YES}); HBDeliver(f.reader.states,1,work);
    HBFire(f.reader.updates,0); HBFire(f.reader.updates,0);
    NSUInteger before=f.snapshots.count; HBDeliver(f.reader.states,2,home);
    check(f.snapshots.count==before && f.reader.states.count==4,@"Update arriving during a query suppresses that superseded reply");
    HBDeliver(f.reader.states,3,off);
    check([f.monitor.snapshot[@"available"] boolValue] && ![f.monitor.snapshot[@"active"] boolValue] && ![f.monitor.snapshot[@"identifier"] length],@"Newest reply clears the old identifier when Focus turns off");
    [f.monitor stop]; before=f.reader.states.count; HBFire(f.reader.updates,0);
    check(f.reader.states.count==before,@"Stopped listener events cannot start reads");

    f=[HBFocusFixture new]; [f.monitor stop]; [f.monitor start]; HBFire(f.timers,0);
    check([f.monitor.snapshot[@"diagnostics"][@"state"][@"status"] isEqual:@"checking"],@"Old session deadline cannot time out a reopened session");
    HBFire(f.timers,1);
    check([f.monitor.snapshot[@"diagnostics"][@"state"][@"status"] isEqual:@"timeout"] && f.reader.states.count==1,@"Reopening a blocked service has its own deadline and no extra worker");
    HBDeliver(f.reader.states,0,work); HBDeliver(f.reader.states,1,home);
    check([f.monitor.snapshot[@"identifier"] isEqual:@"fixture.home"],@"Old session reply is discarded before reopened session recovers");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,error);
    check(![f.monitor.snapshot[@"available"] boolValue] && f.reader.registrations.count==0 && f.reader.catalogs.count==0,@"Failed state read makes no optional service requests");
    check([HBFocusDiagnosticSummary(f.monitor.snapshot) containsString:@"BSServiceConnectionErrorDomain (3)"] && ![f.monitor.snapshot[@"status"] containsString:@"Focus is off"],@"Diagnostics preserve error details without equating unavailable with Focus off");
    NSMutableDictionary *library=HBDefaultLibrary(@"sea").mutableCopy;
    library[@"profiles"]=@[HBNormalizeProfile(@{@"id":@"default",@"name":@"Everyday"}),HBNormalizeProfile(@{@"id":@"work",@"name":@"Work"})];
    library[@"automaticFocus"]=@YES; library[@"focusOptInVersion"]=@1; library[@"bindings"]=@{@"fixture.work":@"work"};
    check([HBResolvedProfile(library,f.monitor.snapshot)[@"id"] isEqual:@"default"] && [library[@"bindings"] count]==1,@"Service failure selects the saved default without deleting its Focus links");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,@{@"available":@YES,@"active":@YES,@"identifier":@""});
    check(![f.monitor.snapshot[@"available"] boolValue] && [f.monitor.snapshot[@"diagnostics"][@"state"][@"status"] isEqual:@"missing-identifier"],@"An active Focus without an identifier cannot select a named profile");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,work); HBDeliver(f.reader.registrations,0,error); HBDeliver(f.reader.catalogs,0,error);
    check([f.monitor.snapshot[@"available"] boolValue] && ![f.monitor.snapshot[@"liveUpdates"] boolValue] && [f.monitor.snapshot[@"modes"] count]==1,@"Optional service errors keep the exact current mode usable");
    [f.monitor refresh]; HBDeliver(f.reader.states,1,error);
    check(![f.monitor.snapshot[@"available"] boolValue] && [f.monitor.snapshot[@"modes"] count]==0 && ![f.monitor.snapshot[@"identifier"] length],@"A later state failure clears stale current-mode data");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,work); HBFire(f.timers,1);
    HBDeliver(f.reader.registrations,0,@{@"liveUpdates":@YES}); before=f.reader.states.count; HBFire(f.reader.updates,0);
    check(![f.monitor.snapshot[@"liveUpdates"] boolValue] && f.reader.states.count==before,@"Late observer registration is removed and cannot emit refreshes");
    [f.monitor stop];

    f=[HBFocusFixture new]; HBDeliver(f.reader.states,0,work); [f.monitor stop]; [f.monitor start]; HBDeliver(f.reader.states,1,home);
    check(f.reader.registrations.count==1 && f.reader.catalogs.count==1,@"Reopening keeps optional requests bounded while old requests are pending");
    HBDeliver(f.reader.registrations,0,@{@"liveUpdates":@YES}); HBDeliver(f.reader.catalogs,0,@{@"modes":@[]});
    check(f.reader.registrations.count==2 && f.reader.catalogs.count==2,@"Old optional completions unlock exactly one attempt in the new session");
    before=f.reader.states.count; HBFire(f.reader.updates,0);
    check(f.reader.states.count==before,@"Old observer cannot refresh a new session");
    HBDeliver(f.reader.registrations,1,@{@"liveUpdates":@YES}); HBDeliver(f.reader.states,2,home);
    NSMutableArray *input=[NSMutableArray new]; for(NSUInteger i=0;i<40;i++) [input addObject:@{@"id":[NSString stringWithFormat:@"mode.%lu",(unsigned long)i],@"name":@"Mode"}];
    HBDeliver(f.reader.catalogs,1,@{@"modes":input});
    check([f.monitor.snapshot[@"modes"] count]==32 && [f.monitor.snapshot[@"modes"][0][@"id"] isEqual:@"fixture.home"],@"Mode discovery is bounded and prioritizes the actual current mode");
    [f.monitor stop]; before=f.snapshots.count; HBFire(f.timers,f.timers.count-1);
    check(f.snapshots.count==before,@"No pending deadline publishes after stop");
    check(f.reader.cancellations>0,@"Stopping a monitor cancels queued reads");

    // Run the production queue cancellation path, with queues suspended before
    // scheduling work. A cancelled request returns before loading any service.
    id<HBFocusReading> reader=[NSClassFromString(@"HBDNDFocusReader") new];
    for (NSString *channel in @[@"stateQueue",@"modesQueue",@"updatesQueue"]) {
        dispatch_queue_t queue=[(id)reader valueForKey:channel]; dispatch_suspend(queue);
        dispatch_semaphore_t done=dispatch_semaphore_create(0); __block NSDictionary *reply;
        void (^complete)(NSDictionary *)=^(NSDictionary *result){reply=result; dispatch_semaphore_signal(done);};
        if ([channel isEqual:@"stateQueue"]) [reader readState:complete];
        else if ([channel isEqual:@"modesQueue"]) [reader readModes:complete];
        else [reader beginUpdates:^{} completion:complete];
        [reader cancelPendingReads]; [reader endUpdates]; dispatch_resume(queue);
        BOOL completed=dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0;
        check(completed && [reply[@"issue"][@"status"] isEqual:@"cancelled"],[NSString stringWithFormat:@"Queued %@ is cancelled before any system service call",channel]);
    }
}
