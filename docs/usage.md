# Usage

How to install, update, verify, and roll back Qubix OS. This page is the detailed version
of the quick instructions in the [root README](../README.md).

> **Prerequisite:** an existing Fedora Atomic installation (Kinoite, Silverblue, Aurora,
> Bazzite, …). Rebasing replaces the OS image while keeping `/home` and `/etc`
> customisations.

This page uses the **standard** image throughout. Three variants are active; every command
works for another active one by substituting its image suffix. The NVIDIA+CachyOS recipe
is disabled and must not be used. Read [`variants.md`](variants.md) before choosing NVIDIA
or CachyOS because those images have hardware and Secure Boot requirements of their own.

## First install (two steps, on purpose)

The signature verification policy ships **inside** the image (DD-008), so a machine that
has never run Qubix OS cannot verify the first pull. The fix is to rebase unsigned once to
obtain the policy, then rebase again to the signed image.

**Step 1 — unsigned rebase, to install the signing keys and policy:**

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/qubik65536/qubix-os-bluebuild:latest
systemctl reboot
```

**Step 2 — signed rebase:**

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/qubik65536/qubix-os-bluebuild:latest
systemctl reboot
```

After step 2 the deployment is signature-verified. Every subsequent update stays on the
signed reference.

## Updating

Normal `rpm-ostree` updates apply:

```bash
rpm-ostree upgrade
systemctl reboot
```

`latest` always points at the most recent successful CI build. `image-version: latest`
pins the stable Aurora **channel**, not a Fedora release number, so a new Fedora major can
arrive after Aurora promotes it to that channel (DD-018). Keep a previous deployment for
rollback when crossing a major release.

## Rolling back

Every rebase keeps the previous deployment:

```bash
rpm-ostree rollback
systemctl reboot
```

Pick a specific deployment from the boot menu, or pin one so cleanup won't remove it:

```bash
rpm-ostree status              # list deployments, note the index
sudo ostree admin pin 1        # pin deployment index 1
```

## Verifying an image

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
```

`cosign.pub` is committed at the repository root. Download it from this repository over
HTTPS rather than from any other source.

## Applications after installation or rebase

An **ISO installation** receives the complete desktop Flatpak set from an offline Flathub
repository embedded in the installer (DD-061). Anaconda installs the applications and
their runtimes, so Bazaar, Ungoogled Chromium, Loupe, Aurora's standard desktop apps, and
the Aurora DX Flatpaks are available at the first login without waiting for a network
service. The exact source list is
[`flatpak_refs/iso-refs.txt`](../flatpak_refs/iso-refs.txt).

A **rebase** receives only the OCI image, not the installer's Flatpak repository. The
BlueBuild `default-flatpaks` timer therefore remains as its fallback: it fetches Ungoogled
Chromium and Loupe from Flathub shortly after the first boot and needs working network
access. A desktop notification reports when that pass finishes (`notify: true`).

`ujust update` updates the OS and applications already registered on the machine. It does
not replay a missing installer manifest or reconstruct an offline repository omitted when
an older ISO was built, so it cannot repair this particular media defect. A newly generated
ISO is the fix for new installations.

**Ungoogled Chromium is the default browser** (DD-023), and it is the only one installed —
Firefox is shipped in neither form. Being a Flatpak, it updates on Flathub's schedule
rather than with the OS.

Links open in it from both sessions without any setup: `/etc/xdg/mimeapps.list` claims the
web MIME types and `/etc/xdg/kdeglobals` sets KDE's `BrowserApplication`. To use something
else, install it and pick it in *System Settings → Default Applications* (Plasma) or run
`xdg-settings set default-web-browser <id>.desktop` — either writes
`~/.config/mimeapps.list`, which is searched **before** the image's copy, so your choice
wins and survives updates.

### Homebrew and the `ublue-os` tap

Aurora DX supplies Homebrew and the curated Brewfiles under
`/usr/share/ublue-os/homebrew/`. Qubix inherits both; it does not copy their GUI tools into
the immutable OS image or the installer. The [`ublue-os/tap`](https://github.com/ublue-os/homebrew-tap)
is Universal Blue's staging area for Linux casks that are a poor fit for Flatpak, including
IDEs and hardware utilities. Those applications update through Homebrew, independently of
the OS image and system Flatpaks.

Install one application directly—for example, Zed—with:

```bash
brew tap ublue-os/tap
brew install --cask zed-linux
```

The fully qualified second command is equivalent:

```bash
brew install --cask ublue-os/tap/zed-linux
```

Useful casks in the inherited
[`ide.Brewfile`](https://github.com/get-aurora-dev/common/blob/main/system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile)
are:

| Cask | Application |
|---|---|
| `visual-studio-code-linux` | Visual Studio Code |
| `visual-studio-code-linux@insiders` | Visual Studio Code Insiders |
| `vscodium-linux` | VSCodium |
| `antigravity-linux` | Google Antigravity |
| `jetbrains-toolbox-linux` | JetBrains Toolbox |
| `zed-linux` | Zed |

Run `ujust bbrew` for Aurora's interactive curated-Brewfile picker. Selecting `ide`
installs the **whole** IDE bundle, including its `nvim`, `micro`, `helix`, and
`devcontainer` formulae; use `brew install --cask <name>` when you want only one GUI
application. Normal maintenance commands are:

```bash
brew upgrade
brew uninstall --cask zed-linux
```

#### If an installed Homebrew app is missing from the launcher

Homebrew's Linux prefix stores shared desktop metadata under
`/home/linuxbrew/.linuxbrew/share`. A terminal can still run an application when that
directory is absent from `XDG_DATA_DIRS`, but Plasma and Niri's DMS launcher cannot index
the metadata. Homebrew's `shellenv` does not add the directory itself.

Qubix adds it for graphical sessions and shells as of IMG-039 (DD-062). An enabled user
path unit also watches the Homebrew and per-user application directories: it rebuilds
Plasma's application-service cache and restarts DMS only when DMS is already active. New
installs and removals therefore appear without a logout and do not start the Niri shell in
Plasma.

It watches the matching icon directories too. Before refreshing a launcher,
`qubix-stabilize-homebrew-icons` handles two cask patterns that otherwise age badly:

- an absolute `Icon=` below `Caskroom/<version>/`, which disappears on upgrade;
- a named icon such as `Icon=zed` paired with a loose cask file such as
  `~/.local/share/icons/zed.png`, which launchers do not consistently resolve as an icon
  theme entry.

For those entries only, it copies the readable source to the stable
`${XDG_DATA_HOME:-$HOME/.local/share}/qubix-os/homebrew-icons/` directory and points the
user desktop entry at that absolute copy. A shared Homebrew entry gets a marked user
override with the same desktop ID; an existing unmarked user override always wins. A cask
update refreshes the copy, and uninstall removes Qubix's marked override and unreferenced
copy. Icon-theme names without a detected cask-owned loose/bundle source, and absolute
paths outside Homebrew, are left untouched.

After first rebasing to that image, **log out and back in once** so the user manager and
desktop inherit the new search path and start the watcher. Confirm it with:

```bash
printf '%s\n' "$XDG_DATA_DIRS" | tr : '\n'
# must include /home/linuxbrew/.linuxbrew/share
```

To repair the currently running Niri session without logging out, import the corrected
value and restart only DMS:

```bash
export XDG_DATA_DIRS="/home/linuxbrew/.linuxbrew/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
systemctl --user import-environment XDG_DATA_DIRS
/usr/bin/qubix-refresh-app-launchers
```

The icon repair can also be run and inspected on its own:

```bash
qubix-stabilize-homebrew-icons
find "${XDG_DATA_HOME:-$HOME/.local/share}/qubix-os/homebrew-icons" \
     -maxdepth 1 -type f -print 2>/dev/null
