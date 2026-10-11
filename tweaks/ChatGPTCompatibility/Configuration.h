#import <Foundation/Foundation.h>
#import <roothide.h>
#import <notify.h>
#include <time.h>

#define CGC_SETTINGS_NOTIFICATION "com.chasedavis.chatgptcompat/settingsChanged"
#define CGC_STATUS_APPSTORED_LOADED "com.chasedavis.chatgptcompat/status/appstoredLoaded"
#define CGC_STATUS_STORE_PROCESS_LOADED "com.chasedavis.chatgptcompat/status/storeProcessLoaded"
#define CGC_STATUS_STORE_HOOKED "com.chasedavis.chatgptcompat/status/storeHooked"
#define CGC_STATUS_STORE_MATCHED "com.chasedavis.chatgptcompat/status/storeMatched"
#define CGC_STATUS_UI_HOOKED "com.chasedavis.chatgptcompat/status/uiHooked"
#define CGC_STATUS_UI_MATCHED "com.chasedavis.chatgptcompat/status/uiMatched"
#define CGC_STATUS_INSTALLD_LOADED "com.chasedavis.chatgptcompat/status/installdLoaded"
#define CGC_STATUS_INSTALLER_HOOKED "com.chasedavis.chatgptcompat/status/installerHooked"
#define CGC_STATUS_INSTALLER_MATCHED "com.chasedavis.chatgptcompat/status/installerMatched"

static inline NSString *CGCPreferencesPath(void) {
    return jbroot(@"/var/mobile/Library/Preferences/com.chasedavis.chatgptcompat.plist");
}

static inline void CGCMarkStatus(const char *name) {
    int token = NOTIFY_TOKEN_INVALID;
    if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return;
    notify_set_state(token, (uint64_t)time(NULL));
    notify_post(name);
    notify_cancel(token);
}

static inline uint64_t CGCReadStatus(const char *name) {
    int token = NOTIFY_TOKEN_INVALID;
    uint64_t state = 0;
    if (notify_register_check(name, &token) == NOTIFY_STATUS_OK) {
        notify_get_state(token, &state);
        notify_cancel(token);
    }
    return state;
}
