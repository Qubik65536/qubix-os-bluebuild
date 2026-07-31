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
  - `common-base.yml` — modules 1–3: `files`, `dnf`, `default-flatpaks`. Everything that
    makes an image "Qubix OS".
  - `common-identity.yml` — module 4: the `os-release` rewrite. Split out because of its
    ordering constraint (must run late).
  - `common-kernel-cachyos.yml` — the kernel swap. **`recipe-cachyos.yml` only.**
- **`from-file:` takes no arguments.** A variant needing a different value re-does the work
  after the shared module; the shared file never grows a switch.

### `recipe.yml` (the standard image)

- **Identity:** `name: qubix-os-bluebuild` → published as
  `ghcr.io/qubik65536/qubix-os-bluebuild`. Changing it breaks existing rebases.
- **Base:** `ghcr.io/ublue-os/aurora-dx`, `image-version: beta`. `beta` is a *channel*, not
  a Fedora version (DD-002).
- **Composition:** `from-file: common-base.yml` → `from-file: common-identity.yml` →
  `type: signing`. Rendered module order, unchanged by the split:

  | # | Module | From | Effect | Ordering constraint |
  |---|---|---|---|---|
  | 1 | `files` | `common-base.yml` | Copies `files/system/*` → `/` (branding + desktop config) | none (kept first by convention) |
  | 2 | `dnf` | `common-base.yml` | COPRs `atim/starship`, `wezfurlong/wezterm-nightly`, `avengemedia/dms`, `avengemedia/danklinux`; install `micro`, `starship`, `wezterm`, `niri`, `dms` + fonts + `cliphist`; remove `firefox`, `firefox-langpacks` | before `default-flatpaks` |
  | 3 | `default-flatpaks` | `common-base.yml` | Flathub system + user; installs `org.mozilla.firefox`, `org.gnome.Loupe` | after `dnf` (DD-006) |
  | 4 | `containerfile` | `common-identity.yml` | `sed`-rewrites `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` | after anything that can regenerate `os-release` (DD-003) |
  | 5 | `signing` | `recipe.yml` | Installs the client-side cosign trust policy | last, by convention |

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
- **Requires x86-64-v3 hardware and Secure Boot off.** Both documented in
  `docs/variants.md`; neither is checkable at build time.

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
- No templating in the `files` module. Anything needing a build-time value must go through
  `containerfile`.
- Flatpaks are seeded on first boot, not baked in.

## Update when

You change any module, add a package, add or remove a recipe, or change the base image.
Then also update `docs/recipe-reference.md`, and add a `DD-###` in
`docs/design-decisions.md` if the change is a judgement call.
