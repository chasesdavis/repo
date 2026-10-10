#import <Foundation/Foundation.h>
#import <roothide.h>

#define CGC_SETTINGS_NOTIFICATION "com.chasedavis.chatgptcompat/settingsChanged"

static inline NSString *CGCPreferencesPath(void) {
    return jbroot(@"/var/mobile/Library/Preferences/com.chasedavis.chatgptcompat.plist");
}
