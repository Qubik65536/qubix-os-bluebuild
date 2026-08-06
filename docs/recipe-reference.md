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
  - type: initramfs                 #   - type: initramfs
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
  | `/usr/lib/environment.d/50-qubix-terminal.conf` | `TERMINAL=wezterm` for every user session (DD-012), and `/etc/xdg` **appended** to `XDG_CONFIG_DIRS` so the file below is reachable (DD-034, DD-038). Reaches only what the systemd user manager starts; `/etc/profile.d/qubix-shell-env.sh` carries the same append for every shell |
  | `/etc/xdg/wezterm/wezterm.lua` | WezTerm's system-wide config. Found through `$XDG_CONFIG_DIRS`; `~/.config/wezterm/` shadows it (DD-034) |
  | `/etc/xdg/wezterm/colors/*.toml` | The colour schemes it selects. Available to a user's own `wezterm.lua` too (DD-034) |
  | `/usr/share/licenses/monaspace-krypton-nf/LICENSE` | The OFL text for a font installed in module 4d. Vendored because Monaspace's archive carries none (DD-034) |
  | `/etc/niri/config.kdl` | System-default Niri configuration (DD-014) |
  | `/usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf` | Starts DankMaterialShell under Niri only (DD-015) |
  | `/usr/bin/qubix-dms-theme` | Enforces DMS's Qubix Slate pointer and applies the versioned floating-component bar plus canonical cube launcher once (DD-025, DD-048) |
  | `/usr/lib/systemd/user/qubix-dms-theme.service` | Runs that migration before DMS under Niri; never enabled globally (DD-025, DD-048) |
  | `/etc/profile.d/qubix-shell-env.sh` | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, and bash's interactive setup (DD-026, DD-030) |
  | `/etc/default/useradd` | `SHELL=/usr/bin/zsh` for accounts created from now on. **Replaces** shadow-utils' copy (DD-030) |
  | `/usr/bin/qubix-default-shell` | Moves accounts that already exist to zsh, once each (DD-035) |
  | `/usr/bin/qubix-config` | Copies any shipped configuration into `~/.config` on request. **Nothing runs it** (DD-039) |
  | `/usr/lib/systemd/system/qubix-default-shell.service` | Runs it before logins are permitted. Enabled by module 5 (DD-035) |
  | `/usr/share/qubix-os/shell/` | The interactive shell configuration itself (DD-026) |
  | `/usr/share/qubix-os/starship.toml` | The prompt, used unless the user has their own (DD-026) |
  | `/usr/share/qubix-os/lazygit/config.yml` | lazygit's icons and palette, reached through `LG_CONFIG_FILE`; the user's config merges *over* it (DD-032) |
  | `/etc/zellij/config.kdl` | The zellij theme. `/etc/zellij` is zellij's only system-wide config dir, and `~/.config/zellij/` shadows it (DD-033) |
  | `/etc/fastfetch/config.jsonc` | The fastfetch box. fastfetch has no `/usr` config path, and `~/.config/fastfetch/` still wins (DD-031) |
  | `/usr/share/qubix-os/fastfetch/retune.sh` | Re-derives the box's columns after a logo change. Run by hand (DD-031) |
  | `/etc/distrobox/distrobox.conf` | `container_init_hook`, so every container distrobox creates runs the script below. The distrobox RPM owns no file here (DD-043) |
  | `/usr/bin/qubix-distrobox-shell` | Runs **inside** a container: installs the binaries from its repositories, links the rest from `/run/host`, and writes a delimited block into the container's `zshrc` that a re-run replaces (DD-043, DD-046) |

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
      [micro, starship, wezterm,
       ibm-plex-mono-fonts, ibm-plex-sans-fonts, google-noto-sans-cjk-fonts, unzip,
       niri, dms,
       material-symbols-fonts, fira-code-fonts, rsms-inter-fonts, cliphist,
       zsh, zsh-autosuggestions, zsh-syntax-highlighting, atuin, bat, yazi, fastfetch,
       neovim, ripgrep, fd-find, fzf, git, lazygit, cascadia-mono-nf-fonts]
  remove:
    packages: [firefox, firefox-langpacks]
