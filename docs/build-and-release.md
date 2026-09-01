# Build and Release

## There is no local build

Images are built **only** by GitHub Actions. This is not a limitation to work around — it
is what makes every published image reproducible from a commit and signed by CI.

What you *can* do locally:

| Check | How |
|---|---|
| Recipe schema | The `yaml-language-server` comment at the top of each file in `recipes/` gives editors live validation. |
| YAML syntax | `for f in recipes/*.yml; do ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$f"; done` |
| Composed module order | Expand every `from-file:` and check the rendered list against [`architecture.md`](architecture.md). |
| Asset paths | Confirm the path under `files/system/` matches the intended image path. |
| Asset sync | `shasum -a 256` across the branding groups — see [`branding.md`](branding.md). |
| Shell syntax | `bash -n` on the `.sh`/`.bash` files in the overlay, `zsh -n` on `qubix.zsh`. Parsing only — it proves nothing about whether a plugin loads. |
| Python syntax | `python3 -m py_compile files/system/usr/bin/qubix-*`. Same caveat. |

What you cannot do locally: confirm a package exists, confirm a COPR resolves, confirm the
`sed` patterns match upstream's `os-release`, confirm the kernel swap leaves a bootable
image, or confirm anything renders. Those need CI — and the kernel needs real hardware.

> **For agents:** never describe a change as "verified" or "working" on the basis of local
> inspection. Say what you checked and say that CI is the actual verification.

## The image workflow

[`.github/workflows/build.yml`](../.github/workflows/build.yml)

| Aspect | Value | Notes |
|---|---|---|
| Name | `bluebuild` | |
| Jobs | `select-recipes` → `bluebuild` | The first decides what to build; the second is the matrix that builds it. |
| Runner | `ubuntu-latest` | |
| Action | `blue-build/github-action@v1.11` | Does the whole build, tag, sign, and push. |
| Matrix | `recipe: ${{ fromJSON(needs.select-recipes.outputs.recipes) }}` | One job per recipe. |
| `fail-fast` | `false` | One failing variant doesn't cancel the others. |
| `timeout-minutes` | `90` | A full build is 30–45 min; this only catches a hung run. |
| `maximize_build_space` | `true` | Reclaims runner disk before building; the images are large. |

### What gets built

| Recipe | Image |
|---|---|
| `recipe.yml` | `ghcr.io/qubik65536/qubix-os-bluebuild` |
| `recipe-cachyos.yml` | `ghcr.io/qubik65536/qubix-os-bluebuild-cachyos` |
| `recipe-nvidia.yml` | `ghcr.io/qubik65536/qubix-os-bluebuild-nvidia` |

`recipe-nvidia-cachyos.yml` remains in the repository but is **disabled**: it is absent
from both the automatic matrix and manual choices, so CI does not build, sign, or publish
it (DD-052). A registry tag left by an earlier attempt is not a current release.

`recipes/common-*.yml` files are **included**, never built ([`variants.md`](variants.md),
DD-016).

### Selecting recipes

`select-recipes` emits a JSON array that becomes the matrix:

- Push, PR, schedule → the three active recipes.
- `workflow_dispatch` → the `recipe` input: `all` (default) or one active recipe filename.

Manual single-variant runs exist for the case where one image needs a rebuild — an
upstream fix, or a COPR that was briefly broken — and rebuilding all three would be waste.

**Adding or re-enabling a variant means editing the workflow in two places:** the
`workflow_dispatch` `options` list and the `all` branch of `select-recipes`. Both carry a
comment saying so.

### Triggers

| Trigger | When | Notes |
|---|---|---|
| `schedule` | `00 06 * * *` (daily, 06:00 UTC) | ~20 min after Universal Blue starts building. DD-009. |
| `push` | Any branch, **except** commits touching only `**.md` | `paths-ignore` — DD-010. |
| `pull_request` | Every PR | Always builds, even docs-only. This validates the recipe before merge. |
| `workflow_dispatch` | Manual | Use after an upstream fix lands, instead of waiting for the cron. Takes a `recipe` input to build one variant. |

### Concurrency

```yaml
group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
cancel-in-progress: true
```

One run per ref at a time; a newer push cancels the running one. Rapid pushes cost one
run, not five. The whole matrix is cancelled together, so variants are never partially
superseded.

