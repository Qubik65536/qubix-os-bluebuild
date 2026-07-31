# Recipe Reference

Reference for [`recipes/recipe.yml`](../recipes/recipe.yml) — the file that defines the
image. Modules execute **in file order**; see [`architecture.md`](architecture.md) for the
ordering constraints.

Upstream module documentation: <https://blue-build.org/reference/module/>

## Top-level keys

| Key | Value | Meaning |
|---|---|---|
| `name` | `qubix-os-bluebuild` | Image name. Published as `ghcr.io/<owner>/<name>`. Changing it changes the published image path and breaks existing rebases. |
| `description` | *(see file)* | Written into the image's OCI metadata. |
| `base-image` | `ghcr.io/ublue-os/aurora-dx` | The `FROM`. See DD-002. |
| `image-version` | `beta` | Tag of the base image. A **channel**, not a Fedora version. `latest` is the alternative. |

The file starts with a `yaml-language-server` schema comment; keep it, it gives editors
and agents live validation of the recipe.

## Modules

### 1. `files` — overlay the image root

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

- **Ordering:** no hard constraint. Kept first so content lands before anything that might
  read it.
- **Adding files:** create the file at its final image path under `files/system/`, then add
  a `.agent/context/` note if it introduces a new area.

### 2. `dnf` — package changes

```yaml
- type: dnf
  repos:
    copr:
      - atim/starship
      - wezfurlong/wezterm-nightly
  install:
    packages: [micro, starship, wezterm, niri, brightnessctl]
  remove:
    packages: [firefox, firefox-langpacks]
```

| Field | Effect |
|---|---|
| `repos.copr` | Enables COPR repositories before installing. See the table below. |
| `install.packages` | Layered RPMs. `micro` = terminal editor; `starship` = shell prompt; `wezterm` = default terminal emulator (DD-012); `niri` = the second desktop session (DD-013); `brightnessctl` = backlight control for Niri's brightness keys. |
| `remove.packages` | Removed RPMs. `firefox` is removed in favour of the Flatpak (DD-006); `firefox-langpacks` must be listed explicitly because dependency removal is not automatic. |

COPR repositories in use:

| COPR | Owner | Provides | Why not Fedora proper |
|---|---|---|---|
| `atim/starship` | third party | `starship` | Not in Fedora's main repos (DD-007) |
| `wezfurlong/wezterm-nightly` | WezTerm's own author | `wezterm`, `wezterm-common`, `wezterm-gui`, `wezterm-mux-server` | WezTerm is not packaged in Fedora at all (DD-012) |

- **Ordering:** must precede `default-flatpaks` so the Firefox RPM is gone before the
  Flatpak is queued.
- **Adding a package:** justify it. Aurora DX already includes the developer toolchain, so
  the first question is always "is this already here?" and the second is "should this be a
  Flatpak instead?"

### 3. `default-flatpaks` — Flatpak remotes and seeded applications

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

```yaml
- type: signing
```

Installs the cosign public key and the container policy files so that
`ostree-image-signed:` rebases verify against this repo's key. Takes no options.

- **Ordering:** last, by convention.
- Signing of the *published* image happens in CI, using `SIGNING_SECRET`; this module only
  sets up the *client-side* trust configuration inside the image. See
  [`build-and-release.md`](build-and-release.md).

## Modules available but not used

| Module | What it would do | Why it's unused |
|---|---|---|
| `script` | Run scripts from `files/scripts/` at build time | Nothing needs imperative build logic yet; `example.sh` is the untouched template placeholder. |
| `systemd` | Enable/disable units | No custom units. |
| `rpm-ostree` | Older package module | Superseded by `dnf`. |
| `bling`, `fonts`, `gschema-overrides`, … | Assorted conveniences | Not needed; see upstream docs before adding one. |

## Checklist for changing the recipe

1. Add a task in [`../.agent/plan.md`](../.agent/plan.md) with acceptance criteria.
2. Make the change, with a banner comment on the module explaining **why**.
3. If it's a judgement call, add a `DD-###` record in
   [`design-decisions.md`](design-decisions.md).
4. Update this page and `.agent/context/recipe.md`.
5. Push and confirm the CI build is green — there is no local build.
