# Glossary

Terminology used consistently across this documentation. When writing docs, prefer these
terms over synonyms.

| Term | Meaning |
|---|---|
| **Atomic / image-based** | A Linux system deployed as a whole image rather than as individually installed packages. Updates swap the image; rollback is built in. |
| **atuin** | Shell history in a local SQLite database, searchable from every terminal. Configured fully local — no account, no sync (DD-026). See [`shell.md`](shell.md). |
| **Aurora** | Universal Blue's KDE Plasma image, built on Fedora Kinoite with codecs, drivers, and quality-of-life fixes added. |
| **Aurora DX** | Aurora plus a developer toolchain (container tooling, IDEs, virtualisation). This project's base image. |
| **Base image** | The image named in `base-image:` — what the recipe builds `FROM`. |
| **bat** | `cat` with syntax highlighting. Aliased over `cat` in interactive shells (DD-026). |
| **BlueBuild** | The build system used here. Transpiles a recipe in `recipes/` into a `Containerfile` and builds it. <https://blue-build.org> |
| **BORE** | Burst-Oriented Response Enhancer — the CPU scheduler the CachyOS kernel uses by default. |
| **Branding asset** | A file under `files/system/` that replaces an upstream logo, banner, or watermark. See [`branding.md`](branding.md). |
| **CachyOS** | A performance-focused Linux distribution whose patched kernel is packaged for Fedora in COPR `bieszczaders/kernel-cachyos`. Used by one [variant](variants.md) of this image (DD-017). |
| **Context cache** | `.agent/context/` — one brief Markdown entry per file/module, so an agent can orient without reading the whole repo. |
| **COPR** | Fedora's community package repository service. This project enables `atim/starship`, `wezfurlong/wezterm-nightly`, `avengemedia/dms`, `avengemedia/danklinux`, `lihaohong/yazi`, `atim/lazygit`, and — on the CachyOS variant only — `bieszczaders/kernel-cachyos`. |
| **cosign** | The Sigstore tool used to sign and verify published images. |
| **DankMaterialShell** (DMS) | The desktop shell for the Niri session: panel, launcher, notifications, lock screen, power menu (DD-015). See [`desktops.md`](desktops.md). |
| **DD-###** | A design decision record in [`design-decisions.md`](design-decisions.md). |
| **Delta** | What this repository changes relative to Aurora DX. Kept deliberately small. |
| **Deployment** | An `rpm-ostree` bootable instance of an image. Several coexist; the previous one is the rollback target. |
| **distrobox** | Runs another distribution's userspace in a container that shares your `$HOME` and sees the host root at `/run/host`. It comes from the base image. Containers get this image's terminal environment through an init hook — the binaries installed from their own repositories, everything else linked from the host (DD-043). See [`shell.md`](shell.md#inside-a-distrobox-container). |
| **fastfetch** | The system-information screen, run by hand. Its box is configured system-wide in `/etc/fastfetch/config.jsonc` — fastfetch's search path has no `/usr` entry — and a `~/.config/fastfetch/config.jsonc` replaces it wholesale (DD-031). See [`shell.md`](shell.md). |
| **Flatpak seeding** | Flatpaks are not baked into the image; a systemd unit installs them on first boot. Hence first boot needs network. |
| **Fragment (configuration)** | A file this image ships that sets only the keys it cares about, letting everything else resolve from the files upstream already ships — `/etc/xdg/kdeglobals` (merged key by key) and `/etc/xdg/mimeapps.list` (resolved type by type). Never a wholesale replacement. |
| **`from-file:`** | The recipe key that splices a shared `recipes/common-*.yml` module list into a recipe at that position (DD-016). |
| **GHCR** | GitHub Container Registry — where the image is published. |
| **`image-version`** | The base image *tag* (`latest` here). A channel, not a Fedora version number. See DD-018. |
| **`IMAGE_VERSION`** | A field Universal Blue writes into `os-release`, identifying the upstream build. Interpolated into `PRETTY_NAME` (DD-003). |
| **initramfs** | The RAM filesystem the kernel boots into before mounting the real root. Regenerated at build time by the `initramfs` module, which the kernel-swapping variant requires. |
| **KDL** | The configuration language niri uses (<https://kdl.dev>). Braces and nodes, not YAML. |
| **Kinoite** | Fedora's official immutable KDE Plasma variant. Aurora's base. |
| **lazygit** | A terminal UI over git. Wrapped as `lg`, so quitting after switching repositories leaves the shell in the new one. Its config is the only one here that *merges* with the user's, through `LG_CONFIG_FILE` (DD-032). See [`shell.md`](shell.md). |
| **LazyVim** | A Neovim configuration distribution. Not shipped: `~/.config/nvim` is the user's, cloned from upstream's starter by hand, so `:Lazy update` updates the plugins and `git pull` the config (DD-030). See [`shell.md`](shell.md). |
| **Look-and-feel package** | A KDE Plasma theme bundle under `/usr/share/plasma/look-and-feel/`. Aurora's contains the startup splash this image overrides. |
| **matugen** | Generates a Material colour scheme from the wallpaper. DankMaterialShell uses it to theme itself and niri. |
| **MIME association** | The mapping from a MIME type or URL scheme to the desktop entry that opens it. Set system-wide in `/etc/xdg/mimeapps.list`; the user's `~/.config/mimeapps.list` is searched first and wins. How the default browser is declared (DD-023). |
| **Module** | A build step (`files`, `dnf`, `default-flatpaks`, `containerfile`, `systemd`, `initramfs`, `signing`). Modules run in the order the recipe composes them. |
| **MOK** | Machine Owner Key — an X.509 key enrolled with shim via `mokutil`, letting a machine's owner trust binaries their vendor did not sign. How Secure Boot stays on with the CachyOS kernel ([`variants.md`](variants.md)). |
| **Nerd Font** | A font patched with an extra set of icon glyphs. The prompt and the editor use them; `cascadia-mono-nf-fonts` provides them for consumers that do not bundle their own, as WezTerm does. |
| **Monaspace** | GitHub's monospace type family. *Krypton* is the variant WezTerm's shipped config uses; the Nerd-Font-patched build is installed from a pinned upstream release because Fedora packages none of it (DD-034). |
| **Niri** | A scrollable-tiling Wayland compositor. The second desktop session (DD-013). See [`desktops.md`](desktops.md). |
| **Overlay** | The `files/system/` tree, copied verbatim into the image root. Repository path = image path. |
| **Override** | Shipping a file at an upstream path so the upstream file is replaced in the image. The branding mechanism (DD-004). |
| **Plymouth** | The boot splash system. Reads the watermark this image overrides. |
| **Quickshell** | The QtQuick-based shell toolkit DankMaterialShell is written against. |
| **`qubix-default-shell`** | The boot service that gives an account which already exists zsh as its login shell, once per account. It exists because `/etc/passwd` is per machine and Aurora deletes `chsh` from the image (DD-035). See [`shell.md`](shell.md#the-login-shell). |
| **Rebase** | Switching a machine to a different OS image (`rpm-ostree rebase`). How Qubix OS is installed and uninstalled. |
| **`XDG_CONFIG_DIRS`** | The colon-separated list of *system* configuration directories, searched after the user's own. How WezTerm finds `/etc/xdg/wezterm/wezterm.lua`. WezTerm does not apply the spec's `/etc/xdg` default when the variable is unset, so this image **appends** `/etc/xdg` to it — in `environment.d` for the systemd user manager's units, and in `/etc/profile.d` for every shell (DD-034, DD-038). |
| **Recipe** | A `recipes/recipe*.yml` file: the declarative definition of one published image. Shared parts live in `recipes/common-*.yml`. |
| **`rpm-ostree`** | The package/deployment manager on Fedora Atomic systems. |
| **SDDM** | The display manager (login screen). Lists sessions from `/usr/share/wayland-sessions/`, which is how Niri appears as a login choice. |
| **Secure Boot** | UEFI feature where firmware only loads signed boot binaries. Fedora's kernel is signed; the CachyOS one is not, so this variant needs it off or a [MOK](variants.md#secure-boot) enrolled. |
| **Seeder** | A user service that writes into `$HOME` what the image cannot ship there. Only one remains: `qubix-dms-theme`, which writes the theme pointer every Niri session and applies versioned shell-presentation migrations once (DD-025, DD-047). The shell and editor once had seeders too; they were replaced by plain system files (DD-030). Not to be confused with `qubix-default-shell`, which is a *system* service and writes to `/etc/passwd`, never to `$HOME`. |
| **Session** | One desktop environment as offered at the login screen. This image has two: Plasma (Wayland) and Niri. |
| **shim** | The Fedora-signed first-stage bootloader that chains to GRUB and checks the kernel against firmware `db` plus the MOK list. |
| **Signing policy** | Client-side configuration, installed into the image by the `signing` module, that lets `ostree-image-signed:` rebases verify against `cosign.pub`. |
| **starship** | The shell prompt, configured in `/usr/share/qubix-os/starship.toml` and used unless the user has a `~/.config/starship.toml` of their own (DD-007, DD-026). |
| **Task** | An entry in [`../.agent/plan.md`](../.agent/plan.md) with an ID, category, dependencies, and acceptance criteria. |
| **Ungoogled Chromium** | Chromium with Google's web-service integration and binary blobs removed. The default browser, installed as a Flatpak from Flathub (DD-023). See [`desktops.md`](desktops.md). |
| **Universal Blue** | The project producing the `ublue-os` images, including Aurora. |
| **Variant** | One of the images this repository publishes. They share every module except the one dimension that distinguishes them. See [`variants.md`](variants.md). |
| **WezTerm** | The GPU-accelerated terminal emulator set as the default in every session (DD-012). Not packaged in Fedora; layered from WezTerm's own COPR. |
| **x86-64-v3** | A microarchitecture level (AVX2-era CPUs and newer). The default CachyOS kernel is built for it and will not boot on older hardware. |
| **yazi** | A terminal file browser. Wrapped as `y`, so quitting leaves the shell in the directory it was last in (DD-026). |
| **zellij** | The terminal multiplexer: panes, tabs, and detachable sessions. Installed from upstream's pinned `no-web` release because Fedora does not package it and upstream endorses no COPR; themed in `/etc/zellij/config.kdl`, and nothing starts it automatically (DD-033). See [`shell.md`](shell.md). |
| **zsh plugins** | `zsh-autosuggestions`, `zsh-syntax-highlighting` and `zsh-completions`. Loaded from `/usr/share/qubix-os/shell/qubix.zsh`, highlighting **last** (DD-026). See [`shell.md`](shell.md). |
