# Qubix OS &nbsp; [![bluebuild build badge](https://github.com/qubik65536/qubix-os-bluebuild/actions/workflows/build.yml/badge.svg)](https://github.com/qubik65536/qubix-os-bluebuild/actions/workflows/build.yml)

A custom, immutable Fedora Atomic desktop image, built with [BlueBuild](https://blue-build.org)
on top of [Universal Blue](https://universal-blue.org)'s Aurora DX.

| | |
|---|---|
| **Image** | `ghcr.io/qubik65536/qubix-os-bluebuild` |
| **Base** | `ghcr.io/ublue-os/aurora-dx:beta` (Fedora Kinoite → Aurora → Aurora DX) |
| **Desktop** | KDE Plasma |
| **Signed** | Sigstore cosign — `cosign.pub` |
| **Rebuilt** | Daily at 06:00 UTC, and on every push |

Qubix OS is a thin, deliberately small layer over Aurora DX: Qubix branding, a rewritten
system identity, two extra packages, and Firefox moved from an RPM to a Flatpak. Everything
else is inherited upstream. The full delta is in [`docs/overview.md`](docs/overview.md).

## Documentation

📖 **[Start here → `docs/README.md`](docs/README.md)**

| | |
|---|---|
| [Overview](docs/overview.md) | What this is, the upstream lineage, goals and non-goals |
| [Architecture](docs/architecture.md) | How a commit becomes a bootable OS |
| [Design decisions](docs/design-decisions.md) | Why the project is built this way (`DD-001`…) |
| [Recipe reference](docs/recipe-reference.md) | Every module in `recipes/recipe.yml` |
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

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

Updating, rolling back, and uninstalling are covered in [`docs/usage.md`](docs/usage.md).

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
```

## License

[Apache License 2.0](LICENSE).