```

For Plasma, logging out and back in is the reliable refresh because the launcher and its
service cache both need the new environment. If Zed is still absent afterward, verify that
the cask actually installed a desktop entry:

```bash
find "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
     /home/linuxbrew/.linuxbrew/share/applications \
     -maxdepth 1 -iname '*zed*.desktop' -print 2>/dev/null
```

An empty result is a cask-install problem rather than a launcher-index problem; reinstall
it with `brew reinstall --cask ublue-os/tap/zed-linux`.

**The terminal environment is already there** — the prompt, the aliases and the zsh
plugins are files in the image, not anything seeded into your home directory. **Your login
shell is zsh from the first boot after a rebase**, including on an account that was created
long before it: `/etc/passwd` is per machine, so `qubix-default-shell.service` sets it on
the machine, once per account, before logins are permitted (DD-035). To go back:
`sudo usermod -s /bin/bash $USER` — and nothing will change it again. Not `chsh`; Aurora
deletes it from the image. Bash keeps the prompt and the aliases either way.

**A distrobox container gets the same shell**, without being asked: an init hook installs
the tools from the container's own repositories and reads everything else from the host
through `/run/host` (DD-043). A container you created *before* rebasing predates the hook —
`distrobox enter <name> -- sudo /run/host/usr/bin/qubix-distrobox-shell` brings it up to
date, and is safe to run again on any container. **That command is also how a container
receives a later fix**: a container is not rebuilt by a rebase, and a re-run replaces the
block the hook wrote in it rather than leaving it as it was (DD-046).

One thing is still worth doing once:

- **Install the Neovim config:** `git clone https://github.com/LazyVim/starter ~/.config/nvim`,
  then run `nvim` once with a network connection so LazyVim can bootstrap. Keeping it as a
  clone is what makes `git -C ~/.config/nvim pull` work later; `:Lazy update` handles the
  plugins.

All of it, including how to remove any part, is in [`shell.md`](shell.md).

### If you are rebasing from an older Qubix OS

Earlier images seeded `org.mozilla.firefox`. The Flatpak module only ever installs, so the
rebase leaves it behind. Remove it once, by hand:

