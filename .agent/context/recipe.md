# Context: `recipes/recipe.yml`

**Covers:** `recipes/recipe.yml`

## Purpose

The entire image definition. BlueBuild transpiles this file into a `Containerfile` and
builds it in CI. Everything the image *is* — beyond what it inherits from Aurora DX — is
described here or in `files/system/`.

## Essential details

- **Header:** a `yaml-language-server` schema comment provides live validation. Keep it.
- **Identity:** `name: qubix-os-bluebuild` → published as
  `ghcr.io/qubik65536/qubix-os-bluebuild`. Changing it breaks existing rebases.
- **Base:** `ghcr.io/ublue-os/aurora-dx`, `image-version: beta`. `beta` is a *channel*, not
  a Fedora version (DD-002).
- **Five modules, executed in file order:**

  | # | Module | Effect | Ordering constraint |
  |---|---|---|---|
  | 1 | `files` | Copies `files/system/*` → `/` (branding + desktop config) | none (kept first by convention) |
  | 2 | `dnf` | COPRs `atim/starship`, `wezfurlong/wezterm-nightly`; install `micro`, `starship`, `wezterm`, `niri`, `brightnessctl`; remove `firefox`, `firefox-langpacks` | before `default-flatpaks` |
  | 3 | `default-flatpaks` | Flathub system + user; installs `org.mozilla.firefox`, `org.gnome.Loupe` | after `dnf` (DD-006) |
  | 4 | `containerfile` | `sed`-rewrites `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` | after anything that can regenerate `os-release` (DD-003) |
  | 5 | `signing` | Installs the client-side cosign trust policy | last, by convention |

- **`os-release` result:** `ID=qubix_os_bluebuild`, `NAME="QubixOS-BlueBuild"`,
  `PRETTY_NAME="Qubix OS (BlueBuild Image, Version: <IMAGE_VERSION>)"`. All other upstream
  fields survive untouched.

## Gotchas

- The `containerfile` snippet reads `IMAGE_VERSION` **before** rewriting, then interpolates
  it. Reordering the `sed` calls breaks `PRETTY_NAME`.
- `sed` patterns are anchored (`^ID=`) so they can't match `VERSION_ID=`. Keep the anchors.
- The third `sed` uses `|` as its delimiter because the replacement contains `/`.
- `firefox-langpacks` must be removed explicitly — dependency removal is not automatic.
  It looks redundant and is not.
- `wezterm` comes from **WezTerm's own** COPR and is a *nightly* build: versions are
  datestamps, not releases. There is no Fedora package (DD-012).
- `niri` is **additive**. Nothing KDE is removed (DD-013). Its weak dependencies (waybar,
  fuzzel, swaylock, GTK/GNOME portals) are left enabled on purpose — without them there is
  no usable session.
- No templating in the `files` module. Anything needing a build-time value must go through
  `containerfile`.
- Flatpaks are seeded on first boot, not baked in.

## Update when

You change any module, add a package, or change the base image. Then also update
`docs/recipe-reference.md`, and add a `DD-###` in `docs/design-decisions.md` if the change
is a judgement call.
