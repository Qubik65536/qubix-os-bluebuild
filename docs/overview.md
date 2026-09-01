# Overview

## What Qubix OS is

Qubix OS is a **personal custom Linux desktop image**: an immutable, image-based Fedora
Atomic system delivered as an OCI container image. Users don't install packages onto a
mutable root filesystem; they *rebase* their machine onto a new version of this image.

The whole operating system is defined declaratively by the recipes in `recipes/` plus a
tree of files to overlay. There is no imperative installer and no local build step.

| Property | Value |
|---|---|
| Image family | `qubix-os-bluebuild` |
| Published to | `ghcr.io/qubik65536/qubix-os-bluebuild{,-cachyos,-nvidia}` |
| Active variants | Standard, CachyOS, NVIDIA; NVIDIA+CachyOS is parked — see [`variants.md`](variants.md) |
| Base images | `ghcr.io/ublue-os/aurora-dx` and `ghcr.io/ublue-os/aurora-dx-nvidia-open` |
| Base tag | `latest` |
| Desktops | KDE Plasma (via Fedora Kinoite → Aurora) and Niri + DankMaterialShell, switchable at login |
| Build system | [BlueBuild](https://blue-build.org) |
| Signing | Sigstore cosign (`cosign.pub`) |
| Rebuild cadence | Weekly, Sunday at 00:00 UTC, plus on every push |

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
| Branding | Qubix Boot Console for GRUB; distro logos, banners, Plymouth boot watermark, KDE splash and "About this system" | `files/system/usr/share/**`, `files/system/usr/bin/qubix-grub-theme` |
| Packages added | `micro` (editor), `starship` (shell prompt, from COPR), `wezterm` (terminal, from COPR), `niri` (second session), `dms` + fonts + `cliphist` (Niri's shell, from COPR), Fcitx 5 + Pinyin + toolkit/KDE integration (Simplified Chinese input), `grub2-tools-extra` (PF2 font generation) | `recipe.yml` (`dnf`) |
| Terminal environment | `zsh` + its plugins, `atuin`, `bat`, `yazi` (from COPR), `lazygit` (from COPR), `fastfetch`, `neovim` and what LazyVim calls; `zsh-completions` from a pinned upstream tag | `recipe.yml` (`dnf`, `containerfile`) |
| Multiplexer | `zellij`, from upstream's pinned `no-web` release — not packaged by Fedora and endorsed by no COPR. Nothing starts it (DD-033) | `recipe.yml` (`containerfile`), `files/system/etc/zellij/config.kdl` |
| Shell configuration | starship initialised at last, plugins loaded, atuin made explicitly local, `cat`→`bat`, `y`→yazi, `lg`→lazygit. System files only — nothing is written to `$HOME` (DD-026, DD-030, DD-036) | `files/system/etc/profile.d/`, a block appended to `/etc/zshrc`, `files/system/usr/share/qubix-os/shell/` |
| System information | fastfetch's box, as the system-wide default. Run by hand, never automatically; `~/.config/fastfetch/` still wins (DD-031) | `files/system/etc/fastfetch/config.jsonc` |
| Editor | Neovim is `$EDITOR`. Its config is not shipped: `~/.config/nvim` is the user's, from a one-line `git clone` (DD-030) | `files/system/etc/profile.d/qubix-shell-env.sh` |
| Login shell | zsh for new accounts, and for existing ones a boot service sets it once per account — Aurora deletes `chsh`, so there is no manual path (DD-035) | `files/system/etc/default/useradd`, `files/system/usr/bin/qubix-default-shell` |
| Containers | Every distrobox container gets the same shell: an init hook installs the binaries from the container's own repositories and links the rest from `/run/host` (DD-043) | `files/system/etc/distrobox/distrobox.conf`, `files/system/usr/bin/qubix-distrobox-shell` |
| Packages removed | `firefox`, `firefox-langpacks` — no Firefox in either form (DD-023) | `recipe.yml` (`dnf`) |
| Default terminal | WezTerm, for KDE and for the `$TERMINAL` convention | `files/system/etc/xdg/kdeglobals`, `files/system/usr/lib/environment.d/` |
| Terminal configuration | WezTerm's font stack, colour scheme and window settings, system-wide. Found through `$XDG_CONFIG_DIRS`; `~/.config/wezterm/` still wins (DD-034) | `files/system/etc/xdg/wezterm/` |
| Terminal fonts | Monaspace Krypton NF and IBM Plex Math from pinned upstream releases; IBM Plex Mono/Sans and Noto Sans CJK from Fedora (DD-034) | `recipe.yml` (`dnf`, `containerfile`) |
| Default browser | Ungoogled Chromium, claimed for the web MIME types in both sessions | `files/system/etc/xdg/mimeapps.list`, `files/system/etc/xdg/kdeglobals` |
| Simplified Chinese input | Fcitx 5 with English (US) and Pinyin defaults; `Super+Space` in Plasma, `Ctrl+Space` in Niri; native startup integration for both | `recipe.yml` (`dnf`), `files/system/etc/xdg/fcitx5/`, `files/system/etc/xdg/kwinrc`, `files/system/etc/niri/config.kdl` |
| Second session | Niri added alongside — nothing KDE removed. System config shipped | `recipe.yml` (`dnf`), `files/system/etc/niri/config.kdl` |
| Niri shell | DankMaterialShell, started by systemd under Niri only | `files/system/usr/lib/systemd/user/niri.service.d/` |
| Flatpaks | Flathub configured; `io.github.ungoogled_software.ungoogled_chromium` and `org.gnome.Loupe` installed system-wide | `recipe.yml` (`default-flatpaks`) |
| Trust | Cosign signing policy installed so signed rebases verify | `recipe.yml` (`signing`) |
| Kernel *(active CachyOS variant; parked combined recipe)* | Fedora's kernel replaced with `kernel-cachyos`; initramfs regenerated | `recipe*-cachyos.yml`, `common-kernel-cachyos.yml` |
| NVIDIA | The active NVIDIA image inherits Aurora's matched NVIDIA Open userspace and Fedora-kernel driver; the parked combined recipe contains an inactive `akmod-nvidia` rebuild path | `recipe-nvidia*.yml`, `common-nvidia-cachyos.yml` |

That's the entire surface area. Anything not in that table is upstream behaviour and
should be reported upstream, not patched here — see
[`design-decisions.md`](design-decisions.md) (DD-002).

## Project goals

1. **Stay thin.** Prefer inheriting from Aurora DX over reimplementing. The delta above
   should stay small enough to read in one sitting.
2. **Stay declarative.** Changes belong in the recipes or in `files/system/`. A narrow,
   idempotent system bridge is allowed only when the consumer owns machine-local state
   outside the image, as GRUB does under `/boot`; its ownership and opt-out must be explicit
   (DD-057).
3. **Stay reproducible.** Every published image is built by CI from a commit, and signed.
4. **Stay documented.** Every decision has a record; every file has a context-cache entry.

## Non-goals

- Being a general-purpose distribution for other people. It is published publicly and
  anyone may use it, but it is tuned for one person's workflow.
- Supporting non-Atomic Fedora. KDE Plasma is the inherited desktop and is never removed;
  Niri is an additional session, not a replacement (see [`desktops.md`](desktops.md)).
- Local/offline builds. See [`build-and-release.md`](build-and-release.md).
