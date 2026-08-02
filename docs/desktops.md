# Desktop Sessions

Qubix OS ships **two** desktop sessions. They are installed side by side, share the same
user account and the same home directory, and are chosen at the login screen.

| Session | What it is | Origin | Shell / panel |
|---|---|---|---|
| Plasma (Wayland) | KDE Plasma | Inherited from Aurora DX | Plasma itself |
| Niri | Scrollable-tiling Wayland compositor | Added here (`niri`, Fedora repos) | [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) |

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

## The Niri shell: DankMaterialShell

Niri is a compositor, not a desktop — on its own it has no panel, launcher, notifications,
lock screen, or power menu. **DankMaterialShell** (DMS) provides all of them as one
Quickshell-based shell built for niri. It is installed from its authors' COPRs and started
by systemd.

| Component | Provided by DMS |
|---|---|
| Panel, clock, tray, workspace indicator | yes |
| Application launcher ("spotlight") | yes |
| Notification centre | yes |
| Lock screen | yes |
| Power menu | yes |
| Volume / brightness / media OSD | yes |
| Clipboard history | yes (backed by `cliphist`) |
| Settings UI, task manager, notepad | yes |

### It runs under Niri only

DMS's unit is installed **disabled**, and niri's unit pulls it in:

```ini
# /usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf
[Unit]
Wants=dms.service
```

So a Plasma login is exactly the session it was before DMS existed — no second panel, no
second notification daemon, no second lock screen. This is the image-wide equivalent of
DMS's documented per-user step, `systemctl --user add-wants niri.service dms`. To opt out
for your own account:

```bash
mkdir -p ~/.config/systemd/user/niri.service.d
printf '[Unit]\nWants=\n' > ~/.config/systemd/user/niri.service.d/60-no-dms.conf
```

### Theming

`dms ipc call settings focusOrToggle` (`Mod+,`) opens the shell's own settings. Enabling
dynamic theming makes matugen generate a Material colour scheme from the wallpaper and
write it to `~/.config/niri/dms/colors.kdl`. The shipped niri config includes that file
with `optional=true`, so niri's focus ring, borders, and tab indicators follow the shell's
accent colour once it exists. Until then the config's own Qubix green applies.

The include sits at the **end** of the config on purpose: niri includes are positional and
override whatever was set before them.

### When the Niri session shows nothing

Niri comes up and the keybinds work, but the screen stays empty — no wallpaper, no top
bar, and nothing when you open an application. Tracked as **IMG-012** in
[`../.agent/plan.md`](../.agent/plan.md).

#### Known cause: the Xwayland Video Bridge

**Images built before IMG-012 land with a blank Niri desktop.** `xwaylandvideobridge` —
"Wayland to X Recording bridge" — is a KDE component that republishes a Wayland screen
capture as an X11 window, so Discord, Zoom, and OBS can record the screen. It XDG-autostarts
and niri pulls in `xdg-desktop-autostart.target`, so it runs here too.

