# Overview

## What Qubix OS is

Qubix OS is a **personal custom Linux desktop image**: an immutable, image-based Fedora
Atomic system delivered as an OCI container image. Users don't install packages onto a
mutable root filesystem; they *rebase* their machine onto a new version of this image.

The whole operating system is defined declaratively by the recipes in `recipes/` plus a
tree of files to overlay. There is no imperative installer and no local build step.

| Property | Value |
|---|---|
| Image name | `qubix-os-bluebuild` |
| Published to | `ghcr.io/qubik65536/qubix-os-bluebuild` |
| Variants | Standard, plus `qubix-os-bluebuild-cachyos` (CachyOS kernel) — see [`variants.md`](variants.md) |
| Base image | `ghcr.io/ublue-os/aurora-dx` |
| Base tag | `latest` |
| Desktops | KDE Plasma (via Fedora Kinoite → Aurora) and Niri + DankMaterialShell, switchable at login |
| Build system | [BlueBuild](https://blue-build.org) |
| Signing | Sigstore cosign (`cosign.pub`) |
| Rebuild cadence | Daily, 06:00 UTC, plus on every push |

## The lineage

Qubix OS sits at the end of a chain of images, each adding a layer:

```
Fedora (rpm-ostree base)
  └── Fedora Kinoite            immutable KDE Plasma desktop
        └── Universal Blue Aurora      Kinoite + codecs, drivers, quality-of-life fixes
              └── Aurora DX            Aurora + developer tooling (containers, IDEs, toolchains)
                    └── Qubix OS       branding + package tweaks + identity + a Niri session
```

Everything Aurora DX provides is inherited for free. This repository only records the
**delta**: what Qubix OS adds, removes, or renames on top of Aurora DX.

## What this repository actually changes

| Area | Change | Where |
|---|---|---|
| Identity | `ID`, `NAME`, `PRETTY_NAME` in `/usr/lib/os-release` rewritten to Qubix OS | `recipe.yml` (containerfile snippet) |
| Branding | Distro logos, banners, Plymouth boot watermark, KDE splash and "About this system" | `files/system/usr/share/**` |
| Packages added | `micro` (editor), `starship` (shell prompt, from COPR), `wezterm` (terminal, from COPR), `niri` (second session), `dms` + fonts + `cliphist` (Niri's shell, from COPR) | `recipe.yml` (`dnf`) |
| Terminal environment | `zsh` + its plugins, `atuin`, `bat`, `yazi` (from COPR), `neovim` and what LazyVim calls; `zsh-completions` from a pinned upstream tag | `recipe.yml` (`dnf`, `containerfile`) |
| Shell configuration | starship initialised at last, plugins loaded, atuin made explicitly local, `cat`→`bat`, `y`→yazi. System files only — nothing is written to `$HOME` (DD-026, DD-030) | `files/system/etc/profile.d/`, `files/system/etc/zshenv`, `files/system/usr/share/qubix-os/shell/` |
| Editor | Neovim is `$EDITOR`. Its config is not shipped: `~/.config/nvim` is the user's, from a one-line `git clone` (DD-030) | `files/system/etc/profile.d/qubix-shell-env.sh` |
| Login shell | zsh for accounts created from now on; one `chsh` for one that already exists (DD-030) | `files/system/etc/default/useradd` |
| Packages removed | `firefox`, `firefox-langpacks` — no Firefox in either form (DD-023) | `recipe.yml` (`dnf`) |
| Default terminal | WezTerm, for KDE and for the `$TERMINAL` convention | `files/system/etc/xdg/kdeglobals`, `files/system/usr/lib/environment.d/` |
| Default browser | Ungoogled Chromium, claimed for the web MIME types in both sessions | `files/system/etc/xdg/mimeapps.list`, `files/system/etc/xdg/kdeglobals` |
| Second session | Niri added alongside — nothing KDE removed. System config shipped | `recipe.yml` (`dnf`), `files/system/etc/niri/config.kdl` |
| Niri shell | DankMaterialShell, started by systemd under Niri only | `files/system/usr/lib/systemd/user/niri.service.d/` |
| Flatpaks | Flathub configured; `io.github.ungoogled_software.ungoogled_chromium` and `org.gnome.Loupe` installed system-wide | `recipe.yml` (`default-flatpaks`) |
| Trust | Cosign signing policy installed so signed rebases verify | `recipe.yml` (`signing`) |
| Kernel *(CachyOS variant only)* | Fedora's kernel replaced with `kernel-cachyos`; initramfs regenerated | `recipe-cachyos.yml`, `common-kernel-cachyos.yml` |

That's the entire surface area. Anything not in that table is upstream behaviour and
should be reported upstream, not patched here — see
[`design-decisions.md`](design-decisions.md) (DD-002).

## Project goals

1. **Stay thin.** Prefer inheriting from Aurora DX over reimplementing. The delta above
   should stay small enough to read in one sitting.
2. **Stay declarative.** Changes belong in the recipes or in `files/system/`, not in
   post-install scripts run on user machines.
3. **Stay reproducible.** Every published image is built by CI from a commit, and signed.
4. **Stay documented.** Every decision has a record; every file has a context-cache entry.

## Non-goals

- Being a general-purpose distribution for other people. It is published publicly and
  anyone may use it, but it is tuned for one person's workflow.
- Supporting non-Atomic Fedora. KDE Plasma is the inherited desktop and is never removed;
  Niri is an additional session, not a replacement (see [`desktops.md`](desktops.md)).
- Local/offline builds. See [`build-and-release.md`](build-and-release.md).
