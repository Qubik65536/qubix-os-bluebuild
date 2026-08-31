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
accent colour once it exists. Until then the Qubix Slate palette applies.

The include sits at the **end** of the config on purpose: niri includes are positional and
override whatever was set before them.

### The floating bar

The Qubix preset removes DMS's continuous top strip and lets each component sit in its
own capsule. The approved layout is deliberately airy rather than detached into large
islands:

```text
╭ cube ╮  ╭ 1  2  3 ╮  ╭ focused window ╮       ╭ music ╮  ╭ clock ╮       ╭ tray ╮  ╭ status ╮
```

It uses DMS's native bar settings: `8` px component spacing, `4` px bar inset, and `8` px
widget padding. The outer `BarCanvas` is fully transparent; each component keeps a
separate Slate `surfaceContainer` background at 96% opacity and DMS's normal rounded
corners. There is no widget outline and the outer bar has no border or elevation shadow.
Existing left, centre, and right widget arrays are preserved; only the presentation keys
are migrated. If DMS has no bar yet, its upstream default widget groups are seeded.

The launcher uses the full-colour canonical Qubix cube at
`/usr/share/pixmaps/qubixos-logo.png`, enlarged by DMS's `+4` size offset. There is no
second logo copy and no shell fork.

Bar geometry is a user preference, so the preset runs **once per version**. The corrected
preset's stamp is `$XDG_STATE_HOME/qubix-os/dms-bar-style-v2` (or
`~/.local/state/qubix-os/dms-bar-style-v2`); edits made afterward survive every login.
Version 2 applies automatically even if version 1 was stamped. To reapply it after
experimenting:

```bash
rm "${XDG_STATE_HOME:-$HOME/.local/state}/qubix-os/dms-bar-style-v2"
systemctl --user start qubix-dms-theme.service
```

Masking `qubix-dms-theme.service` opts out of both future bar migrations and the
image-managed Slate theme pointer. See DD-048 for the corrected DMS semantics and
preservation rules.

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
| `/etc/niri/qubix-theme.kdl` | The colour theme, `include`d by the system config. |

**Because `/etc/niri/config.kdl` exists, niri will not create a per-user config for you on
first login.** To customise the session, copy it first:

```bash
qubix-config niri
```

**Do not copy it with `cp`.** The system config includes the palette with a *relative* path,
`include "qubix-theme.kdl"`, and niri resolves that against the including file's own
directory — so a verbatim copy in `~/.config/niri/` names a file that is not there and the
session does not load. `qubix-config` rewrites that line to the absolute
`/etc/niri/qubix-theme.kdl`, which is also what keeps your copy receiving theme changes
(DD-039).

> **A copy is a fork.** Niri ignores the system file completely once yours exists, so from
> that moment you stop receiving every change the image makes — new keybinds, the display
> scale, the layout. The theme is the exception, because of that rewritten include. Run
> `qubix-config --diff niri` after a rebase to see what you are missing. See *The colour
> theme* below.

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
by default — **borders** and **shadows** — are already coloured, so enabling either is a
one-word edit that still matches.

The theme applies to both halves of the session, from two files that live in the image:

| Half | File | How it is applied |
|---|---|---|
| niri | `/etc/niri/qubix-theme.kdl` | `include`d by the system config |
| DankMaterialShell | `/usr/share/qubix-os/dms-theme.json` | `qubix-dms-theme.service` points your DMS settings at it before the shell starts |

**Both are watched, so a rebase updates the colours live** — there is nothing to re-run and
nothing copied into your home directory. Your DMS settings hold a path, not a palette.

The same palette reaches two terminal tools, in both sessions: zellij's theme in
`/etc/zellij/config.kdl` and lazygit's in `/usr/share/qubix-os/lazygit/config.yml`
(DD-032, DD-033). zellij's accents sit at `hsl(h, 55%, 68%)` rather than the 50% above,
because there every accent is text on a dark surface and 50% misses WCAG AA — see
[`shell.md`](shell.md).

#### Keeping the theme with a personal niri config

**This is the one thing that will silently cut you off.** Niri prefers
`~/.config/niri/config.kdl` and ignores `/etc/niri/config.kdl` entirely once yours exists —
so copying the system config to customise it stops you receiving *every* future system
change, theme included.

Add this line to your own config instead, after your own `layout` block:

