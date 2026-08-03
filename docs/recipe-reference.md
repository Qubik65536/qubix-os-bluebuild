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
| [`common-base.yml`](../recipes/common-base.yml) | Module list (included) | Overlay, packages, flatpaks, zsh-completions — shared by every image |
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
| `image-version` | `latest` | Tag of the base image. A **channel**, not a Fedora version. Tracks the current stable Fedora; `beta` is the alternative and tracks the next one. Was `beta` until DD-018. |

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
  | `/etc/xdg/kdeglobals` | KDE cascade fragment: default terminal (DD-012), default browser (DD-023) |
  | `/etc/xdg/mimeapps.list` | MIME association fragment: the web types → Ungoogled Chromium (DD-023) |
  | `/usr/lib/environment.d/50-qubix-terminal.conf` | `TERMINAL=wezterm` for every user session (DD-012) |
  | `/etc/niri/config.kdl` | System-default Niri configuration (DD-014) |
  | `/usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | Starts DankMaterialShell under Niri only (DD-015) |
  | `/etc/profile.d/qubix-shell-env.sh` | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, and bash's interactive setup (DD-026, DD-030) |
  | `/etc/zshenv` | Sources zsh's half. **Replaces** Fedora's, which is comments only (DD-030) |
  | `/etc/default/useradd` | `SHELL=/usr/bin/zsh` for accounts created from now on. **Replaces** shadow-utils' copy (DD-030) |
  | `/usr/share/qubix-os/shell/` | The interactive shell configuration itself (DD-026) |
  | `/usr/share/qubix-os/starship.toml` | The prompt, used unless the user has their own (DD-026) |
  | `/etc/fastfetch/config.jsonc` | The fastfetch box. fastfetch has no `/usr` config path, and `~/.config/fastfetch/` still wins (DD-031) |
  | `/usr/share/qubix-os/fastfetch/retune.sh` | Re-derives the box's columns after a logo change. Run by hand (DD-031) |

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
      - lihaohong/yazi
      - atim/lazygit
  install:
    packages:
      [micro, starship, wezterm, niri, dms,
       material-symbols-fonts, fira-code-fonts, rsms-inter-fonts, cliphist,
       zsh, zsh-autosuggestions, zsh-syntax-highlighting, atuin, bat, yazi, fastfetch,
       neovim, ripgrep, fd-find, fzf, lazygit, git, cascadia-mono-nf-fonts]
  remove:
    packages: [firefox, firefox-langpacks]
```

| Field | Effect |
|---|---|
| `repos.copr` | Enables COPR repositories before installing. See the table below. |
| `install.packages` | Layered RPMs. `micro` = terminal editor; `starship` = shell prompt; `wezterm` = default terminal emulator (DD-012); `niri` = the second desktop session (DD-013); `dms` plus the three font packages and `cliphist` = DankMaterialShell, Niri's desktop shell (DD-015); the rest is the terminal environment — see below and [`shell.md`](shell.md). |
| `remove.packages` | Removed RPMs. `firefox` goes because a browser belongs in a Flatpak (DD-006) and because the browser here is Ungoogled Chromium (DD-023); `firefox-langpacks` must be listed explicitly because dependency removal is not automatic. |

COPR repositories in use:

| COPR | Owner | Provides | Why not Fedora proper |
|---|---|---|---|
| `atim/starship` | third party | `starship` | Not in Fedora's main repos (DD-007) |
| `wezfurlong/wezterm-nightly` | WezTerm's own author | `wezterm`, `wezterm-common`, `wezterm-gui`, `wezterm-mux-server` | WezTerm is not packaged in Fedora at all (DD-012) |
| `avengemedia/dms` | DankMaterialShell's authors | `dms`, `dms-cli` | Not in Fedora (DD-015) |
| `avengemedia/danklinux` | DankMaterialShell's authors | `quickshell`, `dgop`, `matugen`, `material-symbols-fonts`, `cliphist`, … | `dms`'s runtime dependencies. **Required together with `avengemedia/dms`** — without it `dms` is uninstallable |
| `lihaohong/yazi` | third party | `yazi` | Not in Fedora's main repos (DD-026) |
| `atim/lazygit` | third party | `lazygit` | Not in Fedora's main repos. Same maintainer as `atim/starship` (DD-026) |

The terminal-environment packages, and why each is there:

