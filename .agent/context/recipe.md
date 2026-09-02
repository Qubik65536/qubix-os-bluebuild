# Context: `recipes/`

**Covers:** `recipes/recipe.yml`, `recipes/common-*.yml`

## Purpose

The entire image definition. BlueBuild transpiles a *recipe* into a `Containerfile` and
builds it in CI. Everything the image *is* — beyond what it inherits from Aurora DX — is
described here or in `files/system/`.

## Essential details

### File kinds

| Pattern | Kind | Built? |
|---|---|---|
| `recipe.yml`, active `recipe-*.yml` | Recipe: identity keys + a module list | **Yes**, one CI job each |
| `recipe-nvidia-cachyos.yml` | Complete but parked experimental recipe | **No**, disabled by DD-052 |
| `common-*.yml` | Module list, spliced in with `from-file:` | No, only included |

- **Headers:** `yaml-language-server` schema comments — `recipe-v1` for recipes,
  `module-list-v1` for shared module lists. Keep them.
- **Shared files (DD-016):**
  - `common-base.yml` — modules 1–5: `files`, `dnf`, `default-flatpaks`, `containerfile`
    (terminal setup/assertions plus GRUB PF2 generation and manifest), and `systemd` (the
    login-shell and GRUB-theme services). Everything that makes an image "Qubix OS".
  - `common-identity.yml` — module 6: the `os-release` rewrite. Split out because of its
    ordering constraint (must run late).
  - `common-kernel-cachyos.yml` — the kernel swap. Both CachyOS recipes only.
  - `common-nvidia-cachyos.yml` — Negativo17 `akmod-nvidia`, a Fedora 44 compose-hook
    compatibility guard, a privilege-separated source build, and assertions for the
    replacement kernel. **`recipe-nvidia-cachyos.yml` only.**
- **`from-file:` takes no arguments.** A variant needing a different value re-does the work
  after the shared module; the shared file never grows a switch.

### `recipe.yml` (the standard image)

- **Identity:** `name: qubix-os-bluebuild` → published as
  `ghcr.io/qubik65536/qubix-os-bluebuild`. Changing it breaks existing rebases.
- **Base:** `ghcr.io/ublue-os/aurora-dx`; NVIDIA recipes use the matching
  `aurora-dx-nvidia-open`. Every recipe uses `image-version: latest`, a *channel*, not a
  Fedora version. `latest` is current stable and `beta` is next. Was `beta` until a
  pre-release amdgpu/Mesa regression hung the login compositor on hardware (DD-018).
- **Composition:** `from-file: common-base.yml` → `from-file: common-identity.yml` →
  `type: initramfs` → `type: signing`. Rendered module order:

  | # | Module | From | Effect | Ordering constraint |
  |---|---|---|---|---|
  | 1 | `files` | `common-base.yml` | Copies `files/system/*` → `/` (branding + desktop config) | none (kept first by convention) |
  | 2 | `dnf` | `common-base.yml` | COPRs `atim/starship`, `wezfurlong/wezterm-nightly`, `avengemedia/dms`, `avengemedia/danklinux`, `lihaohong/yazi`, `atim/lazygit`; install `micro`, `starship`, `wezterm` + its config's fonts (`ibm-plex-mono-fonts`, `ibm-plex-sans-fonts`, `google-noto-sans-cjk-fonts`) + `unzip`, `grub2-tools-extra` for PF2 generation, `niri`, `dms` + fonts + `cliphist`, Fcitx 5 + Chinese addons + autostart/toolkit/KDE integration, Plasma Discover + Flatpak backend, and the terminal environment (`zsh` + plugins, `atuin`, `bat`, `yazi`, `lazygit`, `fastfetch`, `neovim`, `ripgrep`, `fd-find`, `fzf`, `git`, `cascadia-mono-nf-fonts`); remove `firefox`, `firefox-langpacks` | before `default-flatpaks` and before module 4 |
  | 3 | `default-flatpaks` | `common-base.yml` | Flathub system + user; installs `io.github.ungoogled_software.ungoogled_chromium`, `org.gnome.Loupe` | after `dnf` (DD-006, DD-023) |
  | 4 | `containerfile` | `common-base.yml` | Thirteen snippets: nine terminal/setup assertions, bounded-range Monaspace Krypton NF → GRUB PF2 build/validation, Homebrew desktop/icon validation, an empty-home KDE/Breeze and DMS environment-boundary assertion, then Discover/compiled Plasma applet validation plus the Breeze launcher-alias rewrite | after `dnf`, `files`, and its own module 4d font install; the final three validations depend on installed/overlaid files — DD-026, DD-033…DD-046, DD-057, DD-062, DD-063, DD-066…DD-068 |
  | 5 | `systemd` | `common-base.yml` | Enables `qubix-default-shell.service`, `qubix-grub-theme.service`, and per-user `qubix-app-launcher-refresh.path`; the last stabilises fragile cask icons and refreshes Plasma/DMS indexes after Homebrew metadata changes | after `files`, which ships all units — DD-035, DD-057, DD-062 |
  | 6 | `containerfile` | `common-identity.yml` | `sed`-rewrites `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` | after anything that can regenerate `os-release` (DD-003) |
  | 7 | `initramfs` | `recipe.yml` | Rebuilds the stock kernel's archive with the overlaid Qubix Plymouth watermark | after `files`, late (DD-049) |
  | 8 | `signing` | `recipe.yml` | Installs the client-side cosign trust policy | last, by convention |

