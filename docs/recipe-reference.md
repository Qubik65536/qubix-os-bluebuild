# Recipe Reference

Reference for the files in [`recipes/`](../recipes/) — the definition of the image.
Modules execute **in composed file order**; see [`architecture.md`](architecture.md) for
the ordering constraints.

Upstream module documentation: <https://blue-build.org/reference/module/>

## The files

| File | Kind | Role |
|---|---|---|
| [`recipe.yml`](../recipes/recipe.yml) | Recipe (built) | The standard image: identity keys + composition |
| [`recipe-cachyos.yml`](../recipes/recipe-cachyos.yml) | Recipe (built) | The CachyOS-kernel image ([`variants.md`](variants.md)) |
| [`common-base.yml`](../recipes/common-base.yml) | Module list (included) | Overlay, packages, flatpaks — shared by every image |
| [`common-identity.yml`](../recipes/common-identity.yml) | Module list (included) | The `os-release` rewrite — shared by every image |
| [`common-kernel-cachyos.yml`](../recipes/common-kernel-cachyos.yml) | Module list (included) | The kernel swap — `recipe-cachyos.yml` only |

**`recipe*.yml` is built; `common-*.yml` is only ever included.** The build matrix names
recipe files explicitly, so a shared file is never built by accident. Rationale: DD-016.

Every file starts with a `yaml-language-server` schema comment — `recipe-v1` for recipes,
`module-list-v1` for shared module lists. Keep them; they give editors and agents live
validation.

## Top-level keys

Only recipes carry these; a `common-*.yml` file contains nothing but `modules:`.

| Key | Value in `recipe.yml` | Meaning |
|---|---|---|
| `name` | `qubix-os-bluebuild` (`qubix-os-bluebuild-cachyos` in the variant) | Image name. Published as `ghcr.io/<owner>/<name>`. Changing it changes the published image path and breaks existing rebases. **Each variant needs its own.** |
| `description` | *(see file)* | Written into the image's OCI metadata. |
| `base-image` | `ghcr.io/ublue-os/aurora-dx` | The `FROM`. See DD-002. |
| `image-version` | `beta` | Tag of the base image. A **channel**, not a Fedora version. `latest` is the alternative. |

## Composition

```yaml
# recipe.yml                        # recipe-cachyos.yml
modules:                            # modules:
  - from-file: common-base.yml      #   - from-file: common-base.yml
                                    #   - from-file: common-kernel-cachyos.yml
  - from-file: common-identity.yml  #   - from-file: common-identity.yml
                                    #   - type: containerfile   (PRETTY_NAME)
                                    #   - type: initramfs
  - type: signing                   #   - type: signing
```

`from-file:` takes a path relative to `recipes/` and splices that file's `modules:` list in
at this position. It takes **no arguments** — a variant that needs a different value does
its own module afterwards rather than the shared file growing a switch (DD-016).

## Modules

### 1. `files` — overlay the image root

*Defined in `common-base.yml`.*

```yaml
- type: files
  files:
    - source: system
      destination: /
```

Copies everything under `files/system/` into `/` in the image. `source` is relative to
`files/`. The mapping is literal and byte-for-byte — no templating, no variable
substitution.

- **Currently carries:** branding assets (full map in [`branding.md`](branding.md)) and
  system-wide desktop configuration:

  | Path in image | Purpose |
  |---|---|
  | `/etc/xdg/kdeglobals` | KDE cascade fragment: default terminal (DD-012) |
  | `/usr/lib/environment.d/50-qubix-terminal.conf` | `TERMINAL=wezterm` for every user session (DD-012) |
  | `/etc/niri/config.kdl` | System-default Niri configuration (DD-014) |
  | `/usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | Starts DankMaterialShell under Niri only (DD-015) |

- **Ordering:** no hard constraint. Kept first so content lands before anything that might
  read it.
- **Adding files:** create the file at its final image path under `files/system/`, then add
  a `.agent/context/` note if it introduces a new area.

### 2. `dnf` — package changes

*Defined in `common-base.yml`.*

```yaml
- type: dnf
  repos:
    copr:
      - atim/starship
      - wezfurlong/wezterm-nightly
      - avengemedia/dms
      - avengemedia/danklinux
  install:
    packages:
      [micro, starship, wezterm, niri, dms,
       material-symbols-fonts, fira-code-fonts, rsms-inter-fonts, cliphist]
  remove:
    packages: [firefox, firefox-langpacks]
