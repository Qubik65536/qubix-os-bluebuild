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
| `usr/lib/environment.d/50-qubix-terminal.conf` | systemd user manager | `TERMINAL=wezterm` (DD-012); `XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-/etc/xdg}`, without which the WezTerm config below is unreachable (DD-034) |
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
| `etc/profile.d/qubix-shell-env.sh` | sh, bash and zsh | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, `LG_CONFIG_FILE`, and — at the end — bash's interactive setup (DD-026, DD-030, DD-032) |
| `etc/zshenv` | zsh, on every invocation | Sources `qubix.zsh`. **Replaces** Fedora's file, which is comments only |
| `etc/default/useradd` | `useradd(8)` | `SHELL=/usr/bin/zsh`. **Replaces** shadow-utils' copy; only one line differs |
| `usr/share/qubix-os/shell/common.sh` | `qubix.bash`, `qubix.zsh` | The `cat`→`bat` alias, the `y` yazi wrapper and the `lg` lazygit wrapper |
| `usr/share/qubix-os/shell/qubix.zsh` | zsh, from `/etc/zshenv` | Prompt, atuin, both plugins, history defaults |
| `usr/share/qubix-os/shell/qubix.bash` | bash, from `/etc/profile.d` | Prompt and aliases. No atuin — see gotchas |
| `usr/share/qubix-os/starship.toml` | starship, as `$STARSHIP_CONFIG` | The prompt. Never copied into `$HOME` |
| `usr/share/qubix-os/lazygit/config.yml` | lazygit, as the **first** entry of `$LG_CONFIG_FILE` | Nerd Font icons + the `#56728B` palette. The user's config is appended after it and **merges over it key by key** (DD-032) |
| `etc/zellij/config.kdl` | zellij, when a user starts it | The Qubix theme. **The only system-wide path zellij reads**; `~/.config/zellij/` shadows it wholesale (DD-033) |
| `etc/fastfetch/config.jsonc` | fastfetch, when a user runs it | The system-wide default box. **The only system-wide path fastfetch reads** — its search path has no `/usr` entry (DD-031) |
| `usr/share/qubix-os/fastfetch/retune.sh` | nobody — run by hand | Re-derives the box's four columns after a logo change. Mode `100755` in the overlay |

**Nothing here writes to `$HOME`.** Configuration files, one hand-run tool, no units
(DD-030, DD-031). An earlier
design seeded a `source` line into `~/.zshrc` from a systemd user service, plus a system
service that ran `usermod` to set the login shell, plus a vendored LazyVim starter — all
removed as more machinery than the result justified.

Two constraints survive from that design and still explain the layout:

- **`/etc/profile.d` cannot carry the zsh half.** Fedora's `/etc/zshrc` sources those files
  from inside a function running `emulate -L ksh`, so `KSH_ARRAYS` and `SH_WORD_SPLIT` are
  set — not the language zsh plugin scripts are written in. Environment variables and
  bash's setup only.
- **`/etc/zshenv` is the zsh entry point** because Fedora's copy is comments only, so
  replacing it loses nothing, and it is plain zsh at top level. `/etc/zshrc` was rejected:
  it carries the `profile.d` loop itself, which we would then own forever.

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
three terminal-environment files above — `/etc/profile.d`, `/etc/zshenv` and
`/etc/default/useradd` all have no `/usr` equivalent at all (DD-026, DD-030) — and
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

The last two are **replacements** of upstream files rather than additions, which is
normally forbidden here. Both are justified in their own headers: Fedora's `/etc/zshenv`
is comments only, so nothing is lost, and `/etc/default/useradd` is eight lines of which
one differs. Both must be re-checked against upstream if either package changes them.

## Gotchas

- `fedora-logo.png`, `fedora_logo_med.png`, `fedora-logo-small.png`,
  `fedora-logo-sprite.png`, `aurora-banner.svg`, and `aurora_logo.svgz` all contain
  **Qubix** artwork. This is the override mechanism — do not "fix" the names.
- `system-logo-white.png` is currently identical to `system-logo.png`, i.e. not actually a
  light variant. Tracked as open task `BRD-001`.
- macOS writes `.DS_Store` files into this tree while editing. They are gitignored and must
  stay that way, or the `files` module would copy them into `/usr/share/pixmaps/`.
- Changing artwork means updating **every** copy in the group above.
- **File modes carry through.** `usr/bin/qubix-video-bridge`, `usr/bin/qubix-dms-theme` and
  `usr/share/qubix-os/fastfetch/retune.sh` are executable only because git records mode
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
- **`XDG_CONFIG_DIRS` is load-bearing for the WezTerm config.** WezTerm reads the variable
  and does **not** fall back to the spec's `/etc/xdg` default when it is unset, so
  `usr/lib/environment.d/50-qubix-terminal.conf` states it. Plasma sets it; niri does not.
  Deleting that line silently removes the whole WezTerm configuration in the Niri session.
- **A WezTerm colour scheme's name is its `[metadata] name`, not its filename.** That string
  is what `color_scheme` in `wezterm.lua` has to match; renaming the `.toml` changes nothing
  and editing the metadata breaks the reference. The build catches the second case
  (`scheme was not found`), not the first.
- **The WezTerm font stack is asserted at build time**, family by family, so adding a name to
  it means adding the package or build step that supplies it — otherwise CI fails. CJK is
  `google-noto-sans-cjk-fonts` standing in for IBM Plex Sans SC/TC/JP, and the SC → TC → JP
  order decides which regional Han form is drawn; do not reorder it (DD-034).
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
- **`/etc/zshenv` runs BEFORE `~/.zshrc`.** Two consequences, both intended: a user's own
  file always wins, and zsh-syntax-highlighting cannot wrap widgets defined there. Do not
  "fix" the second by writing into `~/.zshrc`.
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
- **The login shell needs one `chsh` on an existing account.** `/etc/default/useradd` only
  affects accounts created afterwards, and `/etc/passwd` is per machine. This is a
  documented limit, not an oversight — a boot service that edited `/etc/passwd` was tried
  and removed.
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
