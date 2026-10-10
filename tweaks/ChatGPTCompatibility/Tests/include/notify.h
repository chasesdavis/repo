#pragma once
#include <stdint.h>
#define NOTIFY_STATUS_OK 0
#define NOTIFY_TOKEN_INVALID -1
static inline uint32_t notify_register_check(const char *name, int *token) { *token = 1; return NOTIFY_STATUS_OK; }
static inline uint32_t notify_set_state(int token, uint64_t state) { return NOTIFY_STATUS_OK; }
static inline uint32_t notify_get_state(int token, uint64_t *state) { *state = 0; return NOTIFY_STATUS_OK; }
static inline uint32_t notify_post(const char *name) { return NOTIFY_STATUS_OK; }
static inline uint32_t notify_cancel(int token) { return NOTIFY_STATUS_OK; }
