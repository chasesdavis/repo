# LowerInstall

RootHide / rootless port of [julioverne/LowerInstall](https://github.com/julioverne/LowerInstall) for iOS 15–17 Bootstrap.

Hooks `installd` compatibility checks and spoofs App Store (`appstored` / `itunesstored`) User-Agent version/device so you can install apps that declare a higher minimum OS.

## Settings

Settings → LowerInstall

- Enabled
- Spoof iOS Version (e.g. `18.2`)
- Spoof Device machine (e.g. `iPhone17,1`)

After changes: reboot or `killall -9 installd appstored itunesstored`.

## Notes

- Not a signing/DRM bypass — only version/device compatibility gates.
- App may still fail at runtime if it needs a newer OS SDK.
- On RootHide Bootstrap, ensure daemon injection is available for `installd` / `appstored`.

## Credits

Original by julioverne. iOS 17 / RootHide packaging by Chase Davis.
