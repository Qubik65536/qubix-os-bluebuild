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
| `usr/lib/environment.d/50-qubix-terminal.conf` | systemd user manager | `TERMINAL=wezterm` (DD-012); `XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:+…:}/etc/xdg`, without which the WezTerm config below is unreachable (DD-034). **Appends, not defaults**, and reaches only what the user manager starts — `etc/profile.d/qubix-shell-env.sh` carries the same append for every shell (DD-038) |
| `etc/xdg/wezterm/wezterm.lua` | WezTerm | System-wide config: font stack, `Oxocarbon Dark`, no title bar, 0.75 opacity. Found via `$XDG_CONFIG_DIRS`; `~/.config/wezterm/` shadows it wholesale (DD-034) |
| `etc/xdg/wezterm/colors/*.toml` | WezTerm | Two custom schemes. Found because `colors/` sits in a config dir, so they stay available to a user's *own* `wezterm.lua` (DD-034) |
| `usr/share/licenses/monaspace-krypton-nf/LICENSE` | nobody — legal | The OFL text for a font the recipe installs from upstream. **Vendored because Monaspace's archive ships none** (DD-034) |
| `etc/niri/config.kdl` | niri | System-default session config; DMS keybinds; `eDP-1` pinned to `scale 1`; window rule hiding the Xwayland Video Bridge; `include`s the theme (DD-014, DD-015, DD-019, DD-024) |
| `etc/niri/qubix-theme.kdl` | niri, via `include` | The `#56728B` palette for niri. **Separate so a personal config can include it** and keep tracking the image (DD-022, DD-025) |
| `usr/share/qubix-os/dms-theme.json` | DankMaterialShell, as `customThemeFile` | The same palette for the shell. Watched by DMS, so a rebase reloads it live (DD-022, DD-025) |
| `usr/bin/qubix-dms-theme` | `qubix-dms-theme.service` | Writes the *pointer* to the file above into `~/.config/DankMaterialShell/settings.json`. **Only executable in the overlay** (DD-025) |
| `usr/lib/systemd/user/qubix-dms-theme.service` | systemd user manager | Runs the seeder `Before=dms.service`; pulled in by `niri.service`, never enabled globally (DD-025) |
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
| `usr/share/qubix-os/fastfetch/retune.sh` | nobody — run by hand | Re-derives the box's four columns after a logo change. Mode `100755` in the overlay |

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

`etc/xdg/wezterm/` is a fourth `/etc` case, and an *addition* rather than a replacement:
WezTerm's search path ends at `$XDG_CONFIG_DIRS`, which conventionally means `/etc/xdg`, and
has no `/usr` entry (DD-034).

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
  columns in `etc/fastfetch/config.jsonc` (spine 23, label 29, separator 39, right 90) are
  `gutter + 1/7/17/68`, and the gutter is `logo width + 6` of padding. Detection would give
  a *different* logo — `ID=qubix_os_bluebuild` matches no builtin, so fastfetch falls back
  to a 23-wide penguin — which is why `source: fedora_small` is written out. Changing the
  logo without re-running `retune.sh` produces a box that does not close (DD-031).
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
