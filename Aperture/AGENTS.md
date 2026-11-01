# Aperture

Pure-SwiftUI iOS package manager for jailbroken devices. V1: store + install flow (browse, instant FTS5 search, package detail, download queue, install/upgrade/remove via apt-get/dpkg shell-out).

## Overview

Swift 5.9+, SwiftUI (no UIKit/AppKit), iOS 15.0+. SwiftPM workspace with two library targets (ApertureCore, ApertureUI) and one Xcode app target (Aperture). Backend shells out to on-device apt-get/dpkg via tsudo/sudo (Sileo-style launchd helper is a later upgrade). Search is SQLite FTS5 via SQLite.swift.

## Commands

```bash
swift build
swift test
```

## Conventions

- Layering: ApertureCore has zero UI deps. ApertureUI depends on ApertureCore. App target depends on both.
- Concurrency: repo/network/queue work in actors; UI reads pre-built view models on MainActor.
- Naming: value types are AperturePackage/ApertureRepo (avoid clashing with Foundation Package).

## Boundaries

- NEVER write outside /etc/apt/sources.list.d/aperture.list or dpkg db via the privileged helper.
- NEVER re-implement dpkg. Shell out to apt-get/dpkg.
- NEVER commit real device IPs, Apple IDs, or repo URLs containing private tokens.
- ALWAYS gate privileged shell-out behind the detected privilege helper (tsudo > sudo > none).

## Dependencies

- SQLite.swift 0.15.3+ - FTS5 full-text search index. Only dep outside Apple SDKs.

## Config

No env vars in V1. Runtime config lives in /etc/apt/sources.list.d/aperture.list and <Documents>/Aperture/repos.json.

## Error Handling

- Repo parse errors: skip malformed entries, keep valid ones.
- Search index errors: thrown to caller; UI shows empty state on failure.
- Install failures: InstallEngine retries up to maxAttempts (3), then surfaces .failed(reason) to the queue sheet.

## Troubleshooting

- swift build fails on SQLite.swift linking: ensure Xcode CLT are current.
- Search returns empty after repo add: index is in-memory and rebuilds per repo refresh.
- apt-get Permission denied on device: privilege helper detection failed.
- dpkg -l returns empty: not jailbroken, or dpkg db not at /var/lib/dpkg/status.