### Permissions

| Permission | Why |
|---|---|
| `contents: read` | Check out the repository. |
| `packages: write` | Push the image to GHCR. |
| `id-token: write` | OIDC token for Sigstore/cosign signing. |

Nothing needs more; do not widen these.

## The ISO workflow

[`.github/workflows/iso.yml`](../.github/workflows/iso.yml) is a separate, manual workflow
that turns one **already published** image into installation media. Keeping it separate
means daily OCI rebuilds do not create three multi-gigabyte artifacts (DD-054).

| Aspect | Value |
|---|---|
| Name / trigger | `iso` / `workflow_dispatch` only |
| Runner | `ubuntu-latest`, x86_64 output |
| Installer action | `JasonN3/build-container-installer` v1.5.0, pinned to commit `bed71f8…` |
| Installer variant | Kinoite |
| Timeout | 120 minutes |
| Output | ISO plus generated SHA-256 checksum |
| Storage | GitHub Actions artifact, seven days, compression disabled |
| Publication | No GitHub Release and no registry upload |

### ISO inputs

| Input | Values | Default | Constraint |
|---|---|---|---|
| `image` | `standard`, `cachyos`, `nvidia` | `standard` | Active images only; the parked combined image is absent. |
| `image_tag` | Any valid published OCI tag | `latest` | Validated before it reaches the upstream action. |

The preparation step maps the friendly variant to its exact GHCR image. The workflow then
checks that tag against [`cosign.pub`](../cosign.pub), extracts the signed manifest digest,
reads Fedora's major from that digest's `org.opencontainers.image.version` label, and gives
the installer action a `docker://…@sha256:…` source. There is deliberately no separately
maintained Fedora-version input. The mutable tag remains the installed system's update
target, where `image_signed: true` enables Qubix's embedded signature policy. Thus the ISO
contains the manifest that CI authenticated while later updates continue to follow the
selected channel and require valid signatures.

