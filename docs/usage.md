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

The manual [`iso` workflow](../.github/workflows/iso.yml) uses
[`JasonN3/build-container-installer`](https://github.com/JasonN3/build-container-installer)
to embed one already-published Qubix image in an x86_64 Kinoite installer (DD-054). It
does not rebuild or release the OCI image.

### In the GitHub interface

1. Open **Actions → iso → Run workflow**.
2. Select `standard`, `cachyos`, or `nvidia` and enter the published image tag. `latest`
   is the normal choice.
3. When the run succeeds, open it and download the artifact from **Artifacts**. The
   workflow derives Fedora's major version from the signed image metadata; there is no
   separate version input to keep in sync.

The artifact is named like `qubix-os-standard-latest-f44-x86_64` and contains both the
ISO and its `-CHECKSUM` file. It expires after seven days and is not attached to a GitHub
Release. Expect a multi-gigabyte download; the exact size is shown on the completed run.

### With GitHub CLI

Prerequisites are an authenticated [GitHub CLI](https://cli.github.com/) and permission to
dispatch this repository's workflows. This exact sequence builds the current standard
Fedora 44 image and downloads its artifact:

```bash
gh workflow run iso.yml --ref main \
  -f image=standard \
  -f image_tag=latest

run_id="$(gh run list --workflow=iso.yml --event=workflow_dispatch --limit=1 \
  --json databaseId --jq '.[0].databaseId')"
gh run watch "${run_id}" --exit-status
gh run download "${run_id}" \
  --name qubix-os-standard-latest-f44-x86_64 \
  --dir qubix-os-standard-latest-f44-x86_64
```

Verify the downloaded ISO before writing it to media:

```bash
cd qubix-os-standard-latest-f44-x86_64
sha256sum -c qubix-os-standard-latest-f44-x86_64.iso-CHECKSUM
```

On macOS, use `shasum -a 256 -c` in place of `sha256sum -c`.

The workflow verifies the selected tag with `cosign.pub`, pins the verified digest for the
ISO payload, derives Fedora's major version from that digest's
`org.opencontainers.image.version` label, and configures the installed system to enforce
Qubix's signed-image policy for later updates. A missing/unrecognisable version label,
missing tag, invalid signature, installer failure, or missing output fails the run before
an artifact is retained.

## Uninstalling

Rebase back to whatever you came from, e.g.:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/aurora-dx:latest
systemctl reboot
```

`/home` is untouched by rebasing. Flatpaks installed by the seeding unit remain and can be
removed with `flatpak uninstall`.
