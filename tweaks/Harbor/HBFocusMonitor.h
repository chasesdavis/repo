#import <Foundation/Foundation.h>

// Async boundary for the read-only system service. Tests supply delayed replies
// here, exercising the same coordinator and deadlines as the shipping tweak.
@protocol HBFocusReading <NSObject>
- (void)readState:(void (^)(NSDictionary *result))completion;
- (void)readModes:(void (^)(NSDictionary *result))completion;
- (void)beginUpdates:(void (^)(void))update completion:(void (^)(NSDictionary *result))completion;
- (void)endUpdates;
- (void)cancelPendingReads;
@end

NSString *HBFocusDiagnosticSummary(NSDictionary *snapshot);
NSDictionary *HBFocusDisabledSnapshot(void);

// Read-only adapter. Snapshots contain only identifiers/names returned by iOS.
// No guessed built-in identifiers, entitlement changes, or Focus activation.
@interface HBFocusMonitor : NSObject
@property (nonatomic, copy) void (^onChange)(NSDictionary *snapshot);
@property (nonatomic, copy, readonly) NSDictionary *snapshot;
- (instancetype)initWithReader:(id<HBFocusReading>)reader deadline:(NSTimeInterval)deadline
                    scheduler:(void (^)(NSTimeInterval delay, dispatch_block_t block))scheduler;
- (void)start;
- (void)stop;
- (void)refresh;
@end