| Package(s) | Role |
|---|---|
| `zsh` | The login shell. Nothing in the recipe can make it so — `/etc/passwd` is per machine — so `/etc/default/useradd` covers new accounts and an existing one takes one `chsh` (DD-030) |
| `zsh-autosuggestions`, `zsh-syntax-highlighting` | The two interactive zsh plugins. Loaded from `/usr/share/qubix-os/shell/qubix.zsh`, highlighting last |
| `atuin` | Local SQLite shell history. Wired into zsh only — its bash integration needs `bash-preexec`, which Fedora does not package |
| `bat` | `cat` with highlighting; aliased over `cat` in interactive shells |
| `yazi` | Terminal file browser, wrapped as `y` so quitting changes the shell's directory |
| `fastfetch` | System information, on demand. Nothing runs it automatically; the configuration is `/etc/fastfetch/config.jsonc` in the overlay (DD-031) |
| `neovim` | The editor and `$EDITOR`, configured with LazyVim (DD-027) |
| `ripgrep`, `fd-find`, `fzf`, `lazygit`, `git` | What LazyVim's default keymaps shell out to. Without them the keys exist and do nothing |
| `cascadia-mono-nf-fonts` | A Nerd Font, so the prompt's glyphs resolve outside WezTerm (which bundles its own fallback) |

- **Ordering:** must precede `default-flatpaks` so the Firefox RPM is gone before the
  Flatpak is queued, and precede the `containerfile` module below, which needs `zsh` and
  `git` installed.
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
      install: [io.github.ungoogled_software.ungoogled_chromium, org.gnome.Loupe]
    - scope: user
```

| Field | Effect |
|---|---|
| `scope: system` | Applies to all users; these applications are present for everyone. |
| `scope: user` | Second configuration block; adds the Flathub **user** remote with no packages, so per-user installs work immediately. |
| `notify: true` | Desktop notification when the install/uninstall pass finishes. |
| `install` | `io.github.ungoogled_software.ungoogled_chromium` — the default browser, replacing the removed Firefox RPM (DD-023); `org.gnome.Loupe` (image viewer). |

No `repo` is specified, so Flathub is used by default.

- **Ordering:** after `dnf` (DD-006).
- **Note:** flatpaks are *seeded*, not baked into the image — they are fetched on first
  boot by a systemd unit, so first boot needs network access.
- **`install` only.** The v2 module has no `remove:` key, so dropping an ID from this list
  stops *new* installs getting it and leaves it in place on machines that already have it.
  Removing it there is a manual `flatpak uninstall`.
- **IDs are checked at build time** against Flathub, so a typo fails the build rather than
  shipping an image missing an application.
- **Installing is not defaulting.** This module makes no MIME associations; the default
  browser is set by `/etc/xdg/mimeapps.list` and `/etc/xdg/kdeglobals` in the overlay
  (DD-023).

### 4. `containerfile` — zsh completions and login-shell check

*Defined in `common-base.yml`. Two snippets.*

```yaml
- type: containerfile
  snippets:
    - |
      RUN set -eu; \
          tmp="$(mktemp -d)"; \
          git clone --quiet --depth 1 --branch 0.36.0 \
              https://github.com/zsh-users/zsh-completions.git "$tmp"; \
          test "$(git -C "$tmp" rev-parse HEAD)" = "28c5bdcaf81bb89e56d0df8267d822c3b8aed9e0"; \
          install -d -m 0755 /usr/share/zsh/site-functions; \
          install -m 0644 "$tmp"/src/_* /usr/share/zsh/site-functions/; \
          rm -rf "$tmp"; \
          ls /usr/share/zsh/site-functions | wc -l
    - |
      RUN grep -qx '/usr/bin/zsh' /etc/shells
```

The second snippet is an assertion, not a change: zsh's `%post` appends itself to
`/etc/shells` on first install, and this fails the build if it ever stops.
`chsh` is how every account that already exists moves to zsh, and it validates against
`/etc/shells`. Without the entry it fails with *"chsh: /usr/bin/zsh is not a valid shell"*
and nothing explains why (DD-028, DD-030).

The first is a raw build step because there is nothing to install *from*: Fedora does not package
`zsh-completions`, and the `@zsh-users/zsh-completions` COPR has no build chroots at all —
not for the current Fedora, not for any. Checked against the COPR API rather than assumed.

- **The tag is not the pin; the commit is.** A tag can be moved, and a moved tag would
  silently change what ships. `rev-parse HEAD` is compared against the commit `0.36.0`
  pointed at when this was written, so that case fails the build instead. **Bumping the
  version means changing both lines.**
- `/usr/share/zsh/site-functions` is already on zsh's default `$fpath`, so nothing in the
  shell configuration has to add it.
- Its functions **shadow zsh's own** where both ship one for the same tool. That is what
  using zsh-completions means, not a bug to fix.
- The trailing `ls | wc -l` is there so the build log shows how many completion functions
  landed; a clone that produced nothing would otherwise pass silently.
- **Ordering:** after `dnf`, which installs `zsh` and `git`. Before the identity rewrite,
  though nothing forces that.

### 5. `containerfile` — raw build steps

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

### 6. `signing` — install the verification policy

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
  install:
    packages: [sbsigntools, mokutil]   # Secure Boot tooling, this variant only
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
| `sbsigntools`, `mokutil` | The CachyOS kernel is unsigned, so keeping Secure Boot on means signing it with your own key; shipping the tools keeps that procedure copy-pasteable ([`variants.md`](variants.md)) |

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
