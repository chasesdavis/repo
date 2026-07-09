# iOS 17 Roothide Tweak Lab

This repo contains a first tranche of Bootstrap-compatible, roothide Theos tweaks plus a local static Sileo/APT repo.

## Tweaks

- AuraDock: dock glow and ambient dock styling.
- KineticBadges: animated notification badge changes.
- VelvetAlerts: softer notification/banner presentation.
- GhostDock: auto-hiding dock with quick reveal.
- IconLabelPro: cleaner icon label typography and dock-label hiding.
- VolumeRibbon: compact volume HUD ribbon styling.
- SilentToast: small toast when silent mode changes.
- ChargingAurora: charging edge glow on SpringBoard.
- SpotifyReframe: Spotify-only UI redesign with glass cards, tuned artwork, player chrome, and Settings controls.
- LowerInstall: install apps meant for newer iOS (installd + App Store version spoof; julioverne port for RootHide/iOS 15–17).

Premium suite:

- IslandCommand Pro
- DockShelf Pro
- FocusLens Pro
- NotificationForge
- ControlCenter Studio
- HomeScreenZen Pro
- ApertureFX
- StatusLab Pro
- LockScreen Atmosphere
- SpringBoard Automations

The premium packages are versioned `1.0.4-1` and include PreferenceLoader panes in Settings. They install disabled by default so they can be enabled and tested one at a time.

## Build All

```bash
cd "/Users/chase/ios17 tweaks"
./scripts/build-all.sh
./scripts/package-repo.sh
./scripts/audit-tweaks.sh
```

Built `.deb` files are copied into `repo/debs/`. Static repo metadata is written to `repo/`.

Theos rejects project paths containing spaces, so `build-all.sh` stages each tweak into `/tmp/ios17_tweak_lab_build/` before compiling and then copies packages back.

## Install

Manual install fallback:

1. Copy a `.deb` from `repo/debs/` to the iPhone.
2. Open it with Sileo or Zebra.
3. Install, then respring or run `sbreload`.

Static repo flow:

1. Host the `repo/` folder on any static server.
2. Add that URL as a source in Sileo.
3. Refresh sources and install packages.

Published repo URL:

```text
https://chasesdavis.github.io/ios17-tweaks-sileo-repo/
```

For local network testing, serve the folder from the Mac:

```bash
cd "/Users/chase/ios17 tweaks"
./scripts/serve-repo.sh 8088
```

Then add the printed `http://<mac-lan-ip>:8088/` URL to Sileo.

## Publishing to Sileo (important)

GitHub Pages serves the **`gh-pages` branch**, not `main`.

After building packages into `repo/`:

```bash
./scripts/package-repo.sh
git add -A && git commit -m "..." && git push origin main
./scripts/publish-pages.sh   # syncs repo/ → gh-pages
```

Sileo source URL:

```text
https://chasesdavis.github.io/ios17-tweaks-sileo-repo/
```

If a package is on `main` but missing in Sileo, you forgot `publish-pages.sh`.

