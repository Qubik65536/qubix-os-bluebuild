# Architecture

How a commit in this repository becomes a bootable operating system.

## The pipeline

```
 git push / weekly Sunday cron / manual dispatch
              │
              ▼
 ┌──────────────────────────────────────────┐
 │ .github/workflows/build.yml              │
 │  → blue-build/github-action@v1.11        │
 └──────────────────────────────────────────┘
              │  reads
              ▼
 ┌──────────────────────────────────────────┐
 │ recipes/recipe.yml   active recipe-*.yml │   one matrix job per active recipe
 │  + recipes/common-*.yml (shared modules) │
 │  BlueBuild renders each to a Containerfile│
 └──────────────────────────────────────────┘
              │  FROM Aurora DX or Aurora DX NVIDIA Open :latest
              ▼
 ┌──────────────────────────────────────────┐
 │ Modules execute in order (see below)     │
 └──────────────────────────────────────────┘
              │
              ▼
 ┌──────────────────────────────────────────┐
 │ cosign signs the image (SIGNING_SECRET)  │
 └──────────────────────────────────────────┘
              │
              ▼
   ghcr.io/qubik65536/qubix-os-bluebuild:latest
   ghcr.io/qubik65536/qubix-os-bluebuild-cachyos:latest
   ghcr.io/qubik65536/qubix-os-bluebuild-nvidia:latest
              │
              ▼
   rpm-ostree rebase on the user's machine
```

Each active recipe is an independent build producing an independently named,
independently signed image. The NVIDIA+CachyOS recipe is parked and absent from the
matrix (DD-052). What distinguishes them: [`variants.md`](variants.md).

BlueBuild is a **transpiler**, not a runtime: `recipe.yml` is turned into an ordinary
`Containerfile`, and the result is an ordinary OCI image. Nothing in this repo runs on a
user's machine at install time; everything happens at build time, once, in CI.

## Recipe layout

`recipes/` holds two kinds of file, distinguished by name:

| Pattern | Kind | Built? |
|---|---|---|
| `recipe.yml`, active `recipe-*.yml` | A complete image definition: identity keys plus a module list | **Yes** — one CI job each |
| `recipe-nvidia-cachyos.yml` | A complete but parked experimental definition | **No** — disabled by DD-052 |
| `common-*.yml` | A module list included by recipes with `from-file:` | No — only ever included |

Today there are three active recipes—standard, CachyOS, and NVIDIA—and one parked
NVIDIA+CachyOS recipe. All share `common-base.yml` and `common-identity.yml`; both
CachyOS definitions include
`common-kernel-cachyos.yml`, and the combined recipe then includes
`common-nvidia-cachyos.yml`.

The shared files make every additional image a *composition*, not a copy (DD-016):

```yaml
# recipes/recipe.yml
modules:
  - from-file: common-base.yml      # overlay, packages, flatpaks, build steps, one service
  - from-file: common-identity.yml  # the os-release rewrite
  - type: initramfs                 # embed the Qubix Plymouth watermark
  - type: signing
```

`from-file:` splices the referenced file's `modules:` list in at that position, so the
rendered `Containerfile` is exactly what a single flat recipe would have produced. Two
rules follow:

- **A change meant for every image goes in `common-base.yml`.** A change meant for one
  image goes in that recipe.
- **Ordering constraints cross file boundaries.** `common-identity.yml` is separate from
  `common-base.yml` because it must run last-but-one; a recipe composes the blocks in the
  order the constraints demand.

## Module execution order

Modules run **top to bottom** in the order the recipe composes them, each producing an
image layer. Order is load-bearing. For `recipe.yml`:

