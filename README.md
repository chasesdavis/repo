# Lumen

Free status bar pill for iOS 15 - 17 on roothide and rootful jailbreaks. No paid tier, no subscription, donations only.

Turn the status bar clock into a small capsule that shows one live value at a time. Long press cycles pills, tap opens a card. Nothing is sent anywhere; everything is read from public system APIs.

## Pills

- Time, date, battery
- Now playing with play, pause, next and previous
- Network throughput, free storage
- Countdown to a chosen date
- Quick message composer

Settings live in Settings -> Lumen: master switch, clock hiding, per-pill toggles, opacity, accent color and text scale. Changes apply instantly.

## Repo

Add to Sileo or Zebra:

    https://chasesdavis.github.io/repo/

Package id com.chasedavis.lumen. This repo ships Lumen only.

## Build

    export THEOS=~/theos
    ./scripts/build.sh       # builds the deb into repo/debs
    ./scripts/index-repo.sh  # regenerates Packages and Release

build.sh builds with THEOS_PACKAGE_SCHEME=roothide for arm64 and arm64e.

## Layout

- tweaks/Lumen - tweak sources, hooks and the Settings bundle
- repo - static APT/Sileo repo, published by GitHub Pages
- scripts - build and index helpers

## Notes

- The clock keeps its layout slot when hidden; it is only made transparent, so other status items never shift.
- MediaRemote is resolved with dlsym, so there is no private framework in the link line.
- Now playing is polled on a background queue and cached, so the pill never blocks the main thread.

## Donate

paypal.me/chasesdavis

## License

MIT.