- **`os-release` result:** `ID=qubix_os_bluebuild`, `NAME="Qubix OS"`,
  `PRETTY_NAME="Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)"`. `NAME` drives the
  clean visual product label; `ID` and `PRETTY_NAME` retain technical provenance and all
  other upstream fields survive untouched (DD-065).

### CachyOS-kernel recipes

- **Identity:** `name: qubix-os-bluebuild-cachyos` → a *separate* image, so switching
  kernels is a rebase and the fallback is a published image (DD-017).
- Same overlay, packages, and flatpaks. Both kernel variants add
  `common-kernel-cachyos.yml` and a second `PRETTY_NAME` rewrite, then places its own
  `initramfs` run after that swap instead of using the standard recipe's placement.
- **The swap:** COPR `bieszczaders/kernel-cachyos`, then two `containerfile` snippets —
  (1) snapshot the package list and log `kmod-*`, `dnf5 remove` Fedora's five kernel
  packages, `rm -rf` the stock module dir, `dnf5 install --setopt=tsflags=noscripts`
  `kernel-cachyos{,-core,-modules,-devel-matched}`, `depmod`, assert one kernel with a
  `vmlinuz` and a `modules.dep`; (2) diff the package list and reinstall the
  libguestfs/`virt-v2v` stack and `virtualbox-guest-additions`.
- Also installs `sbsigntools` and `mokutil`—Secure Boot tooling in the active CachyOS
  image and parked combined recipe.
- **Requires x86-64-v3 hardware, and Secure Boot off unless the user signs the kernel.**
  The CachyOS `vmlinuz` has no PE signature and there is no vendor cert to enrol, so
  `docs/variants.md` documents the Machine Owner Key procedure. Neither requirement is
  checkable at build time. Signing in CI is open as `IMG-009`.

### NVIDIA recipes

- `recipe-nvidia.yml` publishes `qubix-os-bluebuild-nvidia` from
  `aurora-dx-nvidia-open:latest`. Fedora's kernel, NVIDIA Open module, userspace driver,
  and Universal Blue integration are inherited as one matched unit. Turing or newer only.
- `recipe-nvidia-cachyos.yml` is parked and is not selected or published by CI (DD-052).
  Its retained design would publish `qubix-os-bluebuild-nvidia-cachyos`: it runs the
  CachyOS swap, then `common-nvidia-cachyos.yml` installs `akmods`, temporarily suppresses
  Fedora 44's root-only ostree build hook while installing Negativo17 `akmod-nvidia`,
  restores the hook plus the standard `1777` modes on `/tmp` and `/var/tmp`, and invokes
  `akmods` against the one installed CachyOS kernel. Preflight checks prove the dedicated
  account can write both scratch directories before the orchestrator delegates compilation
  to it. The build asserts all five NVIDIA modules through `modinfo`, the open licence, and
  `nvidia-smi` before rebuilding initramfs (DD-051).
