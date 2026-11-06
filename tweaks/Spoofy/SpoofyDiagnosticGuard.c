#include "SpoofyDiagnosticGuard.h"
#include <limits.h>
static _Thread_local unsigned depth;
void SpoofyGuardEnter(void) { if (depth != UINT_MAX) ++depth; }
bool SpoofyGuardLeave(void) {
    if (!depth || depth == UINT_MAX) return false;
    --depth;
    return true;
}
bool SpoofyGuardIsActive(void) { return depth != 0; }
