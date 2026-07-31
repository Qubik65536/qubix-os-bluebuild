# Glossary

Terminology used consistently across this documentation. When writing docs, prefer these
terms over synonyms.

| Term | Meaning |
|---|---|
| **Atomic / image-based** | A Linux system deployed as a whole image rather than as individually installed packages. Updates swap the image; rollback is built in. |
| **Aurora** | Universal Blue's KDE Plasma image, built on Fedora Kinoite with codecs, drivers, and quality-of-life fixes added. |
| **Aurora DX** | Aurora plus a developer toolchain (container tooling, IDEs, virtualisation). This project's base image. |
| **Base image** | The image named in `base-image:` — what the recipe builds `FROM`. |
| **BlueBuild** | The build system used here. Transpiles `recipes/recipe.yml` into a `Containerfile` and builds it. <https://blue-build.org> |
| **Branding asset** | A file under `files/system/` that replaces an upstream logo, banner, or watermark. See [`branding.md`](branding.md). |
| **Context cache** | `.agent/context/` — one brief Markdown entry per file/module, so an agent can orient without reading the whole repo. |
| **COPR** | Fedora's community package repository service. This project enables `atim/starship` and `wezfurlong/wezterm-nightly`. |
| **cosign** | The Sigstore tool used to sign and verify published images. |
| **DD-###** | A design decision record in [`design-decisions.md`](design-decisions.md). |
| **Delta** | What this repository changes relative to Aurora DX. Kept deliberately small. |
| **Deployment** | An `rpm-ostree` bootable instance of an image. Several coexist; the previous one is the rollback target. |
| **Flatpak seeding** | Flatpaks are not baked into the image; a systemd unit installs them on first boot. Hence first boot needs network. |
| **GHCR** | GitHub Container Registry — where the image is published. |
| **`image-version`** | The base image *tag* (`beta` here). A channel, not a Fedora version number. |
| **`IMAGE_VERSION`** | A field Universal Blue writes into `os-release`, identifying the upstream build. Interpolated into `PRETTY_NAME` (DD-003). |
| **Kinoite** | Fedora's official immutable KDE Plasma variant. Aurora's base. |
| **Look-and-feel package** | A KDE Plasma theme bundle under `/usr/share/plasma/look-and-feel/`. Aurora's contains the startup splash this image overrides. |
| **Module** | A step in `recipe.yml` (`files`, `dnf`, `default-flatpaks`, `containerfile`, `signing`). Modules run in file order. |
| **Overlay** | The `files/system/` tree, copied verbatim into the image root. Repository path = image path. |
| **Override** | Shipping a file at an upstream path so the upstream file is replaced in the image. The branding mechanism (DD-004). |
| **Plymouth** | The boot splash system. Reads the watermark this image overrides. |
| **Rebase** | Switching a machine to a different OS image (`rpm-ostree rebase`). How Qubix OS is installed and uninstalled. |
| **Recipe** | `recipes/recipe.yml`. The declarative definition of the image. |
| **`rpm-ostree`** | The package/deployment manager on Fedora Atomic systems. |
| **Signing policy** | Client-side configuration, installed into the image by the `signing` module, that lets `ostree-image-signed:` rebases verify against `cosign.pub`. |
| **Task** | An entry in [`../.agent/plan.md`](../.agent/plan.md) with an ID, category, dependencies, and acceptance criteria. |
| **Universal Blue** | The project producing the `ublue-os` images, including Aurora. |
| **WezTerm** | The GPU-accelerated terminal emulator set as the default in every session (DD-012). Not packaged in Fedora; layered from WezTerm's own COPR. |
