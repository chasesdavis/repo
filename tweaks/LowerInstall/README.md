# LowerInstall 1.1

RootHide / rootless port of [julioverne/LowerInstall](https://github.com/julioverne/LowerInstall) for iOS 15–17.

## What it does

| Target | Action |
|--------|--------|
| **appstored** | Spoofs modern `User-Agent` (`iOS/18.4` style) so App Store may serve newer listings |
| **installd** | Relaxes min-OS / device family / thinning checks so IPAs can install |

## Setup (RootHide Bootstrap)

1. Install **LowerInstall** from this repo.
2. **Reboot** (or `killall -9 installd appstored` after install).
3. Settings → **LowerInstall**
   - Enabled: ON  
   - Spoof iOS Version: **`18.4`** (or higher — must be newer than your real iOS)  
   - Spoof Device: leave default machine unless App Store still blocks model  
4. Bootstrap App List: enable **App Store** if your build requires per-app injection.
5. Bootstrap 2.x should inject **installd** + **appstored** (they’re on the resign list).

## If it still fails

| Symptom | Likely cause |
|---------|----------------|
| App Store still says “requires iOS X” | SpoofVersion not high enough, or appstored not injected — reboot, set 18.4/99.0 |
| Download starts then install fails | installd not hooked — need daemon injection / full rootless JB |
| Install OK, app crashes on launch | App needs newer OS APIs — LowerInstall cannot fix runtime |
| No Settings pane | Install PreferenceLoader |

## Reality check

Apple often **does not host** an older binary. Spoofing may let you **purchase** or **see** the app; install can still fail if no compatible slice exists. For purchase-only workflows see [AppStoreTroller](https://github.com/mineek/appstoretroller).

## Credits

julioverne (original) · Chase Davis (1.1 RootHide port) · UA pattern notes from mineek/appstoretroller