```

| Field | Effect |
|---|---|
| `repos.copr` | Enables COPR repositories before installing. See the table below. |
| `install.packages` | Layered RPMs. `micro` = terminal editor; `starship` = shell prompt; `wezterm` = default terminal emulator (DD-012); `niri` = the second desktop session (DD-013); `dms` plus the three font packages and `cliphist` = DankMaterialShell, Niri's desktop shell (DD-015). |
| `remove.packages` | Removed RPMs. `firefox` is removed in favour of the Flatpak (DD-006); `firefox-langpacks` must be listed explicitly because dependency removal is not automatic. |

COPR repositories in use:

| COPR | Owner | Provides | Why not Fedora proper |
|---|---|---|---|
| `atim/starship` | third party | `starship` | Not in Fedora's main repos (DD-007) |
| `wezfurlong/wezterm-nightly` | WezTerm's own author | `wezterm`, `wezterm-common`, `wezterm-gui`, `wezterm-mux-server` | WezTerm is not packaged in Fedora at all (DD-012) |
| `avengemedia/dms` | DankMaterialShell's authors | `dms`, `dms-cli` | Not in Fedora (DD-015) |
| `avengemedia/danklinux` | DankMaterialShell's authors | `quickshell`, `dgop`, `matugen`, `material-symbols-fonts`, `cliphist`, … | `dms`'s runtime dependencies. **Required together with `avengemedia/dms`** — without it `dms` is uninstallable |

- **Ordering:** must precede `default-flatpaks` so the Firefox RPM is gone before the
  Flatpak is queued.
- **Adding a package:** justify it. Aurora DX already includes the developer toolchain, so
  the first question is always "is this already here?" and the second is "should this be a
  Flatpak instead?"

### 3. `default-flatpaks` — Flatpak remotes and seeded applications

*Defined in `common-base.yml`.*

```yaml
- type: default-flatpaks
  configurations:
    - notify: true
      scope: system
      install: [org.mozilla.firefox, org.gnome.Loupe]
    - scope: user
```

| Field | Effect |
|---|---|
| `scope: system` | Applies to all users; these applications are present for everyone. |
| `scope: user` | Second configuration block; adds the Flathub **user** remote with no packages, so per-user installs work immediately. |
| `notify: true` | Desktop notification when the install/uninstall pass finishes. |
| `install` | `org.mozilla.firefox` (replaces the removed RPM), `org.gnome.Loupe` (image viewer). |

No `repo` is specified, so Flathub is used by default.

- **Ordering:** after `dnf` (DD-006).
- **Note:** flatpaks are *seeded*, not baked into the image — they are fetched on first
  boot by a systemd unit, so first boot needs network access.

### 4. `containerfile` — raw build steps

*Defined in `common-identity.yml`.*

```yaml
- type: containerfile
  snippets:
    - |
      RUN IMAGE_VERSION=$(grep '^IMAGE_VERSION=' /usr/lib/os-release | cut -d= -f2 | tr -d '"') \
          && sed -i 's/^ID=.*/ID=qubix_os_bluebuild/' /usr/lib/os-release \
          && sed -i 's/^NAME=.*/NAME="QubixOS-BlueBuild"/' /usr/lib/os-release \
          && sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Qubix OS (BlueBuild Image, Version: ${IMAGE_VERSION})\"|" /usr/lib/os-release
```

The escape hatch: raw `Containerfile` directives injected at this point in the build. Used
once, to rewrite the system identity — see DD-003 for why this cannot be a static file.

Resulting fields:

| Field | Before (Aurora DX) | After |
|---|---|---|
| `ID` | `fedora` | `qubix_os_bluebuild` |
| `NAME` | `Fedora Linux` | `QubixOS-BlueBuild` |
| `PRETTY_NAME` | *(Aurora's)* | `Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)` |

Everything else in `os-release` is left untouched on purpose.

Implementation notes:
- Single `RUN`, chained with `&&` — one layer, fails atomically.
- Patterns are anchored with `^` so `ID=` cannot match `VERSION_ID=`.
- `IMAGE_VERSION` is captured **before** the rewrites.
- The third `sed` uses `|` as its delimiter because the replacement contains `/`.
- **Ordering:** must run after any module that can regenerate `os-release`.

### 5. `signing` — install the verification policy

*Defined in each recipe, last.*

```yaml
- type: signing
```

Installs the cosign public key and the container policy files so that
`ostree-image-signed:` rebases verify against this repo's key. Takes no options.

- **Ordering:** last, by convention.
- Signing of the *published* image happens in CI, using `SIGNING_SECRET`; this module only
  sets up the *client-side* trust configuration inside the image. See
  [`build-and-release.md`](build-and-release.md).

## Variant-only modules

These run in `recipe-cachyos.yml` and nowhere else. Full context:
[`variants.md`](variants.md), DD-017.

### V1. `dnf` + `containerfile` ×2 — the CachyOS kernel swap

*Defined in `common-kernel-cachyos.yml`, between `common-base.yml` and
`common-identity.yml`.*

```yaml
- type: dnf
  repos:
    copr:
      - bieszczaders/kernel-cachyos
