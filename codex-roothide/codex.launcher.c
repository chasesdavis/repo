#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef OG_PAYLOAD_URL
#define OG_PAYLOAD_URL "https://chasesdavis.github.io/repo/payloads/codex-0.155.1.tar.lzma"
#endif

extern char **environ;

#ifndef OG_PROGRAM
#error OG_PROGRAM must name the packaged executable
#endif
#ifndef OG_STATIC_PREFIX
#define OG_STATIC_PREFIX ""
#endif

typedef const char *(*libroot_prefix_function)(void);

static int join_path(char output[PATH_MAX], const char *prefix, const char *suffix) {
    int length = snprintf(output, PATH_MAX, "%s%s", prefix, suffix);
    return length > 0 && length < PATH_MAX;
}

static int is_jbrand_value(unsigned long long value) {
    unsigned char check = (unsigned char)((value >> 8) ^ (value >> 16) ^ (value >> 24) ^
                                          (value >> 32) ^ (value >> 40) ^ (value >> 48) ^
                                          (value >> 56));
    return check == (unsigned char)value;
}

static int is_jbroot_name(const char *name) {
    static const char marker[] = ".jbroot-";
    const size_t marker_length = sizeof(marker) - 1;
    char *end = NULL;
    if (!name || strlen(name) != marker_length + 16) return 0;
    if (strncmp(name, marker, marker_length) != 0) return 0;
    unsigned long long value = strtoull(name + marker_length, &end, 16);
    return end && *end == '\0' && is_jbrand_value(value);
}

static int payload_exists(const char *prefix) {
    char path[PATH_MAX];
    return join_path(path, prefix, "/usr/libexec/" OG_PROGRAM "/" OG_PROGRAM) && access(path, X_OK) == 0;
}

static int store_prefix(char *dest, size_t dest_size, const char *prefix) {
    size_t length;
    if (!prefix || prefix[0] != '/') return 0;
    length = strlen(prefix);
    while (length > 1 && prefix[length - 1] == '/') length--;
    if (length >= dest_size) return 0;
    memcpy(dest, prefix, length);
    dest[length] = 0;
    return 1;
}

static int prefix_from_executable(char *dest, size_t dest_size) {
    char executable[PATH_MAX];
    char real[PATH_MAX];
    char link_path[PATH_MAX];
    char linked[PATH_MAX];
    uint32_t size = sizeof(executable);
    char *slash;
    if (_NSGetExecutablePath(executable, &size) != 0) return 0;
    if (!realpath(executable, real)) return 0;
    slash = strrchr(real, '/');
    if (!slash || slash == real) return 0;
    *slash = 0;
    if (snprintf(link_path, sizeof(link_path), "%s/.jbroot", real) < (int)sizeof(link_path) &&
        realpath(link_path, linked) && store_prefix(dest, dest_size, linked)) {
        return 1;
    }
    for (;;) {
        const char *name = strrchr(real, '/');
        name = name ? name + 1 : real;
        if (is_jbroot_name(name) && store_prefix(dest, dest_size, real)) return 1;
        slash = strrchr(real, '/');
        if (!slash || slash == real) break;
        *slash = 0;
    }
    return 0;
}

static int prefix_from_libroot(char *dest, size_t dest_size) {
    static const char *libraries[] = {
        "@executable_path/.jbroot/usr/lib/libroot.dylib",
        "@executable_path/../lib/libroot.dylib",
    };
    for (size_t index = 0; index < sizeof(libraries) / sizeof(libraries[0]); index++) {
        void *handle = dlopen(libraries[index], RTLD_NOW | RTLD_LOCAL);
        libroot_prefix_function get_prefix;
        const char *prefix;
        if (!handle) continue;
        get_prefix = (libroot_prefix_function)dlsym(handle, "libroot_get_jbroot_prefix");
        prefix = get_prefix ? get_prefix() : NULL;
        if (prefix && store_prefix(dest, dest_size, prefix)) return 1;
    }
    return 0;
}

static const char *bootstrap_prefix(void) {
    static char resolved[PATH_MAX];
    const char *configured = OG_STATIC_PREFIX;
    if (configured[0]) return configured;
    if (prefix_from_executable(resolved, sizeof(resolved))) return resolved;
    if (prefix_from_libroot(resolved, sizeof(resolved))) return resolved;
    return NULL;
}

static void configure_environment(const char *prefix) {
    const char *current = getenv("PATH");
    char *path = NULL;
    if (asprintf(&path, "%s/usr/local/bin:%s/usr/bin:%s/bin:%s/usr/sbin:%s/sbin%s%s",
                 prefix, prefix, prefix, prefix, prefix,
                 current && current[0] ? ":" : "", current && current[0] ? current : "") >= 0) {
        setenv("PATH", path, 1);
        free(path);
    }
    const char *shell = getenv("SHELL");
    char candidate[PATH_MAX];
    if (shell && (strncmp(shell, "/bin/", 5) == 0 || strncmp(shell, "/usr/bin/", 9) == 0) &&
        join_path(candidate, prefix, shell)) setenv("SHELL", candidate, 1);
    if (!getenv("SSL_CERT_FILE")) {
        const char *certificates[] = {"/etc/ssl/cert.pem", "/etc/ssl/certs/ca-certificates.crt"};
        for (size_t index = 0; index < 2; index++) {
            if (join_path(candidate, prefix, certificates[index]) && access(candidate, R_OK) == 0) {
                setenv("SSL_CERT_FILE", candidate, 1);
                break;
            }
        }
    }
    if (!getenv("BROWSER") && join_path(candidate, prefix, "/usr/bin/uiopen") &&
        access(candidate, X_OK) == 0) setenv("BROWSER", candidate, 1);
}