- The combined path is parked experimental work. BlueBuild's `akmods` module explicitly
  does not support custom kernels; a clean CI compile and real NVIDIA hardware remain
  prerequisites before publication can be restored.

## Gotchas

- **Where does a change go?** Every image → `common-base.yml`. One dimension → the
  matching shared variant module. One image → that recipe.
  Editing a shared file changes every active image and may affect the parked composition;
  check the three-job matrix is green.
- A `common-*.yml` file must **never** be added to the build matrix — it has no
  `name`/`base-image` and is not a buildable recipe.
- In the kernel swap, **remove before install**: `kernel-cachyos-core` declares
  `Provides: kernel`, so a later `dnf5 remove kernel` would take the new kernel out again.
- **`tsflags=noscripts` on the kernel install is required, not an optimisation.**
  `kernel-cachyos-core`'s `%posttrans` runs `kernel-install` → `05-rpmostree.install` →
  `dracut`, which dies on the missing `modules.dep` and fails the whole build. The build
  runs `depmod` itself instead. Removing that setopt reintroduces the failure.
- A kernel swap **must** be followed by the `initramfs` module. Nothing else generates
  `/usr/lib/modules/<kver>/initramfs.img` in a container build. Fedora-kernel recipes now
  runs the module too, for a different reason: Aurora's inherited archive predates the
  Qubix Plymouth overlay (DD-049). Do not move any run into `common-base.yml`; that is
  before the CachyOS swap.
- Removing `kernel-core` removes **every dependent package**, not just kernel modules —
  on Aurora DX that is libguestfs, `guestfs-tools`, `virt-v2v`, `libguestfs-appliance`,
  `libguestfs-xfs`, `virtualbox-guest-additions`, and `kernel-devel-matched`. All are
  restored afterwards. `kmod-*` packages are not, and cannot be.
- The `containerfile` snippet reads `IMAGE_VERSION` **before** rewriting, then interpolates
  it. Reordering the `sed` calls breaks `PRETTY_NAME`.
- `sed` patterns are anchored (`^ID=`) so they can't match `VERSION_ID=`. Keep the anchors.
- The third `sed` uses `|` as its delimiter because the replacement contains `/`.
- `firefox-langpacks` must be removed explicitly — dependency removal is not automatic.
  It looks redundant and is not.
- **No Firefox in either form, in any variant.** The browser is Ungoogled Chromium
  (DD-023). The RPM
  removal now has two reasons — packaging *and* not shipping a second browser — so do not
  "restore" it when reading DD-006 alone.
- **`default-flatpaks` v2 installs; it cannot uninstall.** The `configurations:` form has no
  `remove:` key (v1 did). Dropping an ID only affects fresh installs; existing machines keep
  the flatpak until the user removes it by hand. Flatpak IDs *are* validated against Flathub
  at build time, so a typo fails the build.
- **Installing a browser does not make it the default.** The association lives in the
  overlay — `files/system/etc/xdg/mimeapps.list` and the `BrowserApplication` key in
  `etc/xdg/kdeglobals`. Changing the browser here means changing all three.
- `wezterm` comes from **WezTerm's own** COPR and is a *nightly* build: versions are
  datestamps, not releases. There is no Fedora package (DD-012).
- `niri` is **additive**. Nothing KDE is removed (DD-013). Its weak dependencies (waybar,
  fuzzel, swaylock, GTK/GNOME portals) are left enabled on purpose — as a fallback, even
  though DankMaterialShell replaces the first three.
- `avengemedia/dms` and `avengemedia/danklinux` are a **pair**. The second holds `dms`'s
  runtime dependencies (`quickshell`, `dgop`, `matugen`, `material-symbols-fonts`,
  `cliphist`); enabling only the first leaves `dms` uninstallable (DD-015).
- DMS's fonts are **not** hard RPM dependencies, so they are listed explicitly. Without
  `material-symbols-fonts` every icon in the shell is a missing-glyph box.
