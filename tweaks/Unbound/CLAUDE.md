# AGENTS.md

## Overview

Unbound is an iOS jailbreak tweak and resource bundle built with GNU Make and Theos for Objective-C, Objective-C++, and Logos sources. The repository does not pin Theos, Xcode, GNU Make, or ldid versions. The documented package manager is Homebrew; exact versions are not provided.

## Commands

- Setup: not provided; install Xcode, Homebrew dependencies, and Theos as documented in `README.md`.
- Development: not provided.
- Build rootless: `THEOS_PACKAGE_SCHEME=rootless make package` (or `gmake` on macOS when GNU Make is installed as `gmake`).
- Build roothide: `THEOS_PACKAGE_SCHEME=roothide make package`.
- Local IPA flow: `./build-local.sh`.
- Test: not provided.
- Lint: not provided; use `git diff --check` for whitespace validation.

## Conventions

Reuse existing Makefile variables and Theos targets; keep source and comments in English. Example:

```make
$(TWEAK_NAME)_CCFLAGS = $(COMMON_FLAGS) -std=c++20
```

## Boundaries

- **NEVER** commit `.env` files, private keys, signing material, or credentials.
- **NEVER** edit generated packages, IPA files, repository indexes, or other build output as source.
- **NEVER** modify vendor or submodule contents from this repository.
- **NEVER** change production release configuration without tracing the release workflow.
- **ALWAYS** preserve submodule gitlinks and review generated files before cleanup.

## Dependencies

- roothide/Theos: build system and iOS packaging; version not provided.
- Xcode/iOS SDK: Apple compilation and signing tools; version not provided.
- GNU Make: executes the Makefile; version not provided.
- `ldid`: documented local signing dependency; version not provided.
- Git submodules: resource and extension inputs; revisions are pinned by gitlinks.

## Config

- `THEOS`: absolute path to a Theos checkout, for example `/path/to/theos`.
- `THEOS_PACKAGE_SCHEME`: package scheme, for example `rootless` or `roothide`.
- `UNBOUND_PK`: optional private signing key supplied through the environment; never store a real value here.

## Error Handling

Make targets fail on failed submodule initialization or packaging commands. Shell scripts print an error and exit for missing inputs, failed downloads, builds, patching, or packaging. Preserve these failures; do not hide them with unconditional fallbacks.

## Troubleshooting

- Empty submodules prevent the resource bundle and extensions from building; initialize them with the repository's existing Git workflow.
- GNU Make may be required as `gmake` on macOS; use the Homebrew `gnubin` PATH setup in `README.md`.
- A missing or wrong `THEOS` path prevents Make from loading Theos makefiles.
- `build-local.sh` requires a Discord IPA and may build or use `patcher-ios` plus extension submodules.
