# Branding

Everything under `files/system/` is branding. This page is the map from **repository
path** → **image path** → **what displays it**.

> **Read this before renaming or deleting any asset.** Several files are deliberately
> named after Fedora or Aurora while containing Qubix OS artwork. That is the override
> mechanism, not a mistake — see DD-004.

## How branding works here

Distro branding on Fedora/KDE is scattered across components that each hardcode a path.
Most surfaces are replaced at their exact upstream paths through the `files` module. The
upstream file is overwritten in the image; the component reads its usual path and finds
Qubix artwork. The Plasma startup splash also has a small Qubix-native look-and-feel
package so it has its own selectable name and ID; Aurora's two package IDs remain
overridden for existing users (DD-049).

Two consequences follow:

- **The filename describes the *consumer*, not the content.** `fedora-logo.png` is the
  path Fedora components read; the bytes are the Qubix banner.
- **The same artwork appears under several names.** Copies are real files, not symlinks
  (DD-005), so each consumer can be re-pointed independently later.

## Source artwork

There are five distinct images in the repository. Everything else is a copy.

| # | Artwork | Format | Size | SHA-256 (prefix) |
|---|---|---|---|---|
| A | Qubix OS logo mark | SVG | 1024×1024pt | `3ccc88c3…` |
| B | Qubix OS logo mark | PNG | 512×512 | `f7448d03…` |
| C | Qubix OS banner (logo + wordmark) | SVG | 1600×450 | `46d7526f…` |
| D | Qubix OS banner | PNG | 1600×450 | `38879687…` |
| E | Qubix OS watermark | PNG | 128×36 | `41ba5629…` |

Primary colour in the logo mark: `#47603b`.

It is **not** the only colour the project uses. The Niri session is themed from `#56728B`,
a slate blue with its own derived palette — see [`desktops.md`](desktops.md) and DD-022.
The logo green stays the logo's; it is not a system accent.

## Asset map

### Logo mark — SVG (artwork A)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/pixmaps/qubixos-logo.svg` | `/usr/share/pixmaps/qubixos-logo.svg` | Qubix-named canonical copy; reference source for the other SVG placements. |
| `files/system/usr/share/icons/hicolor/scalable/distributor-logo.svg` | `/usr/share/icons/hicolor/scalable/distributor-logo.svg` | The freedesktop "distributor logo" icon. Application launchers, About dialogs, and anything resolving the `distributor-logo` icon name. |

### Logo mark — PNG (artwork B)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/pixmaps/qubixos-logo.png` | `/usr/share/pixmaps/qubixos-logo.png` | Qubix-named canonical copy; DMS uses it for the Niri floating-bar launcher (DD-048). |
| `files/system/usr/share/pixmaps/system-logo.png` | `/usr/share/pixmaps/system-logo.png` | Generic system logo. **Referenced explicitly by `kcm-about-distrorc`** → KDE System Settings → About this System. |
| `files/system/usr/share/pixmaps/system-logo-white.png` | `/usr/share/pixmaps/system-logo-white.png` | Light-on-dark variant path. Currently the same artwork as `system-logo.png`. |
| `files/system/usr/share/pixmaps/fedora-logo-sprite.png` | `/usr/share/pixmaps/fedora-logo-sprite.png` | Fedora sprite path, overridden so Fedora-aware components show the Qubix mark. |

### Banner — SVG (artwork C)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/pixmaps/qubixos-banner.svg` | `/usr/share/pixmaps/qubixos-banner.svg` | Qubix-named canonical copy. |
| `files/system/usr/share/pixmaps/aurora-banner.svg` | `/usr/share/pixmaps/aurora-banner.svg` | Aurora's banner path. Overridden so Aurora's own branding surfaces show Qubix. |