```kdl
include "/etc/niri/qubix-theme.kdl"
```

Includes are positional — they override what comes before them — and niri watches included
files, so the theme keeps tracking the image.

#### Changing or keeping a different theme

The DMS pointer is re-applied on **every** Niri session, so picking another theme in DMS's
settings will not survive a logout. To keep your own choice:

```bash
systemctl --user mask qubix-dms-theme.service
```

**Dynamic theming still wins while it is on.** The niri config ends with an include of
`~/.config/niri/dms/colors.kdl`, so matugen's wallpaper-derived scheme overrides the niri
half. That is intentional (DD-015); drop the include to keep the palette regardless of the
wallpaper.

This is deliberately *not* the Qubix logo green — see DD-022 for why the session gets its own
accent, and DD-025 for how it is delivered.

### Display scale

The built-in laptop panel is pinned to **scale 1**:

```kdl
output "eDP-1" {
    scale 1
}
```

Without this, niri derives a scale from the output's physical size and resolution, which on
a ~14-inch 1920×1200 panel comes out at 1.25 — a quarter larger than the Plasma session on
the same machine, with fractional scaling on a panel that does not need it.

**Niri has no global scale setting.** An `output` block matches a connector name or a
`"manufacturer model serial"` triple; there is no wildcard. So the shipped config has to
name one connector, and `eDP-1` is the conventional name for a built-in panel. External
monitors are untouched and keep the automatic guess.

Two consequences worth knowing:

- **If your built-in panel is genuinely HiDPI, delete that block.** Niri's guess is better
  than a forced 1, and scale 1 on a HiDPI panel gives unreadably small text.
- **If your panel is not called `eDP-1`, the block does nothing.** `niri msg outputs` gives
  the real name; substitute it.

See DD-024.

### Key bindings

`Mod` is the Super (Meta / Windows) key. This is a summary; `Mod+Shift+/` shows the live
list, generated from the config actually in use.

| Binding | Action |
|---|---|
| `Mod+T` | Terminal (WezTerm) |
| `Mod+Space` | Application launcher (DMS spotlight) |
| `Ctrl+Space` | Switch English/Pinyin input through Fcitx 5; always handled by Niri and never repeated (DD-050) |
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

### How WezTerm is configured

The image ships a system-wide WezTerm configuration. **Nothing points WezTerm at it** — it
is found by WezTerm's own search path, and a config of your own shadows it wholesale
(DD-034).

| Path in image | What it holds |
|---|---|
| `/etc/xdg/wezterm/wezterm.lua` | Font stack, colour scheme, window and tab-bar settings |
| `/etc/xdg/wezterm/colors/oxocarbon-dark.toml` | The scheme it selects, *Oxocarbon Dark* |
| `/etc/xdg/wezterm/colors/KAMSuperuser.toml` | An alternative scheme, on a commented line |

WezTerm takes the first of these that exists, so anything you create wins:

1. `$WEZTERM_CONFIG_FILE` — **not set by this image**, deliberately: it would come *before*
   your own files rather than after them
2. `~/.wezterm.lua`
3. `~/.config/wezterm/wezterm.lua`
4. `/etc/xdg/wezterm/wezterm.lua` ← this image, via `$XDG_CONFIG_DIRS`

To take it over, start from the shipped copy and edit freely:

```bash
qubix-config wezterm
```

That copies `wezterm.lua` and **not** the colour schemes, deliberately: they stay in
`/etc/xdg/wezterm/colors/`, where your own config still finds them and where they go on
tracking the image. To fork those too, `cp -r /etc/xdg/wezterm/colors ~/.config/wezterm/`.

Delete that file and you are back on the image's, including whatever a later rebase changed
in it. The colour schemes keep working either way: WezTerm looks for `colors/` in *every*
config directory, so `/etc/xdg/wezterm/colors/` stays available to your own `wezterm.lua`.
Note that a scheme's name is the `[metadata] name` inside the file, not its filename.

**Step 4 depends entirely on `$XDG_CONFIG_DIRS`.** WezTerm reads that variable literally and
does not apply the XDG specification's `/etc/xdg` default when it is unset, so a session
without it gets WezTerm's built-in theme and no explanation. The image guarantees the entry
in two places, because neither covers the other (DD-038):

