# Full-screen correction — beta3

The supplied 562 × 1218 JPEG was downloaded through the current Library materialization helper into a private local workspace and visually inspected. Harbor occupies roughly y=213…1004, with native background above/below and the shortcut row clipped at the lower boundary. The original user image is not copied into the repository.

**Installed-version qualification:** the screenshot does not display Harbor's package version, and the user has not yet confirmed the Sileo installed-version question. This report does not infer beta2 installation from publication timing. The code diagnosis below was independently reproduced using the exact published beta2 source at `1eb125a8e71db81a32fb5c45c61b930606cf6adb`.

## Root cause and reproduction

Beta2 makes `dashboard.view.frame = overlayContainerView.bounds` and adds the entire dashboard inside that container. The native module panel may be inset vertically, so its clipping boundary becomes Harbor's viewport. The original mock used a full-window panel and consequently could not expose this mistake. Putting All controls at the end of the same overflowing stack also made the escape action disappear below the initial viewport.

The replacement fixture uses a full-window native scroll/background surface and a module panel inset by 142 points at each end, matching the screenshot's approximate proportions. Published beta2 reproduces the cropped surface and fails nine of the 43 initial layout assertions. [beta2-layout-regression.json](beta2-layout-regression.json) records those failures.

## Correction

- Validate the existing host window, full-window `overlayScrollView`, native background, module hierarchy, and ABI. Unsupported layouts retain Apple's controls with a diagnostic; no clipping or window overrides force presentation.
- Put interactive content inside the full-window native scroll surface, preserving its native gesture ancestry. The smaller module panel remains unmodified. Scroll-offset changes update Harbor's viewport placement.
- Move only Harbor's noninteractive backdrop into `overlayBackgroundView`, so it fills the native background and follows its presentation. Native status/privacy/header views keep their order and interaction.
- Compute layout extents without inverting native presentation transforms. Content inherits those transforms instead of pinning itself against the animation or disappearing during a translation.
- Reserve window/host safe areas and the native status/privacy header. Empty protected regions pass touches through.
- Pin All controls above the home-indicator area; keep the cards in a separate scrolling region with a visible overflow indicator. Large text remains unscaled and scrollable.
- Restore native hidden state and remove both Harbor content and backdrop on native handoff, dismissal, disabled preferences, detached hosts, and unsupported orientations. No new UIWindow, native gesture replacement, lock-screen-access change, or programmatic presentation bypass is introduced.

## Verification and deliverables

- **47/47** UIKit/mock-host assertions passed on iOS 17.5 iPhone 15 Pro Simulator. Includes full-window bounds with an inset panel, header hit testing, pinned footer, reachable lower shortcuts, native scroll offsets, untouched/inherited native transforms, overscanned background, landscape-to-portrait restoration, detached-host cleanup, and the existing lifecycle/media/layout checks.
- **20/20** policy assertions passed with AddressSanitizer and UndefinedBehaviorSanitizer; SDK class/schema checks pass.
- RootHide package compiles and links for **arm64 and arm64e**. Exact package manifest, SpringBoard-only filter, preference registration, schemas, architecture, and loader paths pass verification. Existing toolchain `-multiply_defined` and CPU-count sandbox notices remain; no source compilation warning remains.
- The simulator preview can now use `HARBOR_PREVIEW_APP=/tmp/.../HarborPreview.app`, avoiding an observed iCloud/FileProvider FinderInfo race during signing. This changes only the local preview build path, not device packaging.
- Release package: `packages/com.chasedavis.harbor_0.1.0~beta3_iphoneos-arm64e.deb`, **49,628 bytes**, SHA-256 `dab1172f7602259fc749e5710f30cba376bc6c631184f0124f24074f1a0749fe`.

Evidence: [simulator-results-beta3.json](simulator-results-beta3.json), [preview-beta3-inset-fixture.png](preview-beta3-inset-fixture.png), [build-beta3.log](build-beta3.log), [host-checks-beta3.txt](host-checks-beta3.txt), and [package-verification-beta3.txt](package-verification-beta3.txt). The preview's system header is explicitly a fixture, not real SpringBoard.

## Remaining device checks

Confirm the screenshot's installed package version and the phone's exact environment. Native gesture arbitration, interactive/cancelled dismissal, actual private view hierarchy and header layout, physical rotation, lock-screen access policy, and interactions with other tweaks still require testing on that phone. Lifecycle and ancestry checks do not certify these behaviors. Native status colors are left under Apple's control; the preview app explicitly uses a light status style solely for its synthetic fixture.

Publication was explicitly authorized after the local correction passed validation. See [PUBLICATION.md](PUBLICATION.md) and its Actions link for artifact details and deployment status. This workflow does not install or restart anything on a phone, and physical-device behavior remains unverified.
