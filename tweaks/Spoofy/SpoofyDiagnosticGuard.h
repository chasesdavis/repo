#ifndef SPOOFY_DIAGNOSTIC_GUARD_H
#define SPOOFY_DIAGNOSTIC_GUARD_H
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
void SpoofyGuardEnter(void);
bool SpoofyGuardLeave(void);
bool SpoofyGuardIsActive(void);
#ifdef __cplusplus
}
#endif
#endif
