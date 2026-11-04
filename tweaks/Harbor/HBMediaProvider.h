#import <UIKit/UIKit.h>

@interface HBMediaSnapshot : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, strong) UIImage *artwork;
@property (nonatomic) BOOL hasSession;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL canSkip;
@property (nonatomic) BOOL available;
@end

// Main-thread lifecycle; media fetch and thumbnail decode are off the main thread.
@interface HBMediaProvider : NSObject
@property (nonatomic, copy) void (^onUpdate)(HBMediaSnapshot *snapshot);
- (void)start;
- (void)stop;
- (void)refresh;
- (BOOL)sendCommand:(int)command;
@end