```

| Field | Effect |
|---|---|
| `repos.copr` | Enables COPR repositories before installing. See the table below. |
| `install.packages` | Layered RPMs. `micro` = terminal editor; `starship` = shell prompt; `wezterm` = default terminal emulator (DD-012), and the `ibm-plex-*`, `google-noto-sans-cjk` and `unzip` entries behind it serve its shipped configuration (DD-034); `niri` = the second desktop session (DD-013); `dms` with `material-symbols-fonts`, `fira-code-fonts`, `rsms-inter-fonts` and `cliphist` = DankMaterialShell, Niri's desktop shell (DD-015); the rest is the terminal environment — see below and [`shell.md`](shell.md). |
| `remove.packages` | Removed RPMs. `firefox` goes because a browser belongs in a Flatpak (DD-006) and because the browser here is Ungoogled Chromium (DD-023); `firefox-langpacks` must be listed explicitly because dependency removal is not automatic. |

COPR repositories in use:

| COPR | Owner | Provides | Why not Fedora proper |
|---|---|---|---|
| `atim/starship` | third party | `starship` | Not in Fedora's main repos (DD-007) |
| `wezfurlong/wezterm-nightly` | WezTerm's own author | `wezterm`, `wezterm-common`, `wezterm-gui`, `wezterm-mux-server` | WezTerm is not packaged in Fedora at all (DD-012) |
| `avengemedia/dms` | DankMaterialShell's authors | `dms`, `dms-cli` | Not in Fedora (DD-015) |
| `avengemedia/danklinux` | DankMaterialShell's authors | `quickshell`, `dgop`, `matugen`, `material-symbols-fonts`, `cliphist`, … | `dms`'s runtime dependencies. **Required together with `avengemedia/dms`** — without it `dms` is uninstallable |
| `lihaohong/yazi` | third party | `yazi` | Not in Fedora's main repos (DD-026) |
| `atim/lazygit` | third party | `lazygit` | Not in Fedora's main repos. Same maintainer as `atim/starship` (DD-026, DD-032) |

The terminal-environment packages, and why each is there:

| Package(s) | Role |
|---|---|
| `zsh` | The login shell. Nothing in the recipe can make it so — `/etc/passwd` is per machine — so `/etc/default/useradd` covers new accounts and `qubix-default-shell.service` (module 5) covers the ones that already exist (DD-035) |
| `zsh-autosuggestions`, `zsh-syntax-highlighting` | The two interactive zsh plugins. Loaded from `/usr/share/qubix-os/shell/qubix.zsh`, highlighting last |
| `atuin` | Local SQLite shell history. Wired into zsh only — its bash integration needs `bash-preexec`, which Fedora does not package |
| `bat` | `cat` with highlighting; aliased over `cat` in interactive shells |
| `yazi` | Terminal file browser, wrapped as `y` so quitting changes the shell's directory |
| `fastfetch` | System information, on demand. Nothing runs it automatically; the configuration is `/etc/fastfetch/config.jsonc` in the overlay (DD-031) |
| `neovim` | The editor and `$EDITOR`, configured with LazyVim (DD-027) |
| `ripgrep`, `fd-find`, `fzf`, `git` | What LazyVim's default keymaps shell out to. Without them the keys exist and do nothing |
| `lazygit` | Git in a terminal UI, in its own right as well as behind LazyVim's `<leader>gg`. Configured from `/usr/share/qubix-os/lazygit/config.yml` through `LG_CONFIG_FILE`, and wrapped as `lg` (DD-032) |
| `cascadia-mono-nf-fonts` | A Nerd Font, so the prompt's glyphs resolve outside WezTerm (which bundles its own fallback) |

The packages WezTerm's own configuration needs (DD-034):

| Package(s) | Role |
|---|---|
| `ibm-plex-mono-fonts`, `ibm-plex-sans-fonts` | Entries 3 and 4 of WezTerm's font fallback chain. The two families ahead of them are not packaged by anyone and come from module 4d below |
| `google-noto-sans-cjk-fonts` | CJK coverage, standing in for IBM Plex Sans SC/TC/JP — published only as ~1.2 GB of release archives, and absent from Fedora's `ibm-plex-fonts`. The **static** package, not `-vf-`, because its `.ttc` files expose `Noto Sans CJK SC` / `TC` / `JP` as plain family names |
| `unzip` | Needed by module 4d, which unpacks two upstream font archives. Listed rather than assumed, for the same reason `git` is |

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

### 4. `containerfile` — build steps no module covers

*Defined in `common-base.yml`. Nine snippets: zsh completions, the login-shell assertions,
zellij, WezTerm's two upstream fonts, the WezTerm configuration assertion, the zsh wiring
appended to `/etc/zshrc`, the `qubix-config` assertion, the `fastfetch` alias assertion, and
the distrobox hook assertion.*

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
      RUN set -eu; \
          command -v usermod >/dev/null; \
          grep -qx '/usr/bin/zsh' /etc/shells
    - |
      RUN set -eu; \
          ver=0.44.3; \
          sha=a675b0106263113b9cb8f028649bad05c5d2283331fa62b2b36dd275aeaaa4d3; \
          … download zellij-no-web-x86_64-unknown-linux-musl.tar.gz, \
            sha256sum -c the extracted binary, install it to /usr/bin, \
            generate the zsh and bash completions, \
            assert `zellij setup --check` resolves and parses /etc/zellij/config.kdl
    - |
      RUN set -eu; \
          mono_ver=1.400; mono_sha=9b7f9505…; \
          plex_ver=1.1.0;  plex_sha=d85ed404…; \
          … download monaspace-nerdfonts-v${mono_ver}.zip and ibm-plex-math.zip, \
            sha256sum -c each archive, unzip the Krypton NF faces (minus *Wide*) \
            into /usr/share/fonts/, assert 14 of them, fc-cache
    - |
      RUN set -eu; \
          … HOME=<empty> XDG_CONFIG_DIRS=/etc/xdg wezterm ls-fonts, \
            then grep for each of the seven families it must have resolved, \
            and for the absence of `scheme was not found`
```

