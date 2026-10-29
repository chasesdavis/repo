#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSString *const LumenDomain;
extern NSString *const LumenPrefsChangedNotification;

BOOL LumenEnabled(void);
BOOL LumenHideClock(void);
NSArray<NSString *> *LumenEnabledPills(void);
NSString *LumenDefaultPill(void);
BOOL LumenPillEnabled(NSString *pill);
BOOL LumenUseCustomColor(void);
UIColor *LumenAccentColor(void);
CGFloat LumenFontScale(void);
CGFloat LumenPillOpacity(void);
NSDate *LumenCountdownDate(void);
void LumenSetPref(NSString *key, id value);
void LumenReloadPrefs(void);

#ifdef __cplusplus
}
#endif