| Where | Covers | Why the other one is not enough |
|---|---|---|
| `/usr/lib/environment.d/50-qubix-terminal.conf` | Everything the systemd **user manager** starts — `niri.service`, Plasma's units, and anything launched from them | It is the manager's environment; a shell over SSH, on a text console, or from `su -` is not its child and never sees it |
| `/etc/profile.d/qubix-shell-env.sh` | Every shell, and anything launched from one | It is not read by a unit the user manager starts directly |

Both **append** `/etc/xdg` rather than defaulting to it, and both put it last, so a session
that exports directories of its own keeps them and keeps their precedence. If the theme is
ever missing, this is the thing to check first:

```bash
echo "$XDG_CONFIG_DIRS"      # must contain /etc/xdg
wezterm ls-fonts | head -1   # must name Monaspace Krypton NF
```

**The fonts.** The font stack is a fallback chain — each glyph is drawn from the first
family that has it:

| Order | Family | Installed by |
|---|---|---|
| 1 | Monaspace Krypton NF | Upstream release, pinned and hash-checked at build time |
| 2 | IBM Plex Math | Upstream release, pinned and hash-checked at build time |
| 3 | IBM Plex Mono | `ibm-plex-mono-fonts` |
| 4 | IBM Plex Sans | `ibm-plex-sans-fonts` |
| 5–7 | Noto Sans CJK SC, TC, JP | `google-noto-sans-cjk-fonts` |
| last | Symbols Nerd Font Mono | Built into WezTerm — which is why no Nerd Font is named above |

CJK is Noto rather than IBM Plex Sans SC/TC/JP: those are published only as ~1.2 GB of
release archives and Fedora packages no CJK Plex at all. The order is kept, because it is
what decides which regional form a shared Han character is drawn in. The build **asserts**
that WezTerm resolves all seven, so a font that stops being installed fails CI rather than
turning into boxes on your screen.

**The window is transparent and not blurred.** `window_background_opacity = 0.75` is
carried over, but WezTerm never asks for a blurred background region on Wayland — KWin's
blur effect does not apply to it, and niri has no blur at all. What is behind the window
shows through at full detail. For an opaque window, set that to `1.0` in your own config.

What runs *inside* the terminal — the prompt, zsh and its plugins, history search, and the
editor — is [`shell.md`](shell.md).

## The default browser

**Ungoogled Chromium** is the default browser in both sessions, installed as a Flatpak from
Flathub and seeded on first boot. Firefox is not shipped, in either form — see DD-023.

Installing a browser does not make it the default, so two files claim it:

| Consumer | Mechanism | File |
|---|---|---|
| `xdg-open`, GTK/GIO apps, KIO | `http`, `https`, `about`, `unknown`, `text/html`, `application/xhtml+xml` → `io.github.ungoogled_software.ungoogled_chromium.desktop` | `/etc/xdg/mimeapps.list` |
| KDE's `OpenUrlJob`, which checks its own key first | `[General] BrowserApplication=io.github.ungoogled_software.ungoogled_chromium.desktop` | `/etc/xdg/kdeglobals` |

Both are fragments: only the web types are claimed, so PDFs stay with Okular and images
with Loupe. `~/.config/mimeapps.list` is searched first, so *System Settings → Default
Applications* — or `xdg-settings set default-web-browser …` — still overrides all of it,
per user.

## Simplified Chinese input

