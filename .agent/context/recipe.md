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
| `recipe.yml`, `recipe-*.yml` | Recipe: identity keys + a module list | **Yes**, one CI job each |
| `common-*.yml` | Module list, spliced in with `from-file:` | No, only included |

- **Headers:** `yaml-language-server` schema comments — `recipe-v1` for recipes,
  `module-list-v1` for shared module lists. Keep them.
- **Shared files (DD-016):**
  - `common-base.yml` — modules 1–4: `files`, `dnf`, `default-flatpaks`, `containerfile`
    (zsh completions + login-shell check). Everything that makes an image "Qubix OS".
  - `common-identity.yml` — module 5: the `os-release` rewrite. Split out because of its
    ordering constraint (must run late).
  - `common-kernel-cachyos.yml` — the kernel swap. **`recipe-cachyos.yml` only.**
- **`from-file:` takes no arguments.** A variant needing a different value re-does the work
  after the shared module; the shared file never grows a switch.

### `recipe.yml` (the standard image)

- **Identity:** `name: qubix-os-bluebuild` → published as
  `ghcr.io/qubik65536/qubix-os-bluebuild`. Changing it breaks existing rebases.
- **Base:** `ghcr.io/ublue-os/aurora-dx`, `image-version: latest`. A *channel*, not a Fedora
  version: `latest` is the current stable Fedora, `beta` the next one. Was `beta` until a
  pre-release amdgpu/Mesa regression hung the login compositor on real hardware
  (DD-002, superseded by DD-018). **Both recipes must carry the same channel** — the
  variants are meant to differ only in the kernel.
- **Composition:** `from-file: common-base.yml` → `from-file: common-identity.yml` →
  `type: signing`. Rendered module order, unchanged by the split:

  | # | Module | From | Effect | Ordering constraint |
  |---|---|---|---|---|
  | 1 | `files` | `common-base.yml` | Copies `files/system/*` → `/` (branding + desktop config) | none (kept first by convention) |
  | 2 | `dnf` | `common-base.yml` | COPRs `atim/starship`, `wezfurlong/wezterm-nightly`, `avengemedia/dms`, `avengemedia/danklinux`, `lihaohong/yazi`, `atim/lazygit`; install `micro`, `starship`, `wezterm`, `niri`, `dms` + fonts + `cliphist`, and the terminal environment (`zsh` + plugins, `atuin`, `bat`, `yazi`, `fastfetch`, `neovim`, `ripgrep`, `fd-find`, `fzf`, `lazygit`, `git`, `cascadia-mono-nf-fonts`); remove `firefox`, `firefox-langpacks` | before `default-flatpaks` and before module 4 |
  | 3 | `default-flatpaks` | `common-base.yml` | Flathub system + user; installs `io.github.ungoogled_software.ungoogled_chromium`, `org.gnome.Loupe` | after `dnf` (DD-006, DD-023) |
  | 4 | `containerfile` | `common-base.yml` | Installs `zsh-completions` from a pinned tag into `/usr/share/zsh/site-functions`; asserts `/usr/bin/zsh` is in `/etc/shells` | after `dnf` (needs `zsh`, `git`) — DD-026, DD-028 |
  | 5 | `containerfile` | `common-identity.yml` | `sed`-rewrites `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` | after anything that can regenerate `os-release` (DD-003) |
  | 6 | `signing` | `recipe.yml` | Installs the client-side cosign trust policy | last, by convention |

- **`os-release` result:** `ID=qubix_os_bluebuild`, `NAME="QubixOS-BlueBuild"`,
  `PRETTY_NAME="Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)"`. All other upstream
  fields survive untouched.

### `recipe-cachyos.yml` (the CachyOS-kernel variant)

- **Identity:** `name: qubix-os-bluebuild-cachyos` → a *separate* image, so switching
  kernels is a rebase and the fallback is a published image (DD-017).