- Fcitx is **packaged, not compiled** (DD-050). `fcitx5-chinese-addons` supplies Pinyin;
  `fcitx5-autostart` covers Niri and Fedora's compatibility environment; `kcm-fcitx5`
  supplies KDE's settings page. The system profile, native `Super+space` and
  `Control+space` triggers, KWin selection, and Wayland GTK environment correction live in
  the overlay. Niri consumes Super for DMS and leaves Control to Fcitx. The environment
  correction unsets Fedora's broad `GTK_IM_MODULE` on Wayland and retains GTK 3/4 X11
  fallback through system settings. Its desktop-aware branch also clears Qt/SDL in Plasma
  after nested profile loads. Module 4l additionally prefixes Plasma's installed Wayland
  session command with `env -u` for GTK/Qt/SDL, guaranteeing the parent starts clean;
  Niri retains the Qt module and both retain XIM (DD-067).
- DMS itself is isolated from KDE's Qt platform plugin, while its supported default launch
  prefix adds that integration back only for applications opened from the shell; a personal
  DMS launch prefix wins (DD-066).
- Plasma Discover is installed with its Flatpak backend because Kickoff pins its desktop ID.
  Module 4m proves both pieces and the compiled Kickoff/Kicker applets, then replaces every
  installed instance of four Breeze KDE/Plasma alias families with the canonical Qubix
  distributor logo. Plasma 6.7 ships no editable applet schema XML (DD-068).
- **`zsh-completions` is a build step, not a package.** Fedora does not ship it and the
  `@zsh-users/zsh-completions` COPR has **no chroots at all** — verified against the COPR
  API, so do not "simplify" it back into the `dnf` list. The clone is pinned by tag *and*
  asserted by commit hash: bumping it means changing **both**, and a moved tag fails the
  build on purpose (DD-026).
- `git` is in the package list on purpose: the module above it needs `git clone`, and
  "Aurora DX surely has git" is not something a build should rest on.
- **`zellij` is not a package and must not become a COPR line.** Fedora does not ship it
  (no `zellij`, no `rust-zellij` in dist-git) and — unlike yazi — upstream endorses no
  COPR; the ones that exist are one-person repos with a handful of builds. It comes from
  upstream's own `no-web` musl release, pinned by version and asserted by the SHA-256 **of
  the binary inside the tarball** (the published `.sha256sum` covers the binary, not the
  archive). **Bumping means changing both the version and the hash** (DD-033).
- The zellij snippet redirects `HOME` into its temp dir: zellij creates a cache directory on
  every invocation, and the build container's `/root` must not ship. Its last two `grep`s
  are the real assertion — `zellij setup --check` exits 0 even when the config is broken,
  so the greps are what turn a malformed `/etc/zellij/config.kdl` into a build failure.
- **Two of WezTerm's fonts are build steps, not packages** (DD-034). Fedora has no
  `monaspace-fonts` in any form, and `ibm-plex-fonts` 6.4.0 ships no `math` subpackage —
  checked against the repository metadata, so do not "simplify" either into the `dnf` list.
  Both are pinned by version and asserted by SHA-256; **bumping means changing both halves of
  a pair**, and re-checking the OFL text vendored in the overlay against the new tag.
  `-x '*Wide*'` on the Monaspace unzip is deliberate — the archive carries every weight three
  times over — and the `-eq 14` after it is what turns a reorganised archive into a build
  failure.
- **The WezTerm snippet is an assertion and its greps are the whole point.**
  `wezterm ls-fonts` exits 0 on a Lua syntax error, an unknown colour scheme *and* a missing
  font, exactly like `zellij setup --check`. Running it with `HOME` in a temp dir and
  `XDG_CONFIG_DIRS=/etc/xdg` is what makes it a test of resolution rather than of the file:
  nothing but `/etc/xdg/wezterm/wezterm.lua` can make `Monaspace Krypton NF` the primary
  font. Do not swap it for `--config-file`, which proves nothing about the search path.
- **Write every assertion as `if grep …; then echo …; exit 1; fi`, never as `! grep …`.**
  `set -e` ignores a command whose status is inverted with `!`, so the `!` form reads like an
  assertion and cannot fail a build. One had shipped that way since DD-034; both are fixed
  (MNT-003). Rehearse a new one locally before trusting it.
- `unzip` is in the package list for module 4d, the same way `git` is there for 4a. Removing
  the font snippet means removing it too.
- **lazygit is a tool, not just a LazyVim dependency** (DD-032). Its config lives in the
  overlay at `/usr/share/qubix-os/lazygit/config.yml` and is reached through
  `LG_CONFIG_FILE`; removing the package also means removing that wiring and the `lg`
  wrapper in `shell/common.sh`.
