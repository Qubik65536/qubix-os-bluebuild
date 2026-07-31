# Desktop Sessions

Qubix OS ships **two** desktop sessions. They are installed side by side, share the same
user account and the same home directory, and are chosen at the login screen.

| Session | What it is | Origin | Shell / panel |
|---|---|---|---|
| Plasma (Wayland) | KDE Plasma | Inherited from Aurora DX | Plasma itself |
| Niri | Scrollable-tiling Wayland compositor | Added here (`niri`, Fedora repos) | Waybar |

Nothing that comes with KDE Plasma is removed, disabled, or replaced. Niri is **added**;
Plasma remains the full, untouched Aurora DX desktop. See
[`design-decisions.md`](design-decisions.md) DD-013.

## Switching between them

1. Log out (or reboot).
2. At the SDDM login screen, use the session selector — bottom-left on the Breeze
   greeter, showing the current session name.
3. Pick **Plasma (Wayland)** or **Niri**, then log in.

SDDM lists whatever it finds in `/usr/share/wayland-sessions/`. Niri's own RPM installs
`niri.desktop` there, so no configuration in this repository is involved in making the
entry appear. The choice is remembered per user for the next login.

## What Niri is

Niri is a **scrollable-tiling** compositor. Instead of subdividing the screen, windows
form one infinite horizontal strip of columns per workspace; the viewport scrolls along
it. Opening a window never resizes the windows you already have. Workspaces are dynamic
and stack vertically.

If you have used i3, Sway, or Hyprland, the mental model is different enough to be worth
five minutes with the hotkey overlay (`Mod+Shift+/`) before deciding you dislike it.

## Niri configuration

| Path | Role |
|---|---|
| `~/.config/niri/config.kdl` | Per-user config. Wins if it exists. |
| `/etc/niri/config.kdl` | This image's system default. Used when the per-user file is absent. |

**Because `/etc/niri/config.kdl` exists, niri will not create a per-user config for you on
first login.** To customise the session, copy it first:

```bash
mkdir -p ~/.config/niri
cp /etc/niri/config.kdl ~/.config/niri/config.kdl
```

The config live-reloads on save. `niri validate` parses it and reports errors. The full
option reference ships in the image at `/usr/share/doc/niri/wiki/` and is online at
<https://github.com/YaLTeR/niri/wiki>.

The shipped config is deliberately short — it is not a copy of niri's 600-line annotated
default. Anything it does not set keeps niri's built-in default. See DD-014 for why it
lives in `/etc` rather than `/usr`.

### Key bindings

`Mod` is the Super (Meta / Windows) key. This is a summary; `Mod+Shift+/` shows the live
list, generated from the config actually in use.

| Binding | Action |
|---|---|
| `Mod+T` | Terminal (WezTerm) |
| `Mod+D` | Application launcher (Fuzzel) |
| `Mod+Alt+L` | Lock screen |
| `Mod+Q` | Close window |
| `Mod+O` | Overview — every workspace on every monitor |
| `Mod+←/→` or `Mod+H/L` | Focus the column left / right |
| `Mod+↑/↓` or `Mod+J/K` | Focus the window up / down within a column |
| `Mod+Shift+` *(direction)* | Move the focused window |
| `Mod+U` / `Mod+I` | Focus workspace below / above |
| `Mod+1`…`Mod+9` | Focus workspace by number |
| `Mod+Shift+1`…`9` | Move the window to that workspace |
| `Mod+R` | Cycle preset column widths |
| `Mod+F` / `Mod+Shift+F` | Maximise column / fullscreen window |
| `Mod+W` | Toggle tabbed display for the column |
| `Mod+[` / `Mod+]` | Pull in / push out the neighbouring window |
| `Print` | Interactive screenshot (`Ctrl` = screen, `Alt` = window) |
| `Mod+Shift+E` | Exit the session |

## The default terminal

**WezTerm** is the default terminal in both sessions. It is layered from WezTerm's own
COPR because Fedora does not package it — see DD-012.

| Session | Mechanism | File |
|---|---|---|
| Plasma | `[General] TerminalApplication=wezterm` in the KConfig cascade | `/etc/xdg/kdeglobals` |
| Niri | `Mod+T` spawns `wezterm` | `/etc/niri/config.kdl` |
| Both | `TERMINAL=wezterm` for the `$TERMINAL -e …` convention | `/usr/lib/environment.d/50-qubix-terminal.conf` |

Konsole is still installed and still works. To go back to it in Plasma: *System Settings →
Default Applications → Terminal Emulator*.

## Things that are shared, and things that are not

Both sessions run as the same user against the same home directory, so shell
configuration, SSH keys, Flatpak applications, and files are shared. The desktop *state*
is not: panel layouts, wallpapers, keyboard shortcuts, and theming are per-session,
because Plasma and Niri store them in unrelated places. Changing the wallpaper in one does
not change it in the other.

`xdg-desktop-portal-gnome` and `xdg-desktop-portal-gtk` arrive as weak dependencies of the
`niri` RPM. They do not affect Plasma: portal selection is per-desktop, driven by
`$XDG_CURRENT_DESKTOP` and the `*-portals.conf` files each desktop ships.
