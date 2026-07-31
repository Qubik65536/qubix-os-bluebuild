# Architecture

How a commit in this repository becomes a bootable operating system.

## The pipeline

```
 git push / daily cron / manual dispatch
              │
              ▼
 ┌──────────────────────────────────────────┐
 │ .github/workflows/build.yml              │
 │  → blue-build/github-action@v1.11        │
 └──────────────────────────────────────────┘
              │  reads
              ▼
 ┌──────────────────────────────────────────┐
 │ recipes/recipe.yml                       │
 │  BlueBuild renders it to a Containerfile │
 └──────────────────────────────────────────┘
              │  FROM ghcr.io/ublue-os/aurora-dx:beta
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
              │
              ▼
   rpm-ostree rebase on the user's machine
```

BlueBuild is a **transpiler**, not a runtime: `recipe.yml` is turned into an ordinary
`Containerfile`, and the result is an ordinary OCI image. Nothing in this repo runs on a
user's machine at install time; everything happens at build time, once, in CI.

## Module execution order

Modules in `recipe.yml` run **top to bottom**, each producing an image layer. Order is
load-bearing.

| # | Module | What it does | Why it is here |
|---|---|---|---|
| 1 | `files` | Copies `files/system/*` to `/` (branding + desktop configuration) | Content must exist before anything reads it; nothing later depends on being first, but putting content first keeps later layers small. |
| 2 | `dnf` | Adds COPRs `atim/starship` and `wezfurlong/wezterm-nightly`; installs `micro`, `starship`, `wezterm`, `niri`, `brightnessctl`; removes `firefox`, `firefox-langpacks` | Package changes are the heaviest layer; grouping them keeps rebuilds cache-friendly. |
| 3 | `default-flatpaks` | Configures Flathub (system + user), queues `org.mozilla.firefox` and `org.gnome.Loupe` | Must come after the `dnf` removal of the Firefox RPM so the flatpak is the only Firefox. |
| 4 | `containerfile` | `sed`-rewrites `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` | Must run **after** any module that could rewrite `os-release` (upstream `dnf` operations can regenerate it via `fedora-release`). |
| 5 | `signing` | Installs cosign policy and public key into the image | Conventionally last; the image's trust configuration should reflect the finished image. |

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
  overwriting an upstream file — currently `etc/xdg/kdeglobals` (DD-012) and
  `etc/niri/config.kdl` (DD-014).
- **Not only branding any more.** The overlay also carries the desktop-session
  configuration described in [`desktops.md`](desktops.md).

## Identity rewrite

The `containerfile` snippet is the one piece of imperative logic in the build:

```sh
IMAGE_VERSION=$(grep '^IMAGE_VERSION=' /usr/lib/os-release | cut -d= -f2 | tr -d '"')
sed -i 's/^ID=.*/ID=qubix_os_bluebuild/'                       /usr/lib/os-release
sed -i 's/^NAME=.*/NAME="QubixOS-BlueBuild"/'                  /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Qubix OS (BlueBuild Image, Version: ${IMAGE_VERSION})\"|" /usr/lib/os-release
```

- `IMAGE_VERSION` is injected into `os-release` by Universal Blue upstream; it is read
  **before** the rewrite so the Fedora/Aurora version stays visible in `PRETTY_NAME`.
- `ID` uses underscores because `os-release` `ID` is expected to be a lowercase,
  shell-safe token; it is consumed by tooling, not by humans.
- The whole snippet is a single `RUN` (chained with `&&`) so it is one layer and fails
  atomically.

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
