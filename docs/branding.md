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

There are six principal artworks in the repository. The three additional GRUB PNGs are
solid UI primitives (panel, divider, selected row), not independent artwork; the remaining
logo and banner placements are copies.

| # | Artwork | Format | Size | SHA-256 (prefix) |
|---|---|---|---|---|
| A | Qubix OS logo mark | SVG | 1024×1024pt | `3ccc88c3…` |
| B | Qubix OS logo mark | PNG | 512×512 | `f7448d03…` |
| C | Qubix OS banner (logo + wordmark) | SVG | 1600×450 | `46d7526f…` |
| D | Qubix OS banner | PNG | 1600×450 | `38879687…` |
| E | Qubix OS watermark | PNG | 128×36 | `41ba5629…` |
| F | Qubix Boot Console background | PNG | 1920×1080 | `6e8a8383…` |

Primary colour in the logo mark: `#47603b`.

It is **not** the only colour the project uses. The Niri session is themed from `#56728B`,
a slate blue with its own derived palette — see [`desktops.md`](desktops.md) and DD-022.
The logo green stays the logo's; it is not a system accent.

## Asset map

### Logo mark — SVG (artwork A)

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/pixmaps/qubixos-logo.svg` | `/usr/share/pixmaps/qubixos-logo.svg` | Qubix-named canonical copy; reference source for the other SVG placements. |
| `files/system/usr/share/icons/hicolor/scalable/distributor-logo.svg` | `/usr/share/icons/hicolor/scalable/distributor-logo.svg` | The freedesktop "distributor logo" icon. Application launchers, About dialogs, and anything resolving the `distributor-logo` icon name. The late recipe step also copies it over Breeze's regular and symbolic KDE/Plasma `start-here` aliases used by Kickoff and Kicker (DD-068). |

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

### GRUB Boot Console

GRUB reads its theme before the immutable root deployment is available. These repository
paths are therefore immutable *sources*; `qubix-grub-theme.service` copies the complete
validated set into a content-addressed directory under `/boot/grub2/themes/` and activates
it through GRUB's existing `custom.cfg` hook (DD-057).

| Repository/image path | Runtime path | Consumed by |
|---|---|---|
| `files/system/usr/share/qubix-os/grub-theme/background.png` | `/boot/grub2/themes/qubix-v2-*/background.png` | GRUB desktop artwork F: near-black terminal grid and the cropped Qubix wireframe cube. |
| `…/theme.txt` | same content-addressed theme directory | GRUB `gfxmenu`; lays out the terminal frame, live boot menu, selection, help, and timeout. Menu entries come from GRUB and are not named here. |
| `…/{panel,line,selected_c}.png` | same directory | Solid stretchable primitives for the panel, dividers/border, and selected row. Their SHA-256 prefixes are `18255d05…`, `2a34b4ed…`, and `a62866c2…`. |
| `…/VERSION` | same directory | Installer protocol version. Artwork changes are distinguished automatically by the manifest digest; increment this only when the delivery contract changes. |
| Generated by `common-base.yml` module 4j | `…/qubix-krypton-{16,20}.pf2`, `…/qubix-krypton-bold-20.pf2` | Monaspace Krypton NF Regular at 16/20 points and Bold at 20, converted from module 4d's OTF files into PF2. Only Latin text and combining marks plus arrow and box-drawing ranges are retained; Nerd Font private-use icons are not used by this interface. |
| `files/system/usr/bin/qubix-grub-theme` | `/usr/bin/qubix-grub-theme` | Validates the image source, copies it atomically into `/boot`, and replaces only the delimited Qubix block in `/boot/grub2/custom.cfg`. |
| `files/system/usr/lib/systemd/system/qubix-grub-theme.service` | same path under `/usr/lib/…` | Runs the installer after local filesystems mount. Enabled in every variant by the shared `systemd` module. |

### Text branding

| Repository path | Image path | Consumed by |
|---|---|---|
| `files/system/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | `/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` | KDE System Settings → **About this System**. Sets `Name=Qubix OS`, the `Variant` string, and `LogoPath=/usr/share/pixmaps/system-logo.png`. |
| `files/system/usr/share/kde-settings/kde-profile/default/xdg/ksplashrc` | `/usr/share/kde-settings/kde-profile/default/xdg/ksplashrc` | KDE's distro profile. Selects `com.qubixos.desktop` for accounts without a higher-priority personal splash choice. |
| `.github/lorax/qubix-product.tmpl` | Installer runtime `/etc/anaconda/qubix-product.buildstamp` plus two systemd drop-ins | Supplies Anaconda a partial `PRODBUILDPATH` overlay with `Product=Qubix OS`; Lorax's later technical `/.buildstamp` and the embedded OCI image name remain unchanged (DD-065). |

`os-release` (`ID`, `NAME`, `PRETTY_NAME`) is *not* in this tree — it is patched at build
time by the `containerfile` module. Its visual `NAME` is `Qubix OS`; technical `ID` and
detail-oriented `PRETTY_NAME` retain BlueBuild provenance. See
[`recipe-reference.md`](recipe-reference.md) and DD-065.

## Where branding shows up, by surface

