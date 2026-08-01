# Context: `files/system/`

**Covers:** everything under `files/system/`

## Purpose

The image root overlay. The `files` module copies `files/system/*` verbatim into `/` in the
image, so **repository path = image path**. Two kinds of content live here: branding assets
(the bulk of it) and system-wide desktop configuration.

## Desktop configuration

| Path | Consumer | Effect |
|---|---|---|
| `etc/xdg/kdeglobals` | KDE Frameworks (KConfig cascade) | `TerminalApplication=wezterm` (DD-012) |
| `usr/lib/environment.d/50-qubix-terminal.conf` | systemd user manager | `TERMINAL=wezterm` (DD-012) |
| `etc/niri/config.kdl` | niri | System-default session config; DMS keybinds; window rule hiding the Xwayland Video Bridge (DD-014, DD-015, DD-019) |
| `usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | systemd user manager | `Wants=dms.service`, so the shell starts under Niri **only** (DD-015) |

`etc/xdg/kdeglobals` is a **fragment**, not a replacement — KConfig merges every
`kdeglobals` on `$XDG_CONFIG_DIRS` key by key. Fedora's `XDG_CONFIG_DIRS` is
`/etc/xdg:/usr/share/kde-settings/kde-profile/default/xdg`, so `/etc/xdg` wins for the
keys it names and inherits everything else. Do **not** add a `kdeglobals` under
`usr/share/kde-settings/…` — that path already exists upstream and would be overwritten.

`xwaylandvideobridge` XDG-autostarts and `niri.service` pulls in
`xdg-desktop-autostart.target`, so KDE components reach the Niri session. The bridge
expects the compositor to hide it — KDE ships a KWin rule; niri does not — so without the
window rule in `etc/niri/config.kdl` it opens a blank window over a fresh session and the
desktop looks dead (DD-019). **Anything else KDE that autostarts and relies on a KWin rule
will do the same**; the answer is another window rule in that file, never removing a KDE
package.

`dms.service` is left **disabled** on purpose. It ships
`WantedBy=graphical-session.target`, so enabling it would start DankMaterialShell inside
KDE Plasma too — two panels, two notification daemons, two lock screens. The drop-in on
`niri.service` is what scopes it to the Niri session.

## Branding

- **Mechanism:** branding works by *overwriting upstream paths* (DD-004). Files are
  therefore named after the component that reads them, **not** after their contents.
- **Four distinct source images**, everything else is a byte-identical copy (DD-005):

  | Artwork | Form | Size | SHA-256 prefix | Copies live at |
  |---|---|---|---|---|
  | A | SVG logo mark | 1024×1024pt | `3ccc88c3…` | `pixmaps/qubixos-logo.svg`, `icons/hicolor/scalable/distributor-logo.svg` |
  | B | PNG logo mark | 512×512 | `f7448d03…` | `pixmaps/qubixos-logo.png`, `system-logo.png`, `system-logo-white.png`, `fedora-logo-sprite.png` |
  | C | SVG banner | 1600×450 | `46d7526f…` | `pixmaps/qubixos-banner.svg`, `aurora-banner.svg` |
  | D | PNG banner | 1600×450 | `38879687…` | `pixmaps/fedora-logo.png`, `fedora_logo_med.png` |
  | E | PNG watermark | 128×36 | `41ba5629…` | `plymouth/themes/spinner/watermark.png`, `kinoite-watermark.png`, `pixmaps/fedora-logo-small.png` |

- **Plasma splash:**
  `usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/splash/images/aurora_logo.svgz`
  — a gzipped copy of artwork A. The Aurora directory and filename are referenced by the
  splash QML and **must not be renamed**.
- **Text branding:**
  `usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` — KDE "About this
  System". Sets `Name=Qubix OS`, a `Variant` string, and
  `LogoPath=/usr/share/pixmaps/system-logo.png`.
- Logo primary colour: `#47603b`.

## `/usr` vs `/etc`

Prefer `/usr` for configuration: `/etc` is three-way merged on updates, `/usr` is replaced
wholesale. Use `/etc` only where the consumer offers no `/usr` path that can be written
without clobbering an upstream file — currently `etc/xdg/kdeglobals` (DD-012) and
`etc/niri/config.kdl` (DD-014; niri's config search path has no `/usr` entry).

## Gotchas

- `fedora-logo.png`, `fedora_logo_med.png`, `fedora-logo-small.png`,
  `fedora-logo-sprite.png`, `aurora-banner.svg`, and `aurora_logo.svgz` all contain
  **Qubix** artwork. This is the override mechanism — do not "fix" the names.
- `system-logo-white.png` is currently identical to `system-logo.png`, i.e. not actually a
  light variant. Tracked as open task `BRD-001`.
- macOS writes `.DS_Store` files into this tree while editing. They are gitignored and must
  stay that way, or the `files` module would copy them into `/usr/share/pixmaps/`.
- Changing artwork means updating **every** copy in the group above.

## Update when

You add, remove, or change any asset or configuration file. For configuration, also update
`docs/recipe-reference.md` (the `files` module table). For assets, also update
`docs/branding.md` — including its checksum table:

```bash
shasum -a 256 files/system/usr/share/pixmaps/* \
              files/system/usr/share/plymouth/themes/spinner/* \
              files/system/usr/share/icons/hicolor/scalable/*.svg | sort
```