static int tool_path(char output[PATH_MAX], const char *prefix, const char *name) {
    const char *directories[] = {"/usr/bin/", "/bin/", "/usr/local/bin/"};
    for (size_t index = 0; index < sizeof(directories) / sizeof(directories[0]); index++) {
        if (snprintf(output, PATH_MAX, "%s%s%s", prefix, directories[index], name) < PATH_MAX &&
            access(output, X_OK) == 0) {
            return 1;
        }
    }
    return 0;
}

static int run_tool(const char *path, char *const argv[]) {
    pid_t pid;
    int status;
    if (posix_spawn(&pid, path, NULL, NULL, argv, environ) != 0) return 0;
    if (waitpid(pid, &status, 0) < 0) return 0;
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static int ensure_payload(const char *prefix) {
    char directory[PATH_MAX];
    char archive[PATH_MAX];
    char entitlements[PATH_MAX];
    char binary[PATH_MAX];
    char host[PATH_MAX];
    char curl_bin[PATH_MAX];
    char shell_bin[PATH_MAX];
    char ldid_bin[PATH_MAX];
    char link_path[PATH_MAX];
    char script[PATH_MAX * 3];
    char sign_argument[PATH_MAX + 3];
    if (payload_exists(prefix)) return 1;
    if (!join_path(directory, prefix, "/usr/libexec/" OG_PROGRAM)) return 0;
    if (!join_path(archive, prefix, "/usr/libexec/" OG_PROGRAM "/payload.tar.lzma")) return 0;
    if (!join_path(entitlements, prefix, "/usr/libexec/" OG_PROGRAM "/codex.entitlements")) return 0;
    if (!join_path(binary, prefix, "/usr/libexec/" OG_PROGRAM "/codex")) return 0;
    if (!join_path(host, prefix, "/usr/libexec/" OG_PROGRAM "/codex-code-mode-host")) return 0;
    fprintf(stderr, "codex: downloading the RootHide bootstrap build\n");
    fflush(stderr);
    if (!tool_path(curl_bin, prefix, "curl")) {
        fprintf(stderr, "codex: curl is not installed in the bootstrap\n");
        return 0;
    }
    char *curl_argv[] = {curl_bin, "-fL", "--retry", "3", "-o", archive, OG_PAYLOAD_URL, NULL};
    if (!run_tool(curl_bin, curl_argv)) {
        fprintf(stderr, "codex: download failed\n");
        unlink(archive);
        return 0;
    }
    if (!tool_path(shell_bin, prefix, "sh")) {
        fprintf(stderr, "codex: sh is not installed in the bootstrap\n");
        return 0;
    }
    if (snprintf(script, sizeof(script),
                 "cd '%s' && (lzma -dc payload.tar.lzma || xz -dc -F lzma payload.tar.lzma) | tar -xf - && "
                 "rm -f payload.tar.lzma && chmod 755 codex codex-code-mode-host",
                 directory) >= (int)sizeof(script)) {
        return 0;
    }
    char *shell_argv[] = {shell_bin, "-c", script, NULL};
    if (!run_tool(shell_bin, shell_argv)) {
        fprintf(stderr, "codex: could not unpack the download\n");
        return 0;
    }
    if (tool_path(ldid_bin, prefix, "ldid") &&
        snprintf(sign_argument, sizeof(sign_argument), "-S%s", entitlements) < (int)sizeof(sign_argument)) {
        char *sign_codex[] = {ldid_bin, sign_argument, binary, NULL};
        char *sign_host[] = {ldid_bin, sign_argument, host, NULL};
        run_tool(ldid_bin, sign_codex);
        run_tool(ldid_bin, sign_host);
    }
    if (snprintf(link_path, sizeof(link_path), "%s/.jbroot", directory) < (int)sizeof(link_path)) {
        unlink(link_path);
        symlink(prefix, link_path);
    }
    return payload_exists(prefix);
}

int main(int argc, char **argv) {
    (void)argc;
    const char *prefix = bootstrap_prefix();
    if (!prefix) {
        fprintf(stderr, "%s: cannot find the RootHide bootstrap from this executable\n", OG_PROGRAM);
        return 127;
    }
    configure_environment(prefix);
    if (!ensure_payload(prefix)) return 1;
    char executable[PATH_MAX];
    if (!join_path(executable, prefix, "/usr/libexec/" OG_PROGRAM "/" OG_PROGRAM)) return 127;
    argv[0] = executable;
    execv(executable, argv);
    int error = errno;
    fprintf(stderr, "%s: cannot execute %s: %s\n", OG_PROGRAM, executable, strerror(error));
    return error == ENOENT ? 127 : 126;
}
