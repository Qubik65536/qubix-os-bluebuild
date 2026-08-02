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
| `etc/niri/config.kdl` | niri | System-default session config; DMS keybinds; the `#56728B` colour theme; window rule hiding the Xwayland Video Bridge (DD-014, DD-015, DD-019, DD-022) |
| `etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop` | XDG autostart / `systemd-xdg-autostart-generator` | **Replaces** the package's entry, adding `NotShowIn=niri;` so the bridge does not autostart under Niri (DD-021) |
| `usr/bin/qubix-video-bridge` | `Mod+Shift+B` and the launcher entry below | Toggles the bridge, with a notification. **Only executable in the overlay** — the git mode bit is what makes it runnable (IMG-013) |
| `usr/share/applications/qubix-video-bridge.desktop` | XDG application menu / DMS launcher | A **new** entry (upstream's is `NoDisplay=true`), `OnlyShowIn=niri;` (IMG-013) |
| `usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | systemd user manager | `Wants=dms.service`, so the shell starts under Niri **only** (DD-015) |

`etc/xdg/kdeglobals` is a **fragment**, not a replacement — KConfig merges every
`kdeglobals` on `$XDG_CONFIG_DIRS` key by key. Fedora's `XDG_CONFIG_DIRS` is
`/etc/xdg:/usr/share/kde-settings/kde-profile/default/xdg`, so `/etc/xdg` wins for the
keys it names and inherits everything else. Do **not** add a `kdeglobals` under
`usr/share/kde-settings/…` — that path already exists upstream and would be overwritten.

`xwaylandvideobridge` XDG-autostarts and `niri.service` pulls in
`xdg-desktop-autostart.target`, so KDE components reach the Niri session. The bridge
expects the compositor to hide it — KDE ships a KWin rule; niri does not — so it opens a
blank window over a fresh session and the desktop looks dead (DD-019).

**Hiding it was not enough**, which is the part worth remembering: a hidden window is still
in niri's toplevel list, so DankMaterialShell's bar kept listing it, and neither niri nor
DMS can filter a window out of that list. Hence the autostart override (DD-021). The two
files work together — rule for a hand-started bridge, override so it never starts by itself.

**Anything else KDE that autostarts and relies on a KWin rule will behave the same way.**
Window rule if it should still run, `NotShowIn=niri;` override if it should not. Never
remove the KDE package.

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
- Logo primary colour: `#47603b`. **This is the logo's colour, not the project's accent.**
  The Niri session is themed from `#56728B` — `hsl(208, 24%, 44%)` — with every other tone
  derived by holding hue and saturation and moving only lightness (DD-022). Extending that
  palette means computing `hsl(208, 24%, L)`, not eyeballing something close.

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
- **File modes carry through.** `usr/bin/qubix-video-bridge` is executable only because git
  records mode `100755`; the `files` module copies the bit as it finds it. A rewrite that
  drops it produces a script the keybind silently cannot run.
- **`pkill xwaylandvideobridge` matches nothing**, ever. `pkill`/`pgrep` compare against
  `/proc/PID/comm`, truncated by the kernel to 15 characters; that name is 19. `-f` matches
  the full command line instead — and then needs `-x`, or it also matches the shell running
  the `pkill`. `qubix-video-bridge` documents this inline; do not "simplify" it.

## Update when

You add, remove, or change any asset or configuration file. For configuration, also update
`docs/recipe-reference.md` (the `files` module table). For assets, also update
`docs/branding.md` — including its checksum table:

```bash
shasum -a 256 files/system/usr/share/pixmaps/* \
              files/system/usr/share/plymouth/themes/spinner/* \
              files/system/usr/share/icons/hicolor/scalable/*.svg | sort
```
