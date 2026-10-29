# Lumen

Theos + app repo: a free status bar pill (Lumen) and Aurora, a prebuilt APT package manager. Published as a static Sileo/APT repo on GitHub Pages.

## Commands

    export THEOS=~/theos
    ./scripts/build.sh       # builds repo/debs/com.chasedavis.lumen_*.deb
    ./scripts/index-repo.sh  # regenerates Packages, Release and dists
    make -C tweaks/Lumen clean

Index before committing any repo change; Pages deploys from repo/ only.

## Conventions

Hooks live in one %hook block per class, gated by LumenEnabled(). All mutable prefs read through LumenPrefs.h so the domain and notify name stay in one place.

    static void LumenStyleClock(id target) {
        UIView *view = (UIView *)target;
        BOOL hide = LumenEnabled() && LumenHideClock();
        view.alpha = hide ? 0.0 : 1.0;
    }

## Boundaries

- **NEVER** touch files outside the jailbreak prefix.
- **NEVER** commit a device IP, Apple ID or signing identity.
- **ALWAYS** keep repo/debs to these two packages; no strays.
- **ALWAYS** rebuild and reindex before pushing, so Packages matches debs.
- **IMPORTANT** the package must stay free; donations only.

## Dependencies

ElleKit (Logos hooks), PreferenceLoader (Settings bundle), PrivateFrameworks/Preferences (settings controller). MediaRemote is dlsym-resolved and needs no link dependency.

## Config

Prefs domain com.chasedavis.lumen, Darwin notification com.chasedavis.lumen/prefschanged, stored at /var/mobile/Library/Preferences/com.chasedavis.lumen.plist.

## Error Handling

Hooks pass through when the master switch is off. Missing providers render -- rather than blanking the pill. If the status bar window is not up yet, attach retries 40 times at 250 ms.

## Troubleshooting

- Nothing appears: confirm the package is enabled and respring once after install.
- Pill moves or clips: the clock must stay in the layout; keep hideClock on rather than removing the time item.
- No now playing text: MediaRemote only answers while a media session exists.
- Sileo shows a stale list: re-run ./scripts/index-repo.sh and refresh sources.
