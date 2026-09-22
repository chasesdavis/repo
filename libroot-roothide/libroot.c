#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>

/*
 * libroot for an iOS 17 RootHide bootstrap.
 *
 * RootHide does not ship opa334's /usr/lib/libroot.dylib. This dylib is that
 * file. It lives at <jbroot>/usr/lib/libroot.dylib and reports the physical
 * bootstrap root, which is what non-vroot programs (the Codex launcher among
 * them) can actually open and exec.
 */

#define EXPORT __attribute__((visibility("default")))

static char jbroot_prefix[PATH_MAX];
static char boot_uuid[37] = "00000000-0000-0000-0000-000000000000";

static int is_jbrand_value(unsigned long long value) {
    unsigned char check = (unsigned char)((value >> 8) ^ (value >> 16) ^ (value >> 24) ^
                                          (value >> 32) ^ (value >> 40) ^ (value >> 48) ^
                                          (value >> 56));
    return check == (unsigned char)value;
}

static int is_jbroot_name(const char *name) {
    static const char prefix[] = ".jbroot-";
    const size_t prefix_length = sizeof(prefix) - 1;
    char *end = NULL;
    unsigned long long value;
    if (!name || strlen(name) != prefix_length + 16) return 0;
    if (strncmp(name, prefix, prefix_length) != 0) return 0;
    value = strtoull(name + prefix_length, &end, 16);
    if (!end || *end != '\0') return 0;
    return is_jbrand_value(value);
}

static const char *base_name(const char *path) {
    const char *slash = strrchr(path, '/');
    return slash ? slash + 1 : path;
}

static void remember_jbroot(const char *path) {
    size_t length = strlen(path);
    const char *name;
    char brand[17];
    while (length > 1 && path[length - 1] == '/') length--;
    if (length == 0 || length >= sizeof(jbroot_prefix) || path[0] != '/') return;
    memcpy(jbroot_prefix, path, length);
    jbroot_prefix[length] = 0;
    name = base_name(jbroot_prefix);
    if (!is_jbroot_name(name)) return;
    memcpy(brand, name + 8, 16);
    brand[16] = 0;
    snprintf(boot_uuid, sizeof(boot_uuid), "%.8s-%.4s-%.4s-%.4s-%.12s",
             brand, brand + 8, brand + 12, brand, brand + 4);
}

static void discover_from_self(void) {
    Dl_info info;
    char real[PATH_MAX];
    char walk[PATH_MAX];
    static const char suffix[] = "/usr/lib/libroot.dylib";
    const size_t suffix_length = sizeof(suffix) - 1;
    if (dladdr((const void *)discover_from_self, &info) == 0 || !info.dli_fname) return;
    if (!realpath(info.dli_fname, real)) return;
    if (strlen(real) > suffix_length && strcmp(real + strlen(real) - suffix_length, suffix) == 0) {
        real[strlen(real) - suffix_length] = 0;
        if (is_jbroot_name(base_name(real))) {
            remember_jbroot(real);
            return;
        }
    }
    if (!realpath(info.dli_fname, walk)) return;
    for (;;) {
        char *slash = strrchr(walk, '/');
        if (!slash || slash == walk) break;
        *slash = 0;
        if (is_jbroot_name(base_name(walk))) {
            remember_jbroot(walk);
            return;
        }
    }
}

__attribute__((constructor)) static void libroot_init(void) {
    discover_from_self();
}

static char *finish_path(char *resolved, const char *value) {
    if (!resolved) {
        resolved = malloc(PATH_MAX);
        if (!resolved) return NULL;
    }
    if (strlcpy(resolved, value, PATH_MAX) >= PATH_MAX) return NULL;
    return resolved;
}

EXPORT const char *libroot_get_jbroot_prefix(void) {
    return jbroot_prefix;
}

EXPORT const char *libroot_get_root_prefix(void) {
    /* Physical rootfs. Bootstrap tools see this as /rootfs only inside vroot. */
    return "";
}

EXPORT const char *libroot_get_boot_uuid(void) {
    return boot_uuid;
}

EXPORT char *libroot_jbrootpath(const char *path, char *resolved) {
    char joined[PATH_MAX];
    size_t prefix_length;
    if (!path) return NULL;
    if (path[0] != '/' || jbroot_prefix[0] == '\0') return finish_path(resolved, path);
    prefix_length = strlen(jbroot_prefix);
    if (strncmp(path, jbroot_prefix, prefix_length) == 0 &&
        (path[prefix_length] == '/' || path[prefix_length] == '\0')) {
        return finish_path(resolved, path);
    }
    if (snprintf(joined, sizeof(joined), "%s%s", jbroot_prefix, path) >= (int)sizeof(joined)) return NULL;
    return finish_path(resolved, joined);
}

EXPORT char *libroot_rootfspath(const char *path, char *resolved) {
    size_t prefix_length;
    if (!path) return NULL;
    prefix_length = strlen(jbroot_prefix);
    if (path[0] == '/' && prefix_length > 0 && strncmp(path, jbroot_prefix, prefix_length) == 0 &&
        (path[prefix_length] == '/' || path[prefix_length] == '\0')) {
        const char *stripped = path + prefix_length;
        if (stripped[0] == '\0') stripped = "/";
        return finish_path(resolved, stripped);
    }
    return finish_path(resolved, path);
}
