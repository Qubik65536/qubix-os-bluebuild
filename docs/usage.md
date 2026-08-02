# Usage

How to install, update, verify, and roll back Qubix OS. This page is the detailed version
of the quick instructions in the [root README](../README.md).

> **Prerequisite:** an existing Fedora Atomic installation (Kinoite, Silverblue, Aurora,
> Bazzite, …). Rebasing replaces the OS image while keeping `/home` and `/etc`
> customisations.

This page uses the **standard** image throughout. A second image with the CachyOS kernel
is also published, with hardware requirements of its own — see
[`variants.md`](variants.md). Every command below works for it by substituting
`qubix-os-bluebuild-cachyos` for `qubix-os-bluebuild`.

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

`latest` always points at the most recent successful CI build. Because `image-version` in
the recipe pins the Aurora channel, `latest` will not silently move you to the next major
Fedora release.

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

## First boot

Flatpaks are **seeded**, not baked in — a systemd unit installs them on first boot, so
first boot needs network access. Expect
`io.github.ungoogled_software.ungoogled_chromium` and `org.gnome.Loupe` to appear shortly
after login, with a desktop notification when the pass finishes (`notify: true`).

**Ungoogled Chromium is the default browser** (DD-023), and it is the only one installed —
Firefox is shipped in neither form. Being a Flatpak, it updates on Flathub's schedule
rather than with the OS.

Links open in it from both sessions without any setup: `/etc/xdg/mimeapps.list` claims the
web MIME types and `/etc/xdg/kdeglobals` sets KDE's `BrowserApplication`. To use something
else, install it and pick it in *System Settings → Default Applications* (Plasma) or run
`xdg-settings set default-web-browser <id>.desktop` — either writes
`~/.config/mimeapps.list`, which is searched **before** the image's copy, so your choice
wins and survives updates.

**The terminal environment is already there** — the prompt, the aliases and the zsh
plugins are files in the image, not anything seeded into your home directory. Two things
are worth doing once:

- **Switch your login shell to zsh:** `chsh -s /usr/bin/zsh`, then log out and back in.
  `/etc/passwd` is per machine, so this is the one thing the image cannot do for an account
  that already exists. Accounts created afterwards get zsh automatically. Bash keeps the
  prompt and the aliases either way.
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
| `PRETTY_NAME` | `Qubix OS (BlueBuild Image, Version: <upstream IMAGE_VERSION>)`, with `CachyOS Kernel,` inserted before `Version` on that variant |

The version in `PRETTY_NAME` is the **Aurora/Fedora** version the image was built from —
useful when reporting a bug, because it identifies the upstream base. Everything else in
`os-release` is upstream's (DD-003).

Also available: System Settings → **About this System**, which reads
`kcm-about-distrorc` and shows "Qubix OS" with the Qubix logo.

## Building an offline ISO

BlueBuild can generate an installable ISO from a published image. Follow the upstream
guide: <https://blue-build.org/how-to/generate-iso/>

ISOs are not published as GitHub release artifacts — they exceed the size limits for free
hosting. Generate one locally on a Fedora Atomic host when you need installation media.

## Uninstalling

Rebase back to whatever you came from, e.g.:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/aurora-dx:latest
systemctl reboot
```

`/home` is untouched by rebasing. Flatpaks installed by the seeding unit remain and can be
removed with `flatpak uninstall`.
