# Context: `files/system/`

**Covers:** everything under `files/system/`

## Purpose

The image root overlay. The `files` module copies `files/system/*` verbatim into `/` in the
image, so **repository path = image path**. Two kinds of content live here: branding assets
(the bulk of it) and system-wide desktop configuration.

## Desktop configuration

| Path | Consumer | Effect |
|---|---|---|
| `etc/xdg/kdeglobals` | KDE Frameworks (KConfig cascade) | `TerminalApplication=wezterm` (DD-012); `BrowserApplication=io.github.ungoogled_software.ungoogled_chromium.desktop` (DD-023) |
| `etc/xdg/mimeapps.list` | `xdg-open`, GIO, KIO | Web MIME types → Ungoogled Chromium, i.e. the default browser (DD-023) |
| `etc/xdg/fcitx5/profile` | Fcitx 5 XDG config cascade | System fallback group with `keyboard-us` and `pinyin`; `~/.config/fcitx5/profile` wins and is never rewritten (DD-050) |
| `etc/xdg/fcitx5/config` | Fcitx 5 XDG config cascade | Native triggers are `Super+space` for Plasma and `Control+space` for Niri; Niri consumes only Super for DMS, while `~/.config/fcitx5/config` wins (DD-050) |
| `etc/xdg/kwinrc` | KWin / KDE's Virtual Keyboard KCM | Selects Fedora's host Fcitx desktop entry as Plasma's Wayland input method; `~/.config/kwinrc` wins (DD-050) |
| `etc/profile.d/zz-qubix-fcitx-wayland.sh` | graphical sessions and interactive shells | Sorts after Fedora's `fcitx5.sh` and unsets its global `GTK_IM_MODULE` only on Wayland; preserves `XMODIFIERS` and Qt compatibility (DD-050) |
| `etc/gtk-{3,4}.0/settings.ini` | GTK 3 and GTK 4 | Selects the packaged Fcitx module as the X11/XWayland fallback without forcing native Wayland clients away from compositor text-input; personal settings win (DD-050) |
| `usr/lib/environment.d/50-qubix-terminal.conf` | systemd user manager | `TERMINAL=wezterm` (DD-012); `XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:+…:}/etc/xdg`, without which the WezTerm config below is unreachable (DD-034). **Appends, not defaults**, and reaches only what the user manager starts — `etc/profile.d/qubix-shell-env.sh` carries the same append for every shell (DD-038) |
| `etc/xdg/wezterm/wezterm.lua` | WezTerm | System-wide config: font stack, `Oxocarbon Dark`, no title bar, 0.75 opacity. Found via `$XDG_CONFIG_DIRS`; `~/.config/wezterm/` shadows it wholesale (DD-034) |
| `etc/xdg/wezterm/colors/*.toml` | WezTerm | Two custom schemes. Found because `colors/` sits in a config dir, so they stay available to a user's *own* `wezterm.lua` (DD-034) |
| `usr/share/licenses/monaspace-krypton-nf/LICENSE` | nobody — legal | The OFL text for a font the recipe installs from upstream. **Vendored because Monaspace's archive ships none** (DD-034) |
| `etc/niri/config.kdl` | niri | System-default session config; DMS keybinds consume `Mod+Space` for the launcher but deliberately leave `Ctrl+Space` to Fcitx; explicitly unsets `GTK_IM_MODULE` for compositor-launched clients; `eDP-1` pinned to `scale 1`; window rule hiding the Xwayland Video Bridge; `include`s the theme (DD-014, DD-015, DD-019, DD-024, DD-050) |
| `etc/niri/qubix-theme.kdl` | niri, via `include` | The `#56728B` palette for niri. **Separate so a personal config can include it** and keep tracking the image (DD-022, DD-025) |
| `usr/share/qubix-os/dms-theme.json` | DankMaterialShell, as `customThemeFile` | The same palette for the shell. Watched by DMS, so a rebase reloads it live (DD-022, DD-025) |
| `usr/bin/qubix-dms-theme` | `qubix-dms-theme.service` | Enforces the theme pointer every Niri login and migrates DMS's native floating-bar settings plus the canonical cube launcher once per preset version. Version 2 makes `BarCanvas` transparent while retaining rounded `BasePill` backgrounds without outlines. Preserves widget arrays and unrelated settings; stamps completion under `$XDG_STATE_HOME/qubix-os/` (DD-025, DD-048). **Only executable in the overlay** |
| `usr/lib/systemd/user/qubix-dms-theme.service` | systemd user manager | Runs the theme/preset seeder `Before=dms.service`; pulled in by `niri.service`, never enabled globally (DD-025, DD-048) |
| `etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop` | XDG autostart / `systemd-xdg-autostart-generator` | **Replaces** the package's entry, adding `NotShowIn=niri;` so the bridge does not autostart under Niri (DD-021) |
| `usr/bin/qubix-video-bridge` | `Mod+Shift+B` and the launcher entry below | Toggles the bridge, with a notification. **Only executable in the overlay** — the git mode bit is what makes it runnable (IMG-013) |
| `usr/share/applications/qubix-video-bridge.desktop` | XDG application menu / DMS launcher | A **new** entry (upstream's is `NoDisplay=true`), `OnlyShowIn=niri;` (IMG-013) |
| `usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | systemd user manager | `Wants=dms.service`, so the shell starts under Niri **only** (DD-015) |

## Terminal environment

| Path | Consumer | Effect |
|---|---|---|
| `etc/profile.d/qubix-shell-env.sh` | sh, bash and zsh | `XDG_CONFIG_DIRS` (DD-038), `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, `LG_CONFIG_FILE`, and — at the end — bash's interactive setup (DD-026, DD-030, DD-032). Every exported value is **re-resolved in every shell**, and only ever rewritten when it holds the image's own literal path (DD-037) |
| `etc/profile.d/zz-qubix-fastfetch.sh` | interactive bash and zsh | Undoes Aurora's `alias fastfetch='ublue-fastfetch'`, without which `/etc/fastfetch/config.jsonc` — and the user's own — is never read. **Named `zz-` because `/etc/profile.d` is sourced alphabetically** and `qubix-shell-env.sh` sorts before `ublue-*` (DD-040) |
| `etc/default/useradd` | `useradd(8)` | `SHELL=/usr/bin/zsh`. **Replaces** shadow-utils' copy; only one line differs |
| `usr/bin/qubix-default-shell` | `qubix-default-shell.service` | Sets zsh as the login shell for existing accounts, once each, stamped in `/var/lib/qubix-os/default-shell/` (DD-035). Mode `100755` |
| `usr/lib/systemd/system/qubix-default-shell.service` | systemd, at boot | Runs the above `Before=systemd-user-sessions.service`. Enabled by the `systemd` module in `common-base.yml` |
| `usr/share/qubix-os/shell/common.sh` | `qubix.bash`, `qubix.zsh` | The `cat`→`bat` alias, the `y` yazi wrapper and the `lg` lazygit wrapper |
| `usr/share/qubix-os/shell/qubix.zsh` | zsh, from the block appended to `/etc/zshrc` | Prompt, atuin, both plugins, history defaults, `setopt interactive_comments` |
| `usr/share/qubix-os/shell/qubix.bash` | bash, from `/etc/profile.d` | Prompt and aliases. No atuin — see gotchas |
| `usr/share/qubix-os/starship.toml` | starship, as `$STARSHIP_CONFIG` | The prompt. Never copied into `$HOME` |
| `usr/share/qubix-os/lazygit/config.yml` | lazygit, as the **first** entry of `$LG_CONFIG_FILE` | Nerd Font icons + the `#56728B` palette. The user's config is appended after it and **merges over it key by key** (DD-032) |
| `etc/zellij/config.kdl` | zellij, when a user starts it | The Qubix theme. **The only system-wide path zellij reads**; `~/.config/zellij/` shadows it wholesale (DD-033) |
| `etc/fastfetch/config.jsonc` | fastfetch, when a user runs it | The system-wide default box. **The only system-wide path fastfetch reads** — its search path has no `/usr` entry (DD-031) |
| `usr/bin/qubix-config` | nobody — run by hand | Copies any shipped config into `~/.config`, lists them, diffs a copy against the image, and `--check`s its own paths. **Nothing runs it** — it is the alternative to a seeder, not one (DD-039). Mode `100755` |
| `etc/distrobox/distrobox.conf` | distrobox on the host, every subcommand | `container_init_hook="/run/host/usr/bin/qubix-distrobox-shell"`. Last system-wide file in distrobox's config hierarchy; the RPM owns nothing here, and ublue-os-just's `*.ini` manifests are untouched. **Flags beat it** — `--init-hooks` and an assemble `init_hooks=` key replace the hook (DD-043) |
| `usr/bin/qubix-distrobox-shell` | distrobox-init, **inside** a container, as root | Installs zsh, the plugins, starship, atuin and bat from the *container's* repositories, then fills the gaps from `/run/host` — text always, a host binary only after `--version` proves the container can run it; symlinks `/usr/share/qubix-os` → `/run/host/usr/share/qubix-os` and `/etc/profile.d/qubix-shell-env.sh` → the host's; writes the source block into the container's global `zshrc` between `# ── Qubix OS ──…` and `# ── end of the Qubix OS block ──…`, **replacing** any block already there, which is the only route a later fix has into a container that exists (DD-046). Idempotent — two runs give a byte-identical file — re-runnable by hand, **exits 0 from inside a container whatever happens**, and **never prints a line starting with `Error:`** (DD-043, DD-045). Mode `100755` |
| `usr/share/qubix-os/fastfetch/retune.sh` | nobody — run by hand | Re-derives the box's four columns after a logo change. Reads the gutter **two ways** — a cursor step on fastfetch ≤ 2.63, leading spaces on ≥ 2.64, which reworked logo printing (DD-042) — so it is coupled to how fastfetch renders and needs re-checking when that changes. Mode `100755` in the overlay |

**Nothing here writes to `$HOME`.** Configuration files, one hand-run tool, and one system
service that touches `/etc/passwd` (DD-030, DD-031, DD-035). An earlier design also seeded a
`source` line into `~/.zshrc` from a systemd *user* service and vendored the LazyVim starter;
both are gone. The login-shell service came back in DD-035, because the single `chsh` it was
traded for does not exist on Aurora — upstream deletes `/usr/bin/chsh` from the image.

Two constraints explain the rest of the layout:

- **`/etc/profile.d` cannot carry the zsh half.** Fedora's `/etc/zshrc` sources those files
  from inside a function running `emulate -L ksh`, so `KSH_ARRAYS` and `SH_WORD_SPLIT` are
  set — not the language zsh plugin scripts are written in. Environment variables and
  bash's setup only.
- **The end of `/etc/zshrc` is the zsh entry point**, appended there at build time by
  `common-base.yml` (DD-036). It is the last thing the *system* runs before `~/.zshrc`, and
  crucially it is after the `profile.d` loop, so `STARSHIP_CONFIG` and friends exist before
  the tools that read them start. `/etc/zshenv` held this until 2026-08-03 and ran too
  early; Fedora's file is not vendored, only appended to.
- **A distrobox container gets the same environment, and the same way** (DD-043): the same
  block appended to the container's global `zshrc`, the same `/etc/profile.d` file, both
  pointing at the host's files through `/run/host`. Only the binaries — starship, atuin, bat
  — are installed into the container, because they are compiled against the host's glibc.
  Two gotchas live in `qubix-distrobox-shell` rather than in the shell files: the plugins are
  at `/usr/share/zsh/plugins/` on Arch and Alpine, and bat is `batcat` on Debian and Ubuntu.
  **The hook may never exit non-zero** — `distrobox-init` `eval`s it under `set -e`, so a
  failure aborts container creation.
- **AND IT MAY NEVER PRINT A LINE STARTING WITH `Error:`** (DD-045). `distrobox enter`
  follows the container's log and switches on each line's prefix: `Error:` is printed and
  then **`exit 1`** — the enter is abandoned — `Warning:` prints yellow, `distrobox:` becomes
  the displayed step name, and everything else is discarded, stdout and stderr alike. dnf
  says `Error: Unable to find a match:` for a package a distribution does not carry, which is
  why every package manager in that script runs with its output captured to a file, and why
  the file is only echoed back re-prefixed. Anything added to that script inherits this rule.
- **A container's `$fpath` gets nothing from `/run/host`** (DD-046). `compaudit` cannot
  establish ownership through that bind mount — the host's root is an unmapped uid inside a
  rootless container — so any directory under it is "insecure" and every `compinit` without
  `-u` stops to ask, at the top of every shell. `-u` on the block's own `compinit` did not
  help: `~/.zshrc` runs later and Fedora's skeleton calls `compinit` plainly, and answering
  the prompt makes `compinit` drop the directory from `$fpath` regardless. Containers use
  their own completions; the guest block is a pointer and nothing else.

## Branding

- **Mechanism:** branding works by *overwriting upstream paths* (DD-004). Files are
  therefore named after the component that reads them, **not** after their contents.
- **Five distinct source images**, everything else is a byte-identical copy (DD-005):

  | Artwork | Form | Size | SHA-256 prefix | Copies live at |
  |---|---|---|---|---|
  | A | SVG logo mark | 1024×1024pt | `3ccc88c3…` | `pixmaps/qubixos-logo.svg`, `icons/hicolor/scalable/distributor-logo.svg` |
  | B | PNG logo mark | 512×512 | `f7448d03…` | `pixmaps/qubixos-logo.png`, `system-logo.png`, `system-logo-white.png`, `fedora-logo-sprite.png` |
  | C | SVG banner | 1600×450 | `46d7526f…` | `pixmaps/qubixos-banner.svg`, `aurora-banner.svg` |
  | D | PNG banner | 1600×450 | `38879687…` | `pixmaps/fedora-logo.png`, `fedora_logo_med.png` |
  | E | PNG watermark | 128×36 | `41ba5629…` | `plymouth/themes/spinner/watermark.png`, `kinoite-watermark.png`, `pixmaps/fedora-logo-small.png` |

- **Plasma splash (DD-049):** `usr/share/plasma/look-and-feel/com.qubixos.desktop/` is a
  Qubix-native, splash-only package selected by the distro-profile `ksplashrc`. Its QML
  reads the canonical `qubixos-logo.svg` and has no Aurora/KDE footer. Matching QML
  overrides live under both `dev.getaurora.aurora.desktop` and
  `dev.getaurora.auroralight.desktop` for existing users whose personal `ksplashrc` still
  names either Aurora ID. The old dark-theme `aurora_logo.svgz` remains Qubix artwork as a
  compatibility asset, although the active QML reads the canonical SVG directly.
- **Plymouth:** both spinner watermark paths are only the source files. Each recipe must
  run `initramfs` after the overlay or early boot keeps the Aurora bytes embedded by the
  base image (DD-049).
- **Text branding:**
  `usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc` — KDE "About this
  System". Sets `Name=Qubix OS`, a `Variant` string, and
  `LogoPath=/usr/share/pixmaps/system-logo.png`;
  `usr/share/kde-settings/kde-profile/default/xdg/ksplashrc` selects the Qubix splash for
  accounts without a higher-priority `~/.config/ksplashrc`.
- Logo primary colour: `#47603b`. **This is the logo's colour, not the project's accent.**
  The Niri session is themed from `#56728B` — `hsl(208, 24%, 44%)` — with every other tone
  derived by holding hue and saturation and moving only lightness (DD-022). Extending that
  palette means computing `hsl(208, 24%, L)`, not eyeballing something close.

## `/usr` vs `/etc`

Prefer `/usr` for configuration: `/etc` is three-way merged on updates, `/usr` is replaced
wholesale. Use `/etc` only where the consumer offers no `/usr` path that can be written
without clobbering an upstream file — currently `etc/xdg/kdeglobals` (DD-012, DD-023),
`etc/xdg/mimeapps.list` (DD-023; the `/usr` equivalent,
`/usr/share/applications/mimeapps.list`, exists upstream and Aurora appends to it),
`etc/niri/config.kdl` (DD-014; niri's config search path has no `/usr` entry), the
two terminal-environment files above — `/etc/profile.d` and `/etc/default/useradd` have no
`/usr` equivalent at all (DD-026, DD-030), and `/etc/zshrc` is appended to rather than
shipped (DD-036) — and
`etc/fastfetch/config.jsonc` (DD-031; fastfetch's config search path is `~/.config` →
`$HOME` → `$XDG_CONFIG_DIRS` → `/etc/xdg` → `/etc`, and `/usr/share/fastfetch/` is a
*data* dir for presets and logos, not a config dir), and `etc/zellij/config.kdl` (DD-033;
`/etc/zellij` is zellij's `SYSTEM_DEFAULT_CONFIG_DIR` and there is no `/usr` entry).

`etc/xdg/wezterm/`, `etc/xdg/fcitx5/profile`, and `etc/xdg/kwinrc` are XDG/KConfig
`/etc` cases and additions rather than replacements:
WezTerm's search path ends at `$XDG_CONFIG_DIRS`, which conventionally means `/etc/xdg`, and
has no `/usr` entry (DD-034).

Fcitx's package-config search falls back from `~/.config/fcitx5/` to
`$XDG_CONFIG_DIRS/fcitx5/` for both the profile and its `Super+space` plus
`Control+space` native triggers. Niri consumes the former for DMS and leaves the latter
unbound, so Fcitx receives `Ctrl+Space` directly without a compositor-spawned helper.
KWin's KConfig cascade similarly gives the user's `kwinrc` priority over
`/etc/xdg/kwinrc`. These make the Pinyin setup a default rather than a seeder or an
image-owned preference (DD-050).

Fedora's `fcitx5-autostart` also ships `/etc/profile.d/fcitx5.sh`, which exports
`GTK_IM_MODULE=fcitx` broadly. `zz-qubix-fcitx-wayland.sh` must continue sorting after that
package file: it removes the variable only when `XDG_SESSION_TYPE=wayland`, as upstream
recommends when the compositor frontend works. Do not replace it with notification
suppression. GTK 3/4 X11 fallback is deliberately carried by their two `settings.ini`
files instead (DD-050).

lazygit is the counter-example worth remembering: it also has no `/usr` path, but
`LG_CONFIG_FILE` takes a *list*, so its config stays in `/usr` and the user's file is
appended after it (DD-032). Check for an environment variable before reaching for `/etc`.

`/etc/default/useradd` is the one **replacement** of an upstream file rather than an
addition, which is normally forbidden here. It is justified in its own header: eight lines,
of which one differs. Re-check it against shadow-utils if that package changes it.
`/etc/zshenv` used to be a second such replacement and is not shipped any more (DD-036).

## Gotchas

- `fedora-logo.png`, `fedora_logo_med.png`, `fedora-logo-small.png`,
  `fedora-logo-sprite.png`, `aurora-banner.svg`, and `aurora_logo.svgz` all contain
  **Qubix** artwork. This is the override mechanism — do not "fix" the names.
- A personal `~/.config/ksplashrc` outranks the image's distro profile. If it names Breeze,
  the KDE splash is expected until the user selects **Qubix OS**; see `docs/branding.md`.
- `system-logo-white.png` is currently identical to `system-logo.png`, i.e. not actually a
  light variant. Tracked as open task `BRD-001`.
- macOS writes `.DS_Store` files into this tree while editing. They are gitignored and must
  stay that way, or the `files` module would copy them into `/usr/share/pixmaps/`.
- Changing artwork means updating **every** copy in the group above.
- **`qubix-config` hardcodes a table of paths, and the build checks it.** Adding a
  configuration to the image means adding a row to `entry()` in
  `usr/bin/qubix-config`, or it is the one thing a user cannot easily take over; moving one
  fails the build at module 4g (`qubix-config --check`), which is the point. Two entries copy
  **less** than they could on purpose — WezTerm's `colors/` and lazygit's merged config stay
  in the image so they go on tracking it — and **niri's copy is not a byte copy**: its
  relative `include "qubix-theme.kdl"` is rewritten to an absolute path, because a verbatim
  copy names a file that is not in `~/.config/niri/` and the session does not load (DD-039).
- **File modes carry through.** `usr/bin/qubix-video-bridge`, `usr/bin/qubix-dms-theme` and
  `usr/bin/qubix-config` and `usr/share/qubix-os/fastfetch/retune.sh` are executable only because git records mode
  `100755`; the `files` module copies the bit as it finds it. A rewrite that drops it
  produces a script that silently cannot run.
- **fastfetch's box is pinned to its logo, and the logo is pinned on purpose.** The four
  columns in `etc/fastfetch/config.jsonc` (spine 45, label 51, separator 61, right 112) are
  `gutter + 1/7/17/68`, and the gutter is `logo width + 6` of padding — the full `fedora`
  mark is 38 wide, so 44. Changing the logo without re-running `retune.sh` produces a box
  that does not close, and **deleting the `"logo"` block is a change of logo**: detection
  tries `ID`, `NAME`, then `ID_LIKE`, and the base image's `ID_LIKE=fedora` matches, so the
  block is not what chooses Fedora — it is what stops a fastfetch release or a base-image
  change from choosing something else (DD-041; DD-031 said "penguin", which was wrong).
- **Four files now carry the palette, and nothing enforces agreement.**
  `etc/niri/qubix-theme.kdl`, `usr/share/qubix-os/dms-theme.json`,
  `etc/zellij/config.kdl` and `usr/share/qubix-os/lazygit/config.yml` are the same
  `#56728B` ramp in four formats (DD-022, DD-032, DD-033). Drift is invisible until someone
  looks at two of them side by side. The structural tones are `hsl(208, 24%, L)`; the
  accents are `hsl(h, 55%, 50%)` — compute them, do not eyeball them. **zellij's accents are
  the same hues at L68**, not L50, because there every accent is text on a dark surface and
  L50 misses WCAG AA (magenta 3.6:1). That deviation is stated in the file with the ratios;
  do not "correct" it back.
- **`WEZTERM_CONFIG_FILE` must never be set by this image.** It looks like the natural twin
  of `STARSHIP_CONFIG` and `LG_CONFIG_FILE` and it is the opposite: WezTerm inserts it at the
  **front** of its search list, so setting it would make the image beat the user instead of
  losing to them. `/etc/xdg/wezterm/` is reached from the *back* of the list, which is the
  point (DD-034).
- **`XDG_CONFIG_DIRS` is load-bearing for the WezTerm config, and it takes TWO files.**
  WezTerm reads the variable and does **not** fall back to the spec's `/etc/xdg` default when
  it is unset, so the image guarantees the entry —
  `usr/lib/environment.d/50-qubix-terminal.conf` for everything the systemd **user manager**
  starts, and `etc/profile.d/qubix-shell-env.sh` for every shell, because environment.d does
  not reach a shell over SSH, on a text console, or from `su -`. Both **append** `/etc/xdg`
  last rather than defaulting to it: `:-` did nothing to a session that already exported a
  list without it. Deleting either line silently removes the WezTerm configuration from
  whichever half it covered (DD-038).
- **A WezTerm colour scheme's name is its `[metadata] name`, not its filename.** That string
  is what `color_scheme` in `wezterm.lua` has to match; renaming the `.toml` changes nothing
  and editing the metadata breaks the reference. The build catches the second case
  (`scheme was not found`), not the first.
- **The WezTerm font stack is asserted at build time**, family by family, so adding a name to
  it means adding the package or build step that supplies it — otherwise CI fails. CJK is
  `google-noto-sans-cjk-fonts` standing in for IBM Plex Sans SC/TC/JP, and the SC → TC → JP
  order decides which regional Han form is drawn; do not reorder it (DD-034).
- **Check `type -a` before believing a config search path.** A base image can rename a
  command out from under the file that configures it, and this one does: Aurora aliases
  `fastfetch` to `ublue-fastfetch`, which passes its own config explicitly, so DD-031's
  correctly-placed `/etc/fastfetch/config.jsonc` was unreachable for as long as it shipped —
  as was the user's own copy. Three rounds of diagnosis went into config paths, `/etc`
  merges and `$XDG_CONFIG_DIRS` before anybody ran `type -a fastfetch` (DD-040). Any future
  "my config is ignored" report starts there.
- **zsh does not comment with `#` on the command line unless told to.** `INTERACTIVE_COMMENTS`
  is off by default — in scripts `#` always comments, so this is invisible until somebody
  pastes a command with a trailing note and `?` in it globs. `qubix.zsh` sets it (IMG-029).
- **A guard may never test a variable the tools export.** This is the DD-037 rule and it
  broke every nested shell once already: `starship init` exports `STARSHIP_SHELL` and
  `atuin init` exports `ATUIN_SESSION`, so guarding on them asked "has any ancestor process
  done this?" and a zsh started from bash got no prompt. Interactive setup guards on a
  **function** (`_atuin_precmd`, `precmd_functions[(r)*starship*]`, `declare -F
  starship_precmd`), which a child cannot inherit; the exported values in
  `etc/profile.d/qubix-shell-env.sh` are re-resolved every time and matched against the
  image's own literal path before being rewritten. The graphical session reads that file
  too, which is why "once per shell" and "once per session" are not the same thing here.
- **`LG_CONFIG_FILE` must not name a file that does not exist.** lazygit errors out on a
  missing path in that list rather than skipping it, which is why the block in
  `etc/profile.d/qubix-shell-env.sh` tests for the user's config before appending it. Do not
  "simplify" it into one unconditional assignment.
- **Seed pointers, never contents.** DMS has no system-wide theme default, so the only
  lever is each user's `settings.json`. Writing the *path* there — with the palette in
  `/usr`, which DMS watches — is what makes a rebase update the colours with nothing
  re-run. Copying the palette into `$HOME` would freeze it at install time.
- **Palette policy and bar policy have different lifetimes.** `qubix-dms-theme` repairs
  the three custom-theme pointer keys every Niri login, but writes bar presentation only
  when its versioned state stamp is absent. It applies style keys to every valid bar and
  never replaces existing widget arrays. Remove the stamp and start the service to
  reapply; mask the unit to opt out of future migrations and pointer enforcement.
  `transparency=0` hides DMS's outer `BarCanvas`; `noBackground=false` retains each
  rounded `BasePill`, and `widgetOutlineEnabled=false` avoids a second shape around it.
  The corrected preset is version 2, so a version-1 stamp does not block it (DD-048).
- **Niri has no global scale setting** and no output wildcard. `output` matches a connector
  name or a `"manufacturer model serial"` triple, so `etc/niri/config.kdl` names `eDP-1`
  to pin the laptop panel to `scale 1` (DD-024). On a machine whose panel is called
  something else the block silently does nothing; on a genuinely HiDPI panel it makes text
  too small. Both are documented in the block itself.
- **The overlay cannot reach `$HOME` — and the shell no longer tries.** `qubix-dms-theme`
  is now the *only* thing that writes into a home directory, and it is a pointer it owns
  (DD-025). Do not add a second seeder for shell or editor configuration; that was tried
  and removed (DD-030).
- **The zsh block runs BEFORE `~/.zshrc`.** Two consequences, both intended: a user's own
  file always wins, and zsh-syntax-highlighting cannot wrap widgets defined there. Do not
  "fix" the second by writing into `~/.zshrc`.
- **The zsh block is APPENDED to Fedora's `/etc/zshrc`, not shipped as a file in the
  overlay.** Vendoring Fedora's 50 lines would mean owning them forever. The build asserts
  upstream's `_src_etc_profile_d` is present before appending, and `zsh -n` afterwards, so a
  base image that reorganises the file fails CI rather than a login (DD-036).
- **Nothing may be added below the syntax-highlighting line in `qubix.zsh`.** It wraps the
  ZLE widgets that exist when it is sourced.
- **atuin is configured from the environment, not a file**, because it reads every setting
  through `Environment::with_prefix("atuin")` with `__` as the nesting separator — so
  `ATUIN_AUTO_SYNC` is `auto_sync`. The block is **guarded on the user having no
  `~/.config/atuin/config.toml`**, and that guard is load-bearing: atuin applies the
  environment *after* the file, so without it the image would override the user.
- **atuin is wired into zsh only.** `atuin init bash` needs `bash-preexec`, which Fedora
  does not package. Do not "fix" `qubix.bash` by adding it — it fails at runtime, not at
  build time.
- **The Neovim config is not shipped at all.** `~/.config/nvim` is the user's, from a
  documented `git clone` of LazyVim's starter — which is also what makes `git pull` work.
  A vendored starter used to live here; it is gone (DD-030).
- **`chsh` DOES NOT EXIST on this image.** Aurora deletes `/usr/bin/chsh` and
  `/usr/bin/lchsh` (`build_files/base/16-override-install.sh`, "Footgun"). Every manual
  instruction must therefore say `usermod -s`, and the login shell for an account that
  already exists is set by `qubix-default-shell.service` — which is why that service exists
  at all, after being removed once as unnecessary (DD-035).
- **The login-shell service gets ONE attempt per account.** Every account it looks at is
  stamped in `/var/lib/qubix-os/default-shell/`, changed or not, so an account moved back to
  bash stays there. Removing the stamping would turn the image into something that overrules
  its owner every boot.
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