- Same base, same overlay, same packages, same flatpaks. The only differences:
  `common-kernel-cachyos.yml`, a second `PRETTY_NAME` rewrite, and `initramfs` — in that
  order, between `common-base.yml` and `signing`.
- **The swap:** COPR `bieszczaders/kernel-cachyos`, then two `containerfile` snippets —
  (1) snapshot the package list and log `kmod-*`, `dnf5 remove` Fedora's five kernel
  packages, `rm -rf` the stock module dir, `dnf5 install --setopt=tsflags=noscripts`
  `kernel-cachyos{,-core,-modules,-devel-matched}`, `depmod`, assert one kernel with a
  `vmlinuz` and a `modules.dep`; (2) diff the package list and reinstall the
  libguestfs/`virt-v2v` stack and `virtualbox-guest-additions`.
- Also installs `sbsigntools` and `mokutil` — Secure Boot tooling, this variant only.
- **Requires x86-64-v3 hardware, and Secure Boot off unless the user signs the kernel.**
  The CachyOS `vmlinuz` has no PE signature and there is no vendor cert to enrol, so
  `docs/variants.md` documents the Machine Owner Key procedure. Neither requirement is
  checkable at build time. Signing in CI is open as `IMG-009`.

## Gotchas

- **Where does a change go?** Every image → `common-base.yml`. One image → that recipe.
  Editing a shared file changes every published image; check the whole matrix is green.
- A `common-*.yml` file must **never** be added to the build matrix — it has no
  `name`/`base-image` and is not a buildable recipe.
- In the kernel swap, **remove before install**: `kernel-cachyos-core` declares
  `Provides: kernel`, so a later `dnf5 remove kernel` would take the new kernel out again.
- **`tsflags=noscripts` on the kernel install is required, not an optimisation.**
  `kernel-cachyos-core`'s `%posttrans` runs `kernel-install` → `05-rpmostree.install` →
  `dracut`, which dies on the missing `modules.dep` and fails the whole build. The build
  runs `depmod` itself instead. Removing that setopt reintroduces the failure.
- A kernel swap **must** be followed by the `initramfs` module. Nothing else generates
  `/usr/lib/modules/<kver>/initramfs.img` in a container build.
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
- **No Firefox in either form.** The browser is Ungoogled Chromium (DD-023). The RPM
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
- **`zsh-completions` is a build step, not a package.** Fedora does not ship it and the
  `@zsh-users/zsh-completions` COPR has **no chroots at all** — verified against the COPR
  API, so do not "simplify" it back into the `dnf` list. The clone is pinned by tag *and*
  asserted by commit hash: bumping it means changing **both**, and a moved tag fails the
  build on purpose (DD-026).
- `git` is in the package list on purpose: the module above it needs `git clone`, and
  "Aurora DX surely has git" is not something a build should rest on.
- **Installing the shell tools is half the job.** The configuration is in the overlay
  (`files/system/etc/zshenv`, `etc/profile.d/`, `usr/share/qubix-os/shell/`,
  `etc/fastfetch/`). Adding a package here does not put it in anyone's shell.
- `fastfetch` is installed for the config that ships with it (DD-031), and **nothing runs
  it** — not a login banner, not a shell startup hook. Do not add one; a 200 ms picture on
  every prompt is exactly what the rest of this design avoids.
- `zsh` is the intended login shell, but nothing in `recipes/` can make it so:
  `/etc/passwd` is per machine. `files/system/etc/default/useradd` covers accounts created
  from now on; an existing one takes one `chsh` (DD-030). The second `containerfile`
  snippet asserts that zsh registered itself in `/etc/shells`, which is exactly what `chsh`
  validates against.
- No templating in the `files` module. Anything needing a build-time value must go through
  `containerfile`.
- Flatpaks are seeded on first boot, not baked in.

## Update when

You change any module, add a package, add or remove a recipe, or change the base image.
Then also update `docs/recipe-reference.md`, and add a `DD-###` in
`docs/design-decisions.md` if the change is a judgement call.