After a successful run, download the named artifact from the run summary or use
`gh run download`; [`usage.md`](usage.md#building-an-offline-iso) has the complete command
sequence and checksum check.

## Signing

| Piece | Where it lives |
|---|---|
| Private key | GitHub Actions secret `SIGNING_SECRET` (repository settings). Never in git. |
| Public key | [`../cosign.pub`](../cosign.pub), committed. |
| Client trust policy | Installed **into the image** by the `signing` module in the recipe. |

All images are signed with the same key. Verify the published images:

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild-cachyos
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild-nvidia
```

Because the trust policy ships inside the image, a machine that has never run Qubix OS
does not yet have it — hence the two-step first install in [`usage.md`](usage.md).

`.gitignore` excludes `cosign.key` and `cosign.private`. Committing either means
regenerating the keypair, updating `cosign.pub` and `SIGNING_SECRET`, and every existing
installation failing verification until it rebases.

## Tags

| Tag | Meaning |
|---|---|
| `latest` | The most recent successful build of that image. What users rebase to. Each variant has its own. |
| `<date>` / `<version>` | Per-build tags produced by the BlueBuild action. Useful for pinning or rolling back to a specific day. |
| PR tags | Pull-request builds are tagged separately via `pr_event_number` and are not `latest`. |

`latest` tracks builds, not Fedora versions. The Fedora base is pinned by
`image-version: latest` in the recipe, which names Aurora's stable channel rather than one
Fedora release. A major Fedora jump therefore happens when Aurora promotes a new stable
release into that channel; no recipe edit is required. Note the two related-but-distinct
meanings: this project's `latest` tag is its newest successful build, while the base
image's `latest` channel is the current stable Fedora (DD-018).

## Dependency updates

[`.github/dependabot.yml`](../.github/dependabot.yml) checks GitHub Actions daily and
opens PRs for the BlueBuild, checkout, cosign, container-installer, and artifact actions.
Review upstream changelogs before merging. ISO workflow actions use immutable commit SHAs
with release comments so Dependabot can retain the pinning style.

## When a build fails

1. Open the failing run in the Actions tab and read the BlueBuild step's log.
2. Classify it:
   - **Package not found / COPR error** → upstream repo problem. Often transient; retry via
     `workflow_dispatch` — targeting just the affected variant — before changing a recipe.
   - **`sed` matched nothing** → upstream changed `os-release`. Re-check DD-003's
     assumptions.
   - **File copy error** → a path under `files/system/` is wrong.
   - **One variant failed while the others passed** → the fault is in that recipe's
     base or variant-only modules, not in `common-base.yml`, which all images share.
   - **Kernel swap assertion failed** (`test … -eq 1`, CachyOS variant) → more or fewer
     than one kernel is left in `/usr/lib/modules`. Usually the CachyOS COPR did not
     provide a kernel for the current Fedora release, or Fedora renamed a kernel
     subpackage. See DD-017 and [`variants.md`](variants.md).
   - **`dracut` failure in the `initramfs` module** → the kernel installed but its modules
     are incomplete. Read the module list the swap logged.
   - **`%posttrans scriptlet failed` / `modules.dep is missing. Did you run depmod?`** →
     the kernel install ran RPM scriptlets. `--setopt=tsflags=noscripts` must be on that
     `dnf5 install`, with `depmod` after it. See DD-017.
   - **A package vanished from the CachyOS variant** → check the "Packages the kernel
     removal took with it" list in that build's log against the reinstall line in
     `common-kernel-cachyos.yml`.
   - **While re-enabling the parked NVIDIA+CachyOS recipe:** `akmod-nvidia` `%post` says
     **“Not to be used as root”** → Fedora's
     `akmods-ostree-post` compose hook ran instead of the recipe's privilege-separated
     build. Confirm `akmods` is installed before the hook-suppression step, that
     `akmod-nvidia` is installed between suppression and restoration, and that the
     explicit `akmods` call follows restoration. See DD-051.
   - **While re-enabling NVIDIA+CachyOS:** `rpm-tmp…: Permission denied` or
     `failed to create package build directory` → the `akmods` account cannot use RPM's
     scratch directories. Keep `/tmp` and `/var/tmp` at mode `1777` and retain the
     preflight write checks immediately before `akmods`. See DD-051.
   - **While re-enabling NVIDIA+CachyOS:** `akmods` or `modinfo` fails → the current
     NVIDIA Open source did not compile or package against the current CachyOS kernel.
     Do not bypass the assertions or add the recipe back to CI; use the Fedora-kernel
     NVIDIA image until the combined recipe builds cleanly. DD-051, DD-052.
   - **`test "$(git -C … rev-parse HEAD)" = …` failed** (all variants) → the
     `zsh-completions` tag no longer points at the pinned commit, or the clone failed. The
     assertion is doing its job: check the tag upstream, then update **both** the tag and
     the hash in `common-base.yml`. Do not remove the check. See DD-026.
   - **`sha256sum: WARNING: 1 computed checksum did NOT match`** (all variants) → the
     zellij release artifact is not the one that was pinned. Either the download was
     truncated, or upstream replaced the asset. Re-run first; if it repeats, check the
     release's `.sha256sum` file and update **both** the version and the hash in
     `common-base.yml`. Do not relax the check. See DD-033.
   - **`grep -qF '[CONFIG FILE]: Well defined.'` failed** (all variants) → the KDL in
     `files/system/etc/zellij/config.kdl` does not parse, or zellij did not resolve
     `/etc/zellij` as its config directory. The preceding `zellij setup --check` output is
     in the build log and names the error. See DD-033.
   - **Disk space** → confirm `maximize_build_space: true` is still set. Three large image
     jobs run independently, and each gets its own runner.
   - **Signing failure** → `SIGNING_SECRET` missing, malformed, or rotated.
   - **ISO cosign verification failure** → the selected tag is absent, unsigned, signed by
     another key, or the registry is unavailable. Do not bypass the check.
   - **ISO version-label failure** → the selected image no longer carries BlueBuild's
     recognisable `org.opencontainers.image.version`; update the parser only after checking
     the replacement label is part of the verified manifest.
   - **ISO Lorax/repository failure** → Fedora may have retired or moved the selected old
     tag's installer repositories. The Fedora version is derived from the image, not typed.
   - **ISO upload says no files were found** → the installer action failed to emit the ISO
     or checksum at its advertised outputs. Keep `if-no-files-found: error` intact.
3. Record anything non-obvious: a `plan.md` task if it needs fixing, a `DD-###` record if
   it changes a decision, and a note in the relevant `docs/` page.
