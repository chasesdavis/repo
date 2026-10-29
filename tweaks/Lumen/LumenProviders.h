#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

@interface LumenReading : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, strong) UIColor *tint;
+ (instancetype)readingWithText:(NSString *)text symbol:(NSString *)symbol;
@end

NSDictionary<NSString *, LumenReading *> *LumenReadingsForPills(NSArray<NSString *> *pills,
                                                                NSDateFormatter *timeFormatter,
                                                                NSDateFormatter *dateFormatter);

NSString *LumenCachedNowPlaying(void);
void LumenRefreshNowPlaying(void);

BOOL LumenMediaAvailable(void);
void LumenMediaPlayPause(void);
void LumenMediaNext(void);
void LumenMediaPrevious(void);

NSString *LumenStorageSummary(void);
NSString *LumenNetworkSummary(void);
void LumenNetworkResetSampler(void);

NSArray<NSString *> *LumenBatteryDetails(void);

// New providers for 10x feature set
NSString *LumenNextEventSummary(void);      // Next calendar event title + time
NSArray<NSString *> *LumenNextEventDetails(void);
NSString *LumenAlarmSummary(void);          // Next alarm or active timer countdown
NSArray<NSString *> *LumenAlarmDetails(void);
NSString *LumenWeatherSummary(void);       // Current temp + condition
NSArray<NSString *> *LumenWeatherDetails(void);
NSString *LumenUnlocksSummary(void);       // Today's unlock count
NSString *LumenMemorySummary(void);         // Used memory

#ifdef __cplusplus
}
#endif
