#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Live value for a pill. Text is already formatted and safe to show.
@interface LumenReading : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, strong) UIColor *tint;
+ (instancetype)readingWithText:(NSString *)text symbol:(NSString *)symbol;
@end

/// One reading per enabled pill. Missing keys are simply absent.
NSDictionary<NSString *, LumenReading *> *LumenReadingsForPills(NSArray<NSString *> *pills,
                                                                NSDateFormatter *timeFormatter,
                                                                NSDateFormatter *dateFormatter);

/// Cached now-playing line, refreshed asynchronously so renders never block.
NSString *LumenCachedNowPlaying(void);
void LumenRefreshNowPlaying(void);

/// Media transport, used by the now-playing card.
BOOL LumenMediaAvailable(void);
void LumenMediaPlayPause(void);
void LumenMediaNext(void);
void LumenMediaPrevious(void);

/// Disk usage, formatted for display.
NSString *LumenStorageSummary(void);

/// Live network throughput since the last sample, formatted for display.
NSString *LumenNetworkSummary(void);
void LumenNetworkResetSampler(void);

/// Battery detail lines for the battery card.
NSArray<NSString *> *LumenBatteryDetails(void);

#ifdef __cplusplus
}
#endif
