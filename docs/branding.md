# Branding

Everything under `files/system/` is branding. This page is the map from **repository
path** → **image path** → **what displays it**.

> **Read this before renaming or deleting any asset.** Several files are deliberately
> named after Fedora or Aurora while containing Qubix OS artwork. That is the override
> mechanism, not a mistake — see DD-004.

## How branding works here

Distro branding on Fedora/KDE is scattered across components that each hardcode a path.
Rather than fork Aurora's look-and-feel package and a Plymouth theme, this image ships
replacement files at those exact paths through the `files` module. The upstream file is
overwritten in the image; the component reads its usual path and finds Qubix artwork.

Two consequences follow:

- **The filename describes the *consumer*, not the content.** `fedora-logo.png` is the
  path Fedora components read; the bytes are the Qubix banner.
- **The same artwork appears under several names.** Copies are real files, not symlinks
  (DD-005), so each consumer can be re-pointed independently later.

## Source artwork

There are four distinct images in the repository. Everything else is a copy.

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
| `files/system/usr/share/pixmaps/qubixos-logo.png` | `/usr/share/pixmaps/qubixos-logo.png` | Qubix-named canonical copy. |
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
| `files/system/usr/share/plymouth/themes/spinner/watermark.png` | `/usr/share/plymouth/themes/spinner/watermark.png` | **Plymouth boot splash watermark** — the logo shown under the spinner during boot and shutdown. |
| `files/system/usr/share/plymouth/themes/spinner/kinoite-watermark.png` | `/usr/share/plymouth/themes/spinner/kinoite-watermark.png` | Kinoite's watermark variant; overridden so whichever the theme selects is Qubix. |
| `files/system/usr/share/pixmaps/fedora-logo-small.png` | `/usr/share/pixmaps/fedora-logo-small.png` | Small Fedora logo path (128×36). |

### Plasma splash (artwork A, gzip-compressed SVG)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/splash/images/aurora_logo.svgz` | same path under `/usr/share/…` | The **KDE Plasma startup splash** logo. The directory and filename belong to Aurora's look-and-feel package and must be kept exactly — the splash QML references them by name. The file is an SVGZ (gzipped SVG) whose inner `sodipodi:docname` is `qubixos-logo.svgz`. |

### Text branding

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | `/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | KDE System Settings → **About this System**. Sets `Name=Qubix OS`, the `Variant` string, and `LogoPath=/usr/share/pixmaps/system-logo.png`. |

`os-release` (`ID`, `NAME`, `PRETTY_NAME`) is *not* in this tree — it is patched at build
time by the `containerfile` module. See [`recipe-reference.md`](recipe-reference.md).

## Where branding shows up, by surface

| Surface | Driven by |
|---|---|
| Boot / shutdown splash | Plymouth `watermark.png` |
| Plasma startup splash | `aurora_logo.svgz` in the Aurora look-and-feel dir |
| System Settings → About this System | `kcm-about-distrorc` + `system-logo.png` |
| `neofetch` / `fastfetch` / terminal | `os-release` `PRETTY_NAME` (+ `ID` for logo selection) |
| Application menus, icon lookups | `distributor-logo.svg` |
| Fedora-aware apps and docs viewers | `fedora-logo*.png` overrides |

## Changing the logo

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md) (`BRD` category).
2. Produce the new artwork in **all five** forms above (A–E), matching the existing
   dimensions.
3. Replace **every** path in the asset map that uses that artwork — the tables are grouped
   by artwork so the full set is visible.
4. Re-generate the SVGZ with `gzip` if the splash logo changed.
5. Update the SHA-256 prefixes in the *Source artwork* table:
   ```bash
   shasum -a 256 files/system/usr/share/pixmaps/* \
                 files/system/usr/share/plymouth/themes/spinner/* \
                 files/system/usr/share/icons/hicolor/scalable/*.svg | sort
   ```
   Identical prefixes across a group confirm the copies are still in sync.
6. Update `.agent/context/files-system.md`.
7. Push; verify visually after rebasing, since none of this is machine-checkable.

## Known gotcha

macOS `.DS_Store` files appear inside `files/system/` during local editing. They are
gitignored, so they never reach CI or the image. Do not un-ignore them — the `files`
module would copy them into `/usr/share/pixmaps/`.