- type: containerfile        # the swap
  snippets:
    - |
      RUN set -eu \
          && … remove Fedora's kernel, delete its module dir, \
             install CachyOS's with tsflags=noscripts, depmod \
          && test "$(ls -1 /usr/lib/modules | wc -l)" -eq 1
- type: containerfile        # put back what the removal took with it
  snippets:
    - |
      RUN set -eu \
          && … log the removed set, reinstall the libguestfs/virt stack
```

| Piece | Why it is written this way |
|---|---|
| A `containerfile` snippet, not `dnf` module fields | The **order** of remove-then-install is load-bearing, scriptlets must be disabled for the install only, and `depmod` has to run in between |
| Remove before install | `kernel-cachyos-core` declares `Provides: kernel`; removing "kernel" afterwards would remove the new kernel |
| `rm -rf /usr/lib/modules/<stock kver>` | RPM removal leaves generated files (`initramfs.img`, `modules.dep`) behind; two module directories make the image ambiguous |
| `--setopt=tsflags=noscripts` on the install | `kernel-cachyos-core`'s `%posttrans` runs `kernel-install` → `05-rpmostree.install` → `dracut`, which fails on the missing `modules.dep` and fails the build |
| `depmod -a "$KVER"` | The one part of the skipped scriptlets that matters; the `initramfs` module's dracut run needs `modules.dep` |
| `kernel-cachyos-devel-matched` | Replaces the `kernel-devel-matched` that came out with Fedora's kernel, so `akmods` has headers |
| `rpm -qa 'kmod-*'` before the removal | Prebuilt out-of-tree modules go with the stock kernel and cannot come back; this puts the list in the build log |
| The `comm` diff and reinstall | Removing `kernel-core` also removes the libguestfs/`virt-v2v` stack and `virtualbox-guest-additions`, which only need `kernel` — provided by the new kernel, so they are restored. The diff is logged so drift is visible |
| The `test` assertions | Fail the build at the swap rather than publishing an image that cannot boot |

- **Ordering:** after `common-base.yml`; **before** `common-identity.yml`; requires the
  `initramfs` module later in the same recipe.

### V2. `containerfile` — variant identity

*Defined in `recipe-cachyos.yml`, immediately after `common-identity.yml`.*

Rewrites `PRETTY_NAME` a second time, from scratch:

| Field | Standard | CachyOS variant |
|---|---|---|
| `PRETTY_NAME` | `Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)` | `Qubix OS (BlueBuild Image, CachyOS Kernel, Version: <IMAGE_VERSION>)` |

`ID` and `NAME` are deliberately left shared — same distribution, different build.

- **Ordering:** after `common-identity.yml`, which would otherwise overwrite it.

### V3. `initramfs` — regenerate the initramfs

*Defined in `recipe-cachyos.yml`.*

```yaml
- type: initramfs
```

Runs `dracut --add ostree --no-hostonly --reproducible` for every kernel in
`/usr/lib/modules`. Takes no options.

**Mandatory after a kernel swap.** Installing a kernel RPM inside a container build does
not produce an `initramfs.img`; on a normal system `rpm-ostree` does that on the client,
and there is no client at build time.

- **Ordering:** late — it should come after everything that affects early boot (dracut
  configuration, `modprobe.d`, Plymouth theming), so one run covers them all.

## Modules available but not used

| Module | What it would do | Why it's unused |
|---|---|---|
| `script` | Run scripts from `files/scripts/` at build time | Nothing needs imperative build logic yet; `example.sh` is the untouched template placeholder. |
| `systemd` | Enable/disable units | No custom units. |
| `rpm-ostree` | Older package module | Superseded by `dnf`. |
| `bling`, `fonts`, `gschema-overrides`, … | Assorted conveniences | Not needed; see upstream docs before adding one. |

## Checklist for changing the recipe

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md) with acceptance criteria.
2. Decide **where** it belongs: every image → `common-base.yml`; one image → that recipe.
3. Make the change, with a banner comment on the module explaining **why**.
4. If it's a judgement call, add a `DD-###` record in
   [`design-decisions.md`](design-decisions.md).
5. Update this page and `.agent/context/recipe.md`.
6. Push and confirm the CI build is green — for **every** recipe, not just the one you
   edited. There is no local build.