The second snippet is two assertions, not a change (DD-035):

- **`usermod` must exist.** It is what `qubix-default-shell.service` runs to move an account
  that already exists to zsh, and it is the *only* way to do that here: Aurora deletes
  `/usr/bin/chsh` from the image. A service whose tool is missing would fail silently at
  boot on somebody's machine, so the build checks instead.
- **`/usr/bin/zsh` must be in `/etc/shells`.** `usermod` never reads that file, so this is
  for everything else that does — a `chsh` layered back on with `util-linux-user`, and
  anything that declines to treat an account as interactive when its shell is unlisted. The
  entry comes from zsh's `%post` in the *base* image, since Aurora installs zsh itself.

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

The third installs **zellij**, which is neither a Fedora package nor available from a COPR
anyone upstream endorses (DD-033), so it comes from upstream's own release the same way
zsh-completions comes from upstream's own tag:

- **`no-web` build.** zellij 0.43 added a local web server. It is off by default; this build
  is compiled without the capability, so it is absent rather than disabled.
- **The hash is the pin.** The published `.sha256sum` covers the **binary inside** the
  tarball, so `sha256sum -c` is run against the extracted file. **Bumping the version means
  changing both lines**, from the release's `.sha256sum` file.
- **`HOME` is redirected** into the temp directory for every `zellij` invocation, because
  zellij creates a cache directory on startup and the build container's `/root` must not end
  up in the image.
- **Completions are generated by the binary that ships**, into `/usr/share/zsh/site-functions`
  and `/usr/share/bash-completion/completions`, so they can never describe a different
  version.
- **The last two `grep`s are the point.** `zellij setup --check` prints the config file it
  resolved and whether it parsed, and it exits 0 either way — so the greps turn a malformed
  `/etc/zellij/config.kdl`, or a config directory zellij would not have looked in, into a
  build failure instead of a surprise at someone's first login.

The fourth installs the two fonts **WezTerm's configuration names that no repository
packages** — Monaspace Krypton NF and IBM Plex Math (DD-034). Same pattern again: pinned
version, asserted SHA-256.