```bash
flatpak uninstall --system org.mozilla.firefox
```

A fresh installation never gets it.

## Checking what you're running

```bash
cat /etc/os-release
```

Expected fields on Qubix OS:

| Field | Value |
|---|---|
| `ID` | `qubix_os_bluebuild` |
| `NAME` | `QubixOS-BlueBuild` |
| `PRETTY_NAME` | Names the selected dimensions: standard, `CachyOS Kernel`, `NVIDIA Open`, or `NVIDIA Open, CachyOS Kernel`, followed by the upstream `IMAGE_VERSION` |

The version in `PRETTY_NAME` is the **Aurora/Fedora** version the image was built from —
useful when reporting a bug, because it identifies the upstream base. Everything else in
`os-release` is upstream's (DD-003).

Also available: System Settings → **About this System**, which reads
`kcm-about-distrorc` and shows "Qubix OS" with the Qubix logo.

## Building an offline ISO

The [`iso` workflow](../.github/workflows/iso.yml) uses
[`JasonN3/build-container-installer`](https://github.com/JasonN3/build-container-installer)
to embed an already-published Qubix image in an x86_64 Kinoite installer (DD-054, DD-056,
DD-058, DD-059, DD-060, DD-061). It also resolves the application refs in
[`flatpak_refs/iso-refs.txt`](../flatpak_refs/iso-refs.txt), embeds their Flathub objects
and runtime dependencies, and lets Anaconda install them without first-boot network
access. It does not rebuild or release the OCI image.

### Automatic ISO releases

After the `bluebuild` image workflow succeeds on the default branch, the ISO workflow
automatically builds `latest` media for Standard, CachyOS, and NVIDIA in parallel. A
failed, cancelled, pull-request, or non-default-branch image run does not build ISO media.
One ISO failure does not cancel the other two.

After the **iso** run succeeds, open the repository's
[GitHub Releases](https://github.com/Qubik65536/qubix-os-bluebuild/releases). Each variant
has its own release. Its download table puts the anonymous OneDrive ISO link and literal
SHA-256 on the same row, with the checksum-file link immediately below. Scheduled builds
are normal releases; builds originating from a push or either manual route are marked as
prereleases. Expect a multi-gigabyte download.

OneDrive remains the file store: weekly builds live under `scheduled`, while push and
manual builds live under `push`. The workflow permanently keeps three scheduled and five
push/ad-hoc versions per variant, deleting the matching GitHub Release/tag when it purges
a OneDrive version. It also best-effort removes generated GitHub ISO releases more than
three calendar months old. No multi-gigabyte GitHub Actions artifact or GitHub release
asset is created.

The repository maintainer must complete the Entra app, GitHub OIDC environment, and
OneDrive-owner setup once; [`build-and-release.md`](build-and-release.md#microsoft-365-onedrive-setup)
is the authoritative procedure.

### Manual build in the GitHub interface

1. Open **Actions → iso → Run workflow**.
2. Select `standard`, `cachyos`, or `nvidia` and enter the published image tag. `latest`
   is the normal choice.
3. When the run succeeds, open **Releases**, select the new prerelease for that variant,
   compare the displayed literal SHA-256, and use its OneDrive ISO/checksum links. The
   workflow derives Fedora's major version from signed image metadata; there is no
   separate version input to keep in sync.

### Manual build with GitHub CLI

Prerequisites are an authenticated [GitHub CLI](https://cli.github.com/), permission to
dispatch this repository's workflows, and access to the configured Microsoft 365
OneDrive. This sequence builds the current standard image and waits for its upload:

```bash
gh workflow run iso.yml --ref main \
  -f image=standard \
  -f image_tag=latest

run_id="$(gh run list --workflow=iso.yml --event=workflow_dispatch --limit=1 \
  --json databaseId --jq '.[0].databaseId')"
gh run watch "${run_id}" --exit-status
```

Open the release URL printed by the run, download both linked files into one local
directory, compare the checksum shown beside the ISO link, then verify before writing the
ISO to media:

```bash
cd /path/to/downloaded-version
sha256sum -c qubix-os-standard-latest-f44-x86_64.iso-CHECKSUM
```

On macOS, use `shasum -a 256 -c` in place of `sha256sum -c`.

The workflow verifies the selected tag with `cosign.pub`, pins the verified digest for the
ISO payload, derives Fedora's major version from that digest's
`org.opencontainers.image.version` label, and configures the installed system to enforce
Qubix's signed-image policy for later updates. A missing/unrecognisable version label,
missing tag, invalid signature, installer failure, missing output, incomplete OneDrive
transfer, or remote size mismatch fails the run before a complete `v-*` version is
published.

## Uninstalling

Rebase back to whatever you came from, e.g.:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/aurora-dx:latest
systemctl reboot
```

`/home` is untouched by rebasing. Flatpaks installed by the seeding unit remain and can be
removed with `flatpak uninstall`.