- **`qubix-config` is asserted because it hardcodes paths.** `/usr/bin/qubix-config` copies
  the image's configuration into a user's `~/.config` on request (DD-039), and it names six
  source paths literally. Snippet 4g runs `bash -n` and `qubix-config --check`, which fails
  the build when one of those paths moves or when niri's relative theme include — the one
  the command rewrites on copy — is renamed. **Adding a config to the image means adding a
  row to that command's table**; nothing can assert *that* omission.
- **Snippet 4h asserts a RESULT, not a file order, and that is the point.** Aurora aliases
  `fastfetch` to its own wrapper from `/etc/profile.d/ublue-fastfetch.sh`, which beat the
  whole config search path (DD-040). The undo is `zz-qubix-fastfetch.sh`, which works only
  because `/etc/profile.d` is sourced alphabetically — fragile, and invisible when it breaks,
  so the snippet sources every file the way a shell does and then checks the alias is gone.
  Rehearsed against a `zzz-*.sh` that reinstates it.
- **Snippet 4i guards a hook that runs in someone else's container** (DD-043).
  `/etc/distrobox/distrobox.conf` points distrobox at
  `/run/host/usr/bin/qubix-distrobox-shell`, which distrobox-init `eval`s as root inside
  every container it creates. Four assertions: **distrobox is in the image** (it comes from
  the base, not from the `dnf` module, so it could vanish silently); **`distrobox-create`
  still names `/etc/distrobox/distrobox.conf`** — an implementation detail of a tool whose
  2.0 rewrite is a Go binary, so a change fails CI instead of producing bare containers;
  **the config and the script agree**, read by sourcing the config the way distrobox does;
  and **the script still writes both block markers** (DD-046) — the block it puts in a
  container's `zshrc` is replaced by range on the next run, and losing the end marker means
  appending a second block inside a container no build can inspect.
  The hook itself may never exit non-zero: distrobox-init runs with `set -o errexit`.
- **Nothing runs `qubix-config`, and nothing may be added that does.** It is the alternative
  to the runtime seeders IMG-019 removed, not a quieter version of them: an account that
  never runs it keeps tracking the image, which is the property the whole design is for
  (DD-030, DD-039).
- **Installing the shell tools is half the job.** The configuration is in the overlay
  (`etc/profile.d/`, `usr/share/qubix-os/shell/`,
  `etc/fastfetch/`, `etc/zellij/`, `etc/xdg/wezterm/`, `usr/share/qubix-os/lazygit/`).
  Adding a package here does not put it in anyone's shell.
- `fastfetch` is installed for the config that ships with it (DD-031), and **nothing runs
  it** — not a login banner, not a shell startup hook. Do not add one; a 200 ms picture on
  every prompt is exactly what the rest of this design avoids.
- `zsh` is the login shell, and nothing in `recipes/` can make it so directly:
  `/etc/passwd` is per machine. `files/system/etc/default/useradd` covers accounts created
  from now on, and the `systemd` module enables `qubix-default-shell.service` for the ones
  that already exist (DD-035). **`chsh` is not an alternative — Aurora deletes it from the
  image** — which is why the second `containerfile` snippet asserts `usermod` exists. The
  `/etc/shells` half of that assertion is for a `chsh` a user layers back on; `usermod`
  never reads it.
- **The zsh wiring is APPENDED to `/etc/zshrc` by a build snippet, not shipped as a file**
  (DD-036). Fedora's copy carries the `/etc/profile.d` loop, so it is never replaced; the
  snippet greps for upstream's `_src_etc_profile_d` before appending and runs `zsh -n`
  after. `/etc/zshenv` held this until 2026-08-03 and ran before `/etc/profile.d`, which
  meant the tools were initialised before their environment existed.
- No templating in the `files` module. Anything needing a build-time value must go through
  `containerfile`.
- Flatpaks are seeded on first boot, not baked in.

## Update when

You change any module, add a package, add or remove a recipe, or change the base image.
Then also update `docs/recipe-reference.md`, and add a `DD-###` in
`docs/design-decisions.md` if the change is a judgement call.