### Banner — PNG (artwork D)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/pixmaps/fedora-logo.png` | `/usr/share/pixmaps/fedora-logo.png` | Classic Fedora logo path. |
| `files/system/usr/share/pixmaps/fedora_logo_med.png` | `/usr/share/pixmaps/fedora_logo_med.png` | Medium-size Fedora logo path (underscore spelling is upstream's, not a typo). |

### Watermark — PNG (artwork E)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/plymouth/themes/spinner/watermark.png` | `/usr/share/plymouth/themes/spinner/watermark.png` | **Plymouth boot splash watermark** — embedded into the standard image's initramfs by its late `initramfs` module (DD-049). |
| `files/system/usr/share/plymouth/themes/spinner/kinoite-watermark.png` | `/usr/share/plymouth/themes/spinner/kinoite-watermark.png` | Kinoite's watermark variant; overridden before every recipe regenerates its initramfs. |
| `files/system/usr/share/pixmaps/fedora-logo-small.png` | `/usr/share/pixmaps/fedora-logo-small.png` | Small Fedora logo path (128×36). |

### Plasma startup splash

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/plasma/look-and-feel/com.qubixos.desktop/metadata.json` | same path under `/usr/share/…` | Registers **Qubix OS** as a selectable Plasma look-and-feel package. It deliberately carries only the startup splash, not a colour scheme, layout, or wallpaper. |
| `files/system/usr/share/plasma/look-and-feel/com.qubixos.desktop/contents/splash/Splash.qml` | same path under `/usr/share/…` | Canonical Plasma startup splash. Draws `qubixos-logo.svg` centrally on black and no inherited Aurora/KDE footer. |
| `files/system/usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/splash/Splash.qml` | same path under `/usr/share/…` | Compatibility override for an existing account whose splash ID is Aurora dark. Renders the same Qubix-only surface. |
| `files/system/usr/share/plasma/look-and-feel/dev.getaurora.auroralight.desktop/contents/splash/Splash.qml` | same path under `/usr/share/…` | Compatibility override for Aurora light, which is a separate package and previously escaped the one-file logo override. |
| `files/system/usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/splash/images/aurora_logo.svgz` | same path under `/usr/share/…` | Legacy compatibility copy of artwork A at Aurora's image name. The Qubix QML reads the canonical pixmap directly; retaining this prevents Aurora artwork at the old image path. |

### Text branding

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | `/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | KDE System Settings → **About this System**. Sets `Name=Qubix OS`, the `Variant` string, and `LogoPath=/usr/share/pixmaps/system-logo.png`. |
| `files/system/usr/share/kde-settings/kde-profile/default/xdg/ksplashrc` | `/usr/share/kde-settings/kde-profile/default/xdg/ksplashrc` | KDE's distro profile. Selects `com.qubixos.desktop` for accounts without a higher-priority personal splash choice. |

`os-release` (`ID`, `NAME`, `PRETTY_NAME`) is *not* in this tree — it is patched at build
time by the `containerfile` module. See [`recipe-reference.md`](recipe-reference.md).

## Where branding shows up, by surface

| Surface | Driven by |
|---|---|
| Boot / shutdown splash | Plymouth `watermark.png`, embedded by the recipe's late `initramfs` module |
| Plasma startup splash | `com.qubixos.desktop`; Aurora dark/light QML paths are compatibility overrides |
| System Settings → About this System | `kcm-about-distrorc` + `system-logo.png` |
| Niri floating-bar launcher | `qubixos-logo.png` through the DMS preset migration (DD-048) |
| `neofetch` / `fastfetch` / terminal | `os-release` `PRETTY_NAME` (+ `ID` for logo selection) |
| Application menus, icon lookups | `distributor-logo.svg` |
| Fedora-aware apps and docs viewers | `fedora-logo*.png` overrides |

## Changing the logo

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md) (`BRD` category).
2. Produce the new artwork in **all five** forms above (A–E), matching the existing
   dimensions.
3. Replace **every** path in the asset map that uses that artwork — the tables are grouped
   by artwork so the full set is visible.
4. Re-generate the legacy Aurora SVGZ with `gzip` if the splash logo changed. The active
   QML uses `qubixos-logo.svg` directly, but the compatibility path must not drift.
5. Update the SHA-256 prefixes in the *Source artwork* table:
   ```bash
   shasum -a 256 files/system/usr/share/pixmaps/* \
                 files/system/usr/share/plymouth/themes/spinner/* \
                 files/system/usr/share/icons/hicolor/scalable/*.svg | sort
   ```
   Identical prefixes across a group confirm the copies are still in sync.
6. Update `.agent/context/files-system.md`.
7. Push; verify visually after rebasing, since none of this is machine-checkable. A logo
   change reaches Plymouth because every recipe rebuilds its initramfs after the overlay.

## Selecting the Qubix Plasma splash

The image default applies when an account has no personal splash setting. Plasma stores a
user's choice in `~/.config/ksplashrc`, which correctly outranks the distro profile and
survives a rebase. That means an account which explicitly selected Breeze can still show
the Plasma/KDE logo after installing the fixed image.

To restore the image default in the GUI, open **System Settings → Colors & Themes → Splash
Screen**, select **Qubix OS**, and apply it. The equivalent command is:

```bash
kwriteconfig6 --file ksplashrc --group KSplash --key Theme com.qubixos.desktop
```

Log out and back into Plasma to see the result. Accounts still set to either Aurora theme
ID need no migration: both inherited QML paths are overridden with the same Qubix-only
splash.

## Why copying a Plymouth image is not enough

Plymouth runs before the real root filesystem is mounted, so it reads its theme from the
initramfs. Aurora already built that archive before this image's `files` overlay ran.
`recipe.yml` therefore runs BlueBuild's `initramfs` module after the overlay and identity
rewrite; the CachyOS recipe already runs the same module after its kernel swap. Moving the
module into `common-base.yml` would be wrong because it would run before that swap and
leave the variant's replacement kernel without its final archive (DD-049).

## Known gotcha

macOS `.DS_Store` files appear inside `files/system/` during local editing. They are
gitignored, so they never reach CI or the image. Do not un-ignore them — the `files`
module would copy them into `/usr/share/pixmaps/`.