- **Two version/hash pairs**, from
  [Monaspace's releases](https://github.com/githubnext/monaspace/releases) and
  [IBM Plex's](https://github.com/IBM/plex/releases). **Bumping means changing both halves
  of a pair**, and re-checking the vendored OFL text against the new Monaspace tag.
- **The Nerd Font build, deliberately.** WezTerm bundles Symbols Nerd Font Mono, so plain
  Monaspace would draw the same glyphs — but only the patched build answers to the family
  name `Monaspace Krypton NF` that the config asks for.
- **Only the normal widths.** `-x '*Wide*'` drops the `SemiWide` and `Wide` faces, which are
  two thirds of the archive and which a terminal never asks for. The remaining count is
  asserted, so a reorganised archive fails here rather than shipping half a family.
- **315 MB downloaded, 31 MB shipped.** Monaspace publishes no per-family archive. The temp
  directory is removed in the same layer.
- **Licences.** IBM's archive carries one beside the font and it is installed from there;
  Monaspace's carries none, so the OFL text is vendored in the overlay at
  `/usr/share/licenses/monaspace-krypton-nf/LICENSE`.

The fifth is an assertion, not a change — the WezTerm counterpart of `zellij setup --check`:

- **`wezterm ls-fonts` exits 0 whatever is wrong**, so the greps are the assertion. It prints
  the family it resolved for every entry of the fallback chain, and drops the ones it could
  not load.
- **`HOME` points at an empty directory and `XDG_CONFIG_DIRS` at `/etc/xdg`**, which makes
  this a test of *resolution*: with no `~/.wezterm.lua` and no `~/.config/wezterm`, the only
  way `Monaspace Krypton NF` can be the primary font is if
  `/etc/xdg/wezterm/wezterm.lua` was found by the real search path and parsed.
- **A renamed colour scheme is caught separately.** WezTerm logs `scheme was not found` and
  carries on with its default, which the font greps would not notice.
- **Assertions here are written as `if grep …; then exit 1; fi`, never as `! grep …`.**
  `set -e` ignores a command whose status is inverted with `!`, so the `!` form cannot fail
  a build (MNT-003). Anything added to these snippets must follow the same shape.

The sixth wires zsh into the shell environment, by **appending** to Fedora's `/etc/zshrc`:

```yaml
    - |
      RUN set -eu; \
          grep -q '_src_etc_profile_d' /etc/zshrc; \
          ! grep -q 'qubix-os/shell/qubix.zsh' /etc/zshrc; \
          printf '%s\n' … 'if [[ -r /usr/share/qubix-os/shell/qubix.zsh ]]; then' \
                          '    source /usr/share/qubix-os/shell/qubix.zsh' \
                          'fi' >> /etc/zshrc; \
          zsh -n /etc/zshrc
```

- **The end of `/etc/zshrc` is the point of it.** It is after the `/etc/profile.d` loop, so
  the variables that configure these tools exist before the tools are initialised, and after
  Fedora's default `PROMPT` line. This was `/etc/zshenv` until DD-036, which ran before both.
- **Appended, not replaced.** `/etc/zshrc` carries real behaviour — that `profile.d` loop —
  so shipping our own copy would mean owning Fedora's forever. Only our block is added.
- **The first `grep` is the safety.** It fails the build if the base image ever ships an
  `/etc/zshrc` that is not Fedora's, rather than appending to something unknown. The second
  refuses to append twice.
- **`zsh -n` parses the result**, so a broken shell fails in CI instead of at a login.
- Fedora's `/etc/zshrc` has not changed since 2015, per the package changelog. That is why
  appending is a reasonable thing to do to it, and why the assertion is cheap.

The seventh asserts that `qubix-config` still names files that exist:

```yaml
    - |
      RUN set -eu; \
          bash -n /usr/bin/qubix-config; \
          test -x /usr/bin/qubix-config; \
          qubix-config --check
```

- **It hardcodes six source paths**, one per configuration it can copy, so a path that moves
  would turn into "not in this image" at somebody's terminal instead of failing here.
- **`--check` writes nothing and needs no home directory**, which is what lets it run in a
  build container as root. It reports both things that can rot: a missing source, and niri's
  *relative* theme include, which the command rewrites to an absolute path when it copies —
  if that include is ever renamed, a copied niri config would not load (DD-039).
- **`bash -n` runs first**, so a syntax error fails for the right reason rather than making
  `--check` exit non-zero and hiding which problem it was.

The eighth asserts that the name `fastfetch` reaches fastfetch (DD-040). Aurora's
`/etc/profile.d/ublue-fastfetch.sh` aliases it to `ublue-fastfetch`, which passes its own
`--config` — and an alias is resolved before `$PATH`, long before any config directory, so it
beat both `/etc/fastfetch/config.jsonc` and the user's own. `zz-qubix-fastfetch.sh` in the
overlay undoes that one alias.

- **It asserts the result, not the ordering.** The fix depends on `/etc/profile.d` being
  sourced alphabetically, which is a fragile thing to depend on and an invisible thing to
  break — a vendor file named `zzz-*.sh` would restore the alias silently. So the snippet
  sources *every* file in the directory the way a shell does and then asks whether the alias
  survived. Rehearsed against a `zzz-*.sh` that reinstates it, which fails as intended.

The ninth asserts that the distrobox hook can be reached and is what it claims (DD-043):

```yaml
    - |
      RUN set -eu; \
          command -v distrobox …; \
          grep -q '/etc/distrobox/distrobox.conf' /usr/bin/distrobox-create; \
          sh -n /usr/bin/qubix-distrobox-shell; \
          test -x /usr/bin/qubix-distrobox-shell; \
          … it must still write both block markers; \
          hook="$(sh -c '. /etc/distrobox/distrobox.conf; printf %s "$container_init_hook"')"; \
          … the hook must be /run/host/usr/bin/qubix-distrobox-shell, \
            and that path minus /run/host must be executable in this image
```

- **distrobox comes from the base image**, not from the `dnf` module — `ublue-os/main`'s
  `packages.json` installs it everywhere — so the config would become dead weight, silently,
  if upstream ever dropped it.
- **The `grep` guards an implementation detail.** distrobox's configuration search path is a
  list inside a shell script, and its 2.0 release replaces those scripts with a Go binary. If
  the path stops being read, this fails the build with a note to re-check it rather than
  producing containers that come up bare.
- **The hook is read the way distrobox reads it** — by sourcing the file — and the
  `/run/host` prefix is stripped so the script is checked to exist at that path in *this*
  image, which is where a container will look for it.
- **Both block markers must survive an edit** (DD-046). The script writes its block into a
  container's `zshrc` between `# ── Qubix OS ──…` and `# ── end of the Qubix OS block ──…`
  and deletes that range on the next run, which is the only way a change reaches a container
  that already exists. Drop the end marker and a re-run appends a second block instead of
  replacing the first — inside a container, where no build can see it. Grepping for the two
  literals is the only part of that a build *can* check.

- **Ordering:** after `dnf`, which installs `zsh`, `git`, `unzip`, `wezterm` and the packaged
  fonts; after the `files` module, which ships `/etc/zellij/config.kdl`,
  `/etc/xdg/wezterm/`, `/usr/share/qubix-os/shell/qubix.zsh`, `/usr/bin/qubix-config`,
  `/etc/distrobox/distrobox.conf`, `/usr/bin/qubix-distrobox-shell` and every path
  `qubix-config` names. The fifth snippet must follow the fourth. Before the identity
  rewrite, though nothing forces that.

### 5. `systemd` — enable the login-shell service

*Defined in `common-base.yml`.*

```yaml
- type: systemd
  system:
    enabled:
      - qubix-default-shell.service
```

The only unit this image enables, and the only thing in the terminal environment that is not
a file: it sets zsh as the login shell for accounts that already exist, which no image can do
declaratively because `/etc/passwd` is per machine (DD-035).

- The unit and its script are shipped by module 1; this module only enables it.
- It runs `Before=systemd-user-sessions.service`, so nobody is logged in while it rewrites
  `/etc/passwd`, and stamps each account in `/var/lib/qubix-os/default-shell/` so an account
  is only ever changed once. Full behaviour: [`shell.md`](shell.md#the-login-shell).
- **Ordering:** after `files`, which ships the unit. Nothing else depends on it.

### 6. `containerfile` — raw build steps

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

### 7. `initramfs` — embed the finished early-boot content

*Defined late in each recipe.*

```yaml
- type: initramfs
```

Runs `dracut --add ostree --no-hostonly --reproducible` for every kernel in
`/usr/lib/modules`. Takes no options.

The standard recipe needs this even though it does not replace the kernel. Aurora built
the inherited initramfs before Qubix's `files` module overlaid the Plymouth watermark, so
without another run the boot splash reads Aurora artwork from the old archive while the
Qubix file sits unused in `/usr`. See DD-049.

The CachyOS recipe has an independent, later placement because its kernel swap must run
first. Moving this module into `common-base.yml` would build the archive for the stock
kernel before that kernel is removed.

- **Ordering:** after everything that affects early boot (`files`, dracut configuration,
  `modprobe.d`, and, for CachyOS, the kernel swap); before `signing`.

### 8. `signing` — install the verification policy

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

### V3. CachyOS placement of `initramfs`

The module itself is documented above because both recipes now use it. In the CachyOS
variant it is additionally **mandatory after the kernel swap**: installing a kernel RPM
inside a container build does not produce an `initramfs.img`; on a normal system
`rpm-ostree` does that on the client, and there is no client at build time. Its late
placement covers both that requirement and Qubix's Plymouth branding in one dracut run.

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
