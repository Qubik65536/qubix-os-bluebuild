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
first boot needs network access. Expect `org.mozilla.firefox` and `org.gnome.Loupe` to
appear shortly after login, with a desktop notification when the pass finishes
(`notify: true`).

Firefox is the Flatpak, not an RPM (DD-006), so it updates on Flathub's schedule rather
than with the OS.

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
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/aurora-dx:beta
systemctl reboot
```

`/home` is untouched by rebasing. Flatpaks installed by the seeding unit remain and can be
removed with `flatpak uninstall`.