| Surface | Driven by |
|---|---|
| GRUB boot selector | Qubix Boot Console source in `/usr/share/qubix-os/grub-theme/`, copied and activated in `/boot` by `qubix-grub-theme.service` |
| Boot / shutdown splash | Plymouth `watermark.png`, embedded by the recipe's late `initramfs` module |
| Plasma startup splash | `com.qubixos.desktop`; Aurora dark/light QML paths are compatibility overrides |
| Installer welcome / product heading | Anaconda's partial `PRODBUILDPATH` fragment, set before startup by `.github/lorax/qubix-product.tmpl` |
| System Settings → About this System | `kcm-about-distrorc` + `system-logo.png` |
| Niri floating-bar launcher | `qubixos-logo.png` through the DMS preset migration (DD-048) |
| `neofetch` / `fastfetch` / terminal | `os-release` `PRETTY_NAME` (+ `ID` for logo selection) |
| Plasma Kickoff/Kicker panel button | The applets' stock `start-here-kde-symbolic` lookup; every packaged Breeze KDE/Plasma regular and symbolic alias receives `distributor-logo.svg`'s bytes |
| Application menus, icon lookups | `distributor-logo.svg` |
| Fedora-aware apps and docs viewers | `fedora-logo*.png` overrides |

Prominent product surfaces use the clean name **Qubix OS**. Diagnostic and boot/deployment
details deliberately retain the **BlueBuild** qualifier: `PRETTY_NAME`, the About page's
variant text, OCI/update identity, and therefore generated GRUB deployment names continue
to expose how the system was built (DD-065).

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

## Installing and overriding the GRUB theme

The theme cannot appear on the boot that first introduces it: GRUB runs before the new
image's system service can copy anything into machine-local `/boot`. After rebasing, let
the machine reach multi-user boot once, then reboot again. From that second boot onward,
the visible menu uses Qubix Boot Console whenever GRUB chooses to show a menu.

The installer does **not** regenerate GRUB configuration and does not know the names of
installed operating systems. Fedora's BLS/deployment logic remains responsible for current,
rollback, firmware, and discovered external entries; the theme only renders that list.
Both bootupd's static configuration and Fedora's generated `41_custom` fragment source
`custom.cfg`, so the same delivery works on either boot path.

The managed block sets `timeout_style=menu` and `timeout=8`. This deliberately overrides
bootupd's one-second static default: without it, the background can flash correctly and
then disappear into the kernel handoff before the list is usable. A blank interval **after
the full eight-second countdown or after pressing Enter** is no longer GRUB—the bootloader
has handed control to the selected kernel, and Plymouth/initramfs diagnostics apply.

GRUB's canvas has a counterintuitive z-order: its Fedora implementation
[prepends each component and paints that list from the head](https://github.com/rhboot/grub2/blob/fedora-44/grub-core/gfxmenu/gui_canvas.c),
so components render in reverse theme-file order. The opaque panel must therefore be the
last component in `theme.txt`; declaring it first produces exactly the failed hardware
result seen on 2026-08-31—the background and panel render, but the panel covers every
label, actual boot entry, selection row, divider, and countdown. The build asserts the
panel remains last.

The corrected hardware render exposed one remaining footer problem: GRUB enlarged the
small progress bar past its requested bounds. Fedora GRUB's widget implementation
[forces every progress bar to at least 200×28 pixels](https://github.com/rhboot/grub2/blob/fedora-44/grub-core/gfxmenu/gui_progress_bar.c),
which cannot serve as the thin percentage-based underline in the approved layout. The bar
is therefore omitted. The `AUTOBOOT 7s` numeric label remains the sole timeout indicator
and continues to update through GRUB's `__timeout__` component ID.

Content outside these exact markers is preserved byte-for-byte by intent:

```text
# >>> Qubix OS GRUB theme >>>
…managed theme setup…
# <<< Qubix OS GRUB theme <<<
```

If the markers are malformed or `/boot` is unavailable/read-only, installation stops and
the existing GRUB menu remains bootable. The service reasserts its block after each image
boot so a bootloader refresh cannot silently discard the theme. To opt out deliberately:

```bash
sudo systemctl mask qubix-grub-theme.service
sudo qubix-grub-theme --remove
```

The copied assets remain inert and recoverable. To reapply:

```bash
sudo systemctl unmask qubix-grub-theme.service
sudo qubix-grub-theme --check
sudo qubix-grub-theme --install
```

`--check` validates the image-owned manifest and script without touching `/boot`. To confirm
what `--install` activated, inspect the bounded block:

```bash
sudo sed -n '/# >>> Qubix OS GRUB theme >>>/,/# <<< Qubix OS GRUB theme <<</p' \
    /boot/grub2/custom.cfg
```

That block should contain both `set timeout_style=menu` and `set timeout=8`. These lines
are available only after rebasing to an image that contains this revision; rerunning the
older installer cannot add them.

The theme asks firmware for `1920x1080` and then `auto`; percentage-based placement keeps
the menu usable when firmware supplies only a lower mode. A serial or non-graphical GRUB
path continues to use GRUB's text fallback.

## Known gotcha

macOS `.DS_Store` files appear inside `files/system/` during local editing. They are
gitignored, so they never reach CI or the image. Do not un-ignore them — the `files`
module would copy them into `/usr/share/pixmaps/`.
