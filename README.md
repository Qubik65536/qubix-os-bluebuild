# Qubix OS &nbsp; [![bluebuild build badge](https://github.com/qubik65536/qubix-os-bluebuild/actions/workflows/build.yml/badge.svg)](https://github.com/qubik65536/qubix-os-bluebuild/actions/workflows/build.yml)

A custom, immutable Fedora Atomic desktop image, built with [BlueBuild](https://blue-build.org)
on top of [Universal Blue](https://universal-blue.org)'s Aurora DX.

| | |
|---|---|
| **Image** | `ghcr.io/qubik65536/qubix-os-bluebuild` |
| **Base** | Aurora DX (`aurora-dx` or `aurora-dx-nvidia-open`, `latest`) |
| **Desktop** | KDE Plasma, plus a Niri session |
| **Signed** | Sigstore cosign — `cosign.pub` |
| **Rebuilt** | Weekly on Sunday at 00:00 UTC, and on every push |

Qubix OS is a thin, deliberately small layer over Aurora DX: Qubix branding, a rewritten
system identity, a handful of extra packages, and Ungoogled Chromium as the default
browser in place of the layered Firefox RPM.
Everything else is inherited upstream. The full delta is in
[`docs/overview.md`](docs/overview.md).

## Variants

Three images are currently published across kernel and NVIDIA-support dimensions — see
[`docs/variants.md`](docs/variants.md).

| Variant | Image suffix | Kernel / driver | Status / requirements |
|---|---|---|---|
| **Standard** | `qubix-os-bluebuild` | Fedora / generic | Active |
| **CachyOS** | `qubix-os-bluebuild-cachyos` | CachyOS / generic | Active; x86-64-v3; CachyOS Secure Boot caveat |
| **NVIDIA** | `qubix-os-bluebuild-nvidia` | Fedora / NVIDIA Open | Active; Turing or newer |
| **NVIDIA+CachyOS** | `qubix-os-bluebuild-nvidia-cachyos` | CachyOS / NVIDIA Open | **Disabled; not built or published** |

Run Standard on non-NVIDIA hardware or NVIDIA on a supported NVIDIA GPU; choose CachyOS
only when you specifically want its kernel. The combined NVIDIA+CachyOS recipe is parked
after repeated driver-build failures and must not be used while disabled.

## Documentation

📖 **[Start here → `docs/README.md`](docs/README.md)**

| | |
|---|---|
| [Overview](docs/overview.md) | What this is, the upstream lineage, goals and non-goals |
| [Architecture](docs/architecture.md) | How a commit becomes a bootable OS |
| [Design decisions](docs/design-decisions.md) | Why the project is built this way (`DD-001`…) |
| [Recipe reference](docs/recipe-reference.md) | Every file and module in `recipes/` |
| [Variants](docs/variants.md) | The published images, how they differ, how to switch |
| [Shell](docs/shell.md) | The terminal environment: prompt, shell, history, editor |
| [Branding](docs/branding.md) | Which asset overrides which upstream path |
| [Build & release](docs/build-and-release.md) | CI, signing, tags, failure triage |
| [Usage](docs/usage.md) | Install, update, roll back, verify |
| [Contributing](docs/contributing.md) | The workflow everyone follows |

**Working on this repo?** Read [`docs/contributing.md`](docs/contributing.md) first.
**An AI agent?** [`AGENTS.md`](AGENTS.md) is mandatory reading — it is the single source of
truth for agent instructions. Open work is tracked in [`.agent/plan.md`](.agent/plan.md).

## Installation

> [!WARNING]
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

Requires an existing Fedora Atomic installation. The first install is **two steps** because
the signature verification policy ships inside the image itself — the first rebase installs
the policy, the second one uses it.

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/qubik65536/qubix-os-bluebuild:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/qubik65536/qubix-os-bluebuild:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

For another **active** variant, substitute its image suffix from the table in both commands. Read
[`docs/variants.md`](docs/variants.md) first: the NVIDIA and CachyOS images have hardware
and Secure Boot requirements the standard image does not.

The Qubix `latest` tag points to the newest successful build. Its Aurora base also follows
the stable `latest` channel, so a new Fedora major arrives after Aurora promotes it to
stable; `latest` pins a channel, not a Fedora number (DD-018).

Updating, rolling back, and uninstalling are covered in [`docs/usage.md`](docs/usage.md).

## ISO

Every successful default-branch [`bluebuild` workflow](.github/workflows/build.yml)
automatically starts the [`iso` workflow](.github/workflows/iso.yml), which turns all three
active `latest` images into x86_64 installers. A manual run can rebuild one variant or use
another published tag. The workflow verifies each image signature, builds the ISO with
[`JasonN3/build-container-installer`](https://github.com/JasonN3/build-container-installer),
and uploads the ISO and checksum to a configured Microsoft 365 work/school OneDrive. Each
installer embeds the declared Aurora/Qubix desktop Flatpaks and their runtimes, with
Ungoogled Chromium in place of Firefox, so Bazaar and the browser are ready at first login.
Each variant keeps three scheduled versions separately from five push/manual versions; older
versions are permanently purged to reclaim space. A per-variant
[GitHub Release](https://github.com/Qubik65536/qubix-os-bluebuild/releases) records the
OneDrive download links, literal SHA-256, signed image digest, and build provenance.
Scheduled media is an official release; push/manual media is a prerelease. Generated ISO
releases older than three months are cleaned up when possible. No large GitHub Actions
artifact or GitHub release asset is created. See
[`docs/usage.md`](docs/usage.md#building-an-offline-iso) for dispatch and download.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
```

Substitute another active variant's full image name to verify it.

## License

[Apache License 2.0](LICENSE).