It is meant to be invisible and leaves that to the compositor. KDE ships a KWin rule that
hides it; niri has no equivalent, so it just opens ([niri#2367]). It takes focus at login
and covers the session, which is why the desktop looks dead rather than merely cluttered.

The symptoms are distinctive, and none of them are display faults:

- The session starts by showing niri's "Important Hotkeys" cheatsheet, so niri is
  compositing and presenting fine.
- Keybinds, DMS's IPC, and every client work throughout.
- Hammering a keybind, or switching workspaces, brings the whole session up at once —
  correct, and functional from then on.

Confirm it in one command:

```bash
niri msg windows        # look for app-id `xwaylandvideobridge`
```

**The image now stops the bridge from autostarting under Niri**, with an
`/etc/xdg/autostart/` entry carrying `NotShowIn=niri;` (DD-021). Rebase to pick it up. A
window rule in `/etc/niri/config.kdl` also keeps it out of sight if it is started by hand
(DD-019); if you keep a personal `~/.config/niri/config.kdl`, that file wins and you need
to copy the rule across yourself.

Hiding the window alone was not enough, and the reason is worth knowing: a hidden window is
still a window. It stays in niri's toplevel list, so the bar goes on listing it as a running
application, and neither niri nor DankMaterialShell can filter a window out of that list.

**What this costs.** X11 applications — Discord, Zoom, older OBS — cannot capture the screen
in the Niri session *until you turn the bridge on*. Wayland-native screen sharing through
`xdg-desktop-portal` is unaffected, and Plasma is untouched.

Turning it on is one keystroke: **`Mod+Shift+B`**, or "Xwayland Video Bridge (toggle)" in
the launcher. The same control turns it off again, and either way you get a notification
saying which happened. Both run `qubix-video-bridge`, so it also works from a terminal.

Leave it off when you are not sharing your screen. While it runs it appears in the bar as a
running application, which is the behaviour that made stopping the autostart necessary in
the first place — it is only worth putting up with while you need it.

[niri#2367]: https://github.com/niri-wm/niri/issues/2367

#### Something else is covering the session

The same shape — niri healthy, screen apparently dead — happens with anything that
XDG-autostarts and expects a KWin rule to tidy it up. `niri msg windows` names it.

There are two answers, and neither is removing the KDE package (DD-013). Add a window rule
in `/etc/niri/config.kdl` if the thing should still run — that takes nothing away, so try it
first. If it should not run here at all, add an `/etc/xdg/autostart/` override carrying
`NotShowIn=niri;`, as the bridge does. DD-019 and DD-021 cover both halves.

#### Nothing renders at all

If nothing is covering the session and the display really is dead, run these in a terminal
inside the failing session. If `Mod+T` gives you no window, switch
to a text console with `Ctrl+Alt+F3`, log in, and prefix each command with
`XDG_RUNTIME_DIR=/run/user/$(id -u)`.

**1. Does niri know the windows exist?** This is the decisive question.

```bash
niri msg windows
niri msg layers
niri msg outputs
```

- **Windows are listed but nothing is on screen** — the compositor is tracking them and
  the frames are not reaching the display. Check `niri msg outputs` in the same breath:
  content drawn onto a second, logically-enabled output is indistinguishable from content
  never drawn at all. If the panel holds a stale image only when the screen is idle, that is
  Panel Self Refresh; `rpm-ostree kargs --append=amdgpu.dcdebugmask=0x10` disables it on AMD
  laptops, at some battery cost, and `--delete=` backs it out.
- **Nothing is listed** — clients are not reaching niri's Wayland socket, and the process
  that briefly drew the top bar is the only one that got through.
- **A surface on the `overlay` layer covers the output** — DMS's lock screen is drawn
  there. A lock surface that has engaged but rendered blank hides windows and shell alike
  while leaving niri's binds working.

**2. Read niri's own log.** More often than not it names the fault outright — a GL or DRM
error, a config parse failure, or a spawned command that could not be executed.

```bash
journalctl --user -u niri.service -b --no-pager
```

**3. Is it niri, or is it the machine?** Log out and log in to **Plasma**. The greeter and
the Plasma session are both Wayland compositors on the same GPU; if they render and niri
does not, the graphics stack is fine and the fault is niri-specific. If Plasma is also
broken, see the boot notes on IMG-011 — this hardware has hung a compositor before.

#### Only the shell is missing

If applications open normally and just the bar and wallpaper are absent:

```bash
systemctl --user status dms.service
tr '\0' '\n' < /proc/"$(pgrep -nf 'qs -p')"/environ | grep -E 'QT_QPA|WAYLAND_DISPLAY'
dms doctor
```

`inactive` means niri's drop-in was not applied — check that
`/usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` exists and that nothing in
`~/.config/systemd/user/niri.service.d/` overrides it. A start-timeout means the unit ran
but systemd never saw it claim `org.freedesktop.Notifications`, the D-Bus name it declares
as its `Type=dbus` name.

`QT_QPA_PLATFORM` matters because DMS sets `wayland;xcb` **only when the variable is
unset** — a fallback chain. If the Wayland plugin cannot connect, Qt silently falls back to
`xcb` and runs the shell through niri's Xwayland, where there is no layer-shell protocol at
all: the bar and wallpaper can never map, while ordinary windows and the whole IPC surface
keep working normally.

Report what you find to IMG-012. The fix belongs in the image, not in your home directory —
please do not paper over it with per-user config before it is recorded.

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

### The colour theme

Every colour niri draws comes from one hex, **`#56728B`** — `hsl(208, 24%, 44%)`, a muted
slate blue. The rest of the palette holds that hue and saturation and moves only lightness,
so every surface is the same colour at a different depth.

| Swatch | Lightness | Where you see it |
|---|---|---|
| `#1B242C` | 14% | Overview backdrop; the shadow colour; the empty screen |
| `#2B3945` | 22% | Unfocused window — ring or border |
| `#3A4E5F` | 30% | Inactive tab in a tabbed column |
| **`#56728B`** | **44%** | **Focused window; the insert hint, at half alpha** |
| `#7490A9` | 56% | Active tab |
| `#C67B39` | — | Urgent window. `hsl(28, 55%, 50%)` — the hue exactly opposite the base, and the one colour here meant *not* to blend in |

To extend the palette, pick a lightness rather than a colour. Two features niri leaves off
by default — **borders** and **shadows** — are already coloured in the shipped config, so
enabling either is a one-word edit that still matches.

**DankMaterialShell overrides all of this if you turn on dynamic theming.** The config ends
with an include of `~/.config/niri/dms/colors.kdl`, and niri includes override whatever came
before them, so matugen's wallpaper-derived scheme wins. That is intentional (DD-015): this
palette is the default, not a lock. Drop the include to keep it regardless of the wallpaper.

This is deliberately *not* the Qubix logo green — see DD-022 for why the session gets its own
accent.

### Key bindings

`Mod` is the Super (Meta / Windows) key. This is a summary; `Mod+Shift+/` shows the live
list, generated from the config actually in use.

| Binding | Action |
|---|---|
| `Mod+T` | Terminal (WezTerm) |
| `Mod+Space` | Application launcher (DMS spotlight) |
| `Mod+V` | Clipboard history |
| `Mod+N` | Notification centre |
| `Mod+,` | Shell settings |
| `Mod+M` or `Ctrl+Alt+Del` | Task manager |
| `Mod+Shift+B` | X11 screen capture — toggle the Xwayland Video Bridge |
| `Mod+Alt+L` | Lock screen |
| `Mod+X` | Power menu |
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
| Volume / brightness / media keys | Routed through DMS, so its on-screen display appears |
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

Waybar, Fuzzel, and Swaylock also arrive as `niri` weak dependencies. The shipped config
does not use them — DMS covers all three — but they are left installed as a fallback if
you ever need to bind them by hand.