| # | Module | From | What it does | Why it is here |
|---|---|---|---|---|
| 1 | `files` | `common-base.yml` | Copies `files/system/*` to `/` (branding + desktop configuration) | Content must exist before anything reads it; nothing later depends on being first, but putting content first keeps later layers small. |
| 2 | `dnf` | `common-base.yml` | Adds COPRs `atim/starship`, `wezfurlong/wezterm-nightly`, `avengemedia/dms`, `avengemedia/danklinux`, `lihaohong/yazi`, `atim/lazygit`; installs `micro`, `starship`, `wezterm` and the fonts its config names, `grub2-tools-extra` for GRUB's PF2 converter, `niri`, `dms` and its fonts, Fcitx, and the terminal environment (`zsh` and its plugins, `atuin`, `bat`, `yazi`, `neovim` and what LazyVim calls); removes `firefox`, `firefox-langpacks` | Package changes are the heaviest layer; grouping them keeps rebuilds cache-friendly. |
| 3 | `default-flatpaks` | `common-base.yml` | Configures Flathub (system + user), queues `io.github.ungoogled_software.ungoogled_chromium` and `org.gnome.Loupe` | Must come after the `dnf` removal of the Firefox RPM, so the Flatpak browser is the only browser (DD-023). |
| 4 | `containerfile` | `common-base.yml` | Installs and validates the terminal environment, builds/asserts the bounded-range GRUB PF2 payload, validates Homebrew and KDE/DMS environment wiring, synchronizes the Qt runtime with KWin and Plasma Workspace, smoke-tests Quickshell and Plasma's battery QML plugin, asserts Aurora's package-free Plasma launcher defaults, and replaces Plasma's Breeze launcher aliases with Qubix distributor artwork | Needs packages from `dnf` and overlaid configuration/scripts from `files`; late assertions turn missing assets, renamed units, lost executable bits, or a Qt private-ABI mismatch into build failures (DD-057, DD-062, DD-063, DD-066…DD-071). |
| 5 | `systemd` | `common-base.yml` | Enables `qubix-default-shell.service`, `qubix-grub-theme.service`, and the per-user `qubix-app-launcher-refresh.path` | All units come from `files`: one changes existing accounts once (DD-035), one synchronises image-owned GRUB assets into machine-local `/boot` (DD-057), and the user path refreshes desktop application indexes after Homebrew installs (DD-062). |
| 6 | `containerfile` | `common-identity.yml` | Reads the CI source stamp, then rewrites `ID`, `NAME`, `PRETTY_NAME` and adds `QUBIX_GIT_SHA` in `/usr/lib/os-release` | Must run **after** any module that could rewrite `os-release` (upstream `dnf` operations can regenerate it via `fedora-release`). |
| 7 | `initramfs` | `recipe.yml` | Regenerates the stock kernel's initramfs with the overlaid Plymouth files | Must run after `files`; late so it captures every early-boot change. Aurora's inherited initramfs otherwise retains Aurora's watermark (DD-049). |
| 8 | `signing` | `recipe.yml` | Installs cosign policy and public key into the image | Conventionally last; the image's trust configuration should reflect the finished image. |

The active CachyOS recipe and parked combined recipe compose the same blocks plus variant
modules, in a fixed order:

| Module | From | What it does | Why it is here |
|---|---|---|---|
| `dnf` + `containerfile` ×2 | `common-kernel-cachyos.yml` | Enables the CachyOS kernel COPR; removes Fedora's kernel, installs CachyOS's with scriptlets off, runs `depmod`, asserts one kernel remains; restores the packages the removal took with it | After the shared `dnf` work, **before** the identity rewrite. Removal must precede installation — DD-017. |
| `dnf` + `containerfile` | `common-nvidia-cachyos.yml` *(parked combined recipe only)* | Installs `akmod-nvidia`, compiles NVIDIA Open for the replacement kernel, and asserts all five modules plus `nvidia-smi` | Immediately after the swap, while matching CachyOS development files exist; before `initramfs`, which must embed the finished modules — DD-051. This path is not currently selected by CI — DD-052. |
| `containerfile` | Each variant recipe | Rewrites `PRETTY_NAME` again, naming the selected dimensions | After the shared identity rewrite, which would otherwise overwrite it. |
| `initramfs` | Each recipe | Regenerates `/usr/lib/modules/<kver>/initramfs.img` | Late so it embeds the Qubix Plymouth watermark and, for the combined image, the rebuilt NVIDIA modules. For CachyOS it is also required because installing a kernel in a container produces no archive. |

`recipe-nvidia.yml` follows the standard recipe's order and differs in its
`aurora-dx-nvidia-open` base plus its `PRETTY_NAME`. Its Fedora kernel and NVIDIA module
arrive already matched; no local module build runs (DD-051).

**Rule:** when adding a module, state its ordering constraint in
[`recipe-reference.md`](recipe-reference.md). If it has none, say so.

## The `files` overlay

`files/system/` is a mirror of the image root. The mapping is literal:

```
files/system/usr/share/pixmaps/system-logo.png
        →  /usr/share/pixmaps/system-logo.png   (inside the image)
```

Consequences worth remembering:

- **Overwriting is the mechanism.** To change branding, you write a file at the exact path
  the upstream component already reads. See [`branding.md`](branding.md).