Qubix OS ships **Fcitx 5 with the Pinyin engine** for Simplified Chinese (`zh-Hans`)
input. The setup follows the same component split as the
[Rocky Linux 10 KDE reference guide](https://www.qubik65536.top/posts/2025-12-23-InstallChineseInputOnRockyWorkstation10KDE),
but every component is available as a signed Fedora package on the Aurora base. Nothing is
compiled locally and no EPEL or COPR repository is involved (DD-050).

| Piece | Package / file | Purpose |
|---|---|---|
| Framework | `fcitx5`, `fcitx5-autostart` | Runs Fcitx in graphical sessions and supplies Fedora's input-method environment |
| Chinese engine | `fcitx5-chinese-addons` | Pinyin, punctuation, cloud-Pinyin support, and related Chinese addons |
| Application bridges | `fcitx5-gtk`, `fcitx5-qt` | Covers GTK and Qt applications, including XWayland clients |
| KDE settings page | `kcm-fcitx5` | *System Settings → Keyboard → Input Method* |
| Default methods | `/etc/xdg/fcitx5/profile` | English (US), then Pinyin |
| Plasma toggle | `/etc/xdg/fcitx5/config` | `Super+Space` (Windows/Meta key + Space) switches between direct keyboard input and Pinyin |
| Niri toggle | `/etc/niri/config.kdl`, `/usr/bin/qubix-fcitx-toggle` | Non-repeating, non-inhibitable `Ctrl+Space` explicitly selects Pinyin or English through Fcitx's control interface |
| Plasma Wayland launch | `/etc/xdg/kwinrc` | Selects `/usr/share/applications/org.fcitx.Fcitx5.desktop` as KWin's input-method client |
| Native GTK Wayland path | `/etc/profile.d/zz-qubix-fcitx-wayland.sh` | Unsets Fedora's broad `GTK_IM_MODULE` export in Wayland sessions so GTK uses compositor text-input |
| GTK X11 fallback | `/etc/gtk-{3,4}.0/settings.ini` | Selects the packaged Fcitx module for GTK 3/4 clients running through X11 or XWayland |

Plasma starts Fcitx through KWin's dedicated Wayland input-method socket, which is the
equivalent of selecting **Fcitx 5** under *System Settings → Keyboard → Virtual Keyboard*.
Niri has no KWin, so Fedora's XDG autostart entry starts the same host binary there.
Fcitx's system fallback provides `Super+Space` in Plasma. Niri keeps `Mod+Space` for DMS's
application launcher and instead binds `Ctrl+Space` at the compositor level to
`qubix-fcitx-toggle`. The helper queries Fcitx's current engine and explicitly selects
`pinyin` or `keyboard-us`; it does not use the generic active/inactive `-t` operation,
which can be ignored by a focused Wayland input context. A failed D-Bus query or engine
selection produces a desktop notification instead of failing silently. The helper reads
the engine back after selection too, which catches a personal Fcitx profile that shadows
the image default but does not contain both engines.

If you copied the Niri config into `~/.config/niri/`, that personal file still wins: add
the `Ctrl+Space` binding there as well, or use `qubix-config --diff niri` to inspect the
image change.

The Niri toggle is `repeat=false` because a repeated toggle can switch to Pinyin and
immediately back to English. It is also `allow-inhibiting=false`, so a focused remote
desktop, VM, or other application cannot ask Niri to pass the shortcut through. Press
`Mod+Shift+/` and look for **Switch English/Pinyin Input**: if it is absent, Niri is loading
a personal `~/.config/niri/config.kdl` rather than the image default. Add this binding to
that file or compare it with `qubix-config --diff niri`:

```kdl
Ctrl+Space repeat=false allow-inhibiting=false hotkey-overlay-title="Switch English/Pinyin Input" { spawn "/usr/bin/qubix-fcitx-toggle"; }
```

Fedora's `fcitx5-autostart` package exports `GTK_IM_MODULE=fcitx` for every graphical
session. That is useful when a compositor lacks Wayland input-method support, but Niri and
KWin already provide a working native frontend. Qubix OS therefore unsets only that
variable in Wayland sessions. This resolves Fcitx's **Wayland Diagnose** duplicate-path
notification and lets native GTK 3/4 use text-input-v3; `XMODIFIERS` and the Qt fallback
remain available, while the GTK settings files retain the Fcitx module for GTK 3/4
X11/XWayland clients. The diagnostic is fixed at its cause rather than disabled.

The three image files are **fallbacks, not migrations**. Personal
`~/.config/fcitx5/profile`, `~/.config/fcitx5/config`, and `~/.config/kwinrc` files take
priority through Fcitx's XDG and KDE's KConfig cascades. The image never edits them. To
return only the Fcitx method list to the image default, move the personal profile aside
and log out once:

```bash
mv ~/.config/fcitx5/profile ~/.config/fcitx5/profile.backup
```

Use the KDE Input Method page to add another engine, change Plasma's `Super+Space`, or
enable Cloud Pinyin. Those changes create personal configuration and therefore survive
future rebases. Niri's `Ctrl+Space` is a compositor binding, so change that key in the
personal Niri config instead.
`fcitx5-diagnose` reports the running framework, loaded addons, environment, and the
profile path when input works in one application but not another.

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