- **No templating.** The `files` module copies bytes. Anything needing a variable (like
  the image version in `PRETTY_NAME`) must go through the `containerfile` module instead —
  this is exactly why decision DD-003 exists.
- **`/etc` vs `/usr`.** On an Atomic system `/etc` is user-writable and gets three-way
  merged on updates; `/usr` is read-only and fully replaced. Ship configuration in `/usr`
  whenever the consumer supports it, so updates always win. `files/system/etc/` is used
  only where the consumer's search path offers no `/usr` entry that can be written without
  overwriting an upstream file — currently the KDE fallback fragments
  `etc/xdg/{kdeglobals,plasmarc,kwinrc}` (DD-012, DD-023, DD-050, DD-063),
  `etc/xdg/mimeapps.list` (DD-023), `etc/niri/config.kdl` (DD-014) and
  `etc/profile.d/qubix-shell-env.sh` (DD-026; `/etc/profile.d` has no `/usr` equivalent).
- **Not only branding any more.** The overlay also carries the desktop-session
  configuration described in [`desktops.md`](desktops.md) and the terminal environment
  described in [`shell.md`](shell.md).
- **The overlay cannot reach `$HOME`, and it cannot reach `/etc/passwd`.** Anything that
  has to live in a user's home directory — a zsh rc line, an editor config — is *seeded*
  from `/usr` by a user unit at login (DD-026, DD-029), and the login shell itself is set
  by a system unit at boot (DD-028). DD-025 is the same problem in the desktop theme.
  These are the only things in the image that write outside `/usr` at runtime, and each is
  stamped so it happens once.

## Identity rewrite

The `containerfile` snippet is the one piece of imperative logic in the build:

```sh
SOURCE_REVISION_FILE=/usr/lib/qubix-os/source-revision
IMAGE_VERSION=$(grep '^IMAGE_VERSION=' /usr/lib/os-release | cut -d= -f2 | tr -d '"')
SHORT_SHA=$(cat "${SOURCE_REVISION_FILE}")
test -n "${IMAGE_VERSION}"
test "${#SHORT_SHA}" -eq 12
printf '%s' "${SHORT_SHA}" | grep -Eq '^[0-9a-f]{12}$'
sed -i 's/^ID=.*/ID=qubix_os_bluebuild/'                       /usr/lib/os-release
sed -i 's/^NAME=.*/NAME="Qubix OS"/'                           /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Qubix OS (BlueBuild Image, Version: ${IMAGE_VERSION}, ${SHORT_SHA})\"|" /usr/lib/os-release
sed -i '/^QUBIX_GIT_SHA=/d'                                    /usr/lib/os-release
printf 'QUBIX_GIT_SHA="%s"\n' "${SHORT_SHA}" >>                 /usr/lib/os-release
```

- `IMAGE_VERSION` is injected into `os-release` by Universal Blue upstream; it is read
  **before** the rewrite so the Fedora/Aurora version stays visible in `PRETTY_NAME`.
- The image workflow checks out the source first, validates its full commit SHA, and writes
  its 12-character short prefix to `files/system/usr/lib/qubix-os/source-revision`; the
  `files` module copies it into the image before this module runs. The short SHA is
  validated and retained as `QUBIX_GIT_SHA`.
- `ID` uses underscores because `os-release` `ID` is expected to be a lowercase,
  shell-safe token; it is consumed by tooling, not by humans.
- `NAME` is the clean visual product label. `PRETTY_NAME` stays deliberately detailed so
  boot entries, diagnostics, and bug reports retain BlueBuild, upstream-version, and
  source-revision provenance without a redundant SHA label (DD-065, DD-073).
- The whole snippet is a single `RUN` under `set -eu`; semicolon-separated mutations and
  exact assertions therefore form one layer and fail atomically.

## What a user's machine does

Nothing in this repository executes on the client. The client only:

1. Pulls the image from GHCR.
2. Verifies the cosign signature against the policy installed by the `signing` module.
3. Deploys it as a new `rpm-ostree` deployment.
4. Boots into it; the previous deployment stays available for rollback.

This is why there is no "uninstall" or "migration" logic anywhere in the repo — rollback
is the OS's job.

## Extension points not currently used

| Path | Purpose | Status |
|---|---|---|
| `modules/` | Custom BlueBuild modules written for this image | Empty placeholder |
| `files/scripts/` | Scripts invoked by the `script` module during build | Contains only `example.sh`, not wired into `recipe.yml` |
