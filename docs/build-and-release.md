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
| `schedule` | `00 00 * * 0` (weekly, Sunday at 00:00 UTC) | Refreshes active images once a week. DD-055. |
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

[`.github/workflows/iso.yml`](../.github/workflows/iso.yml) turns **already published**
images into installation media. It runs automatically after successful default-branch
image publication and retains a manual single-image/tag path (DD-054, DD-056, DD-058,
DD-059, DD-060, DD-061).

| Aspect | Value |
|---|---|
| Name / triggers | `iso` / completed `bluebuild` workflow, plus `workflow_dispatch` |
| Runner | `ubuntu-latest`, x86_64 output |
| Automatic matrix | `standard`, `cachyos`, `nvidia` from `latest`; `fail-fast: false` |
| Installer action | `JasonN3/build-container-installer` v1.5.0, pinned to commit `bed71f8…` |
| Installer variant | Kinoite |
| Embedded applications | 25 apps, the Breeze theme runtime, and resolved dependencies from `flatpak_refs/iso-refs.txt` |
| Dependency scanner | `umoci` v0.6.0, pinned by SHA-256 ahead of the installer action |
| Timeout | 180 minutes (installer build plus multi-gigabyte upload) |
| Output | ISO plus generated SHA-256 checksum |
| Storage | Microsoft 365 work/school OneDrive; 3 scheduled + 5 push/ad-hoc versions per variant |
| Publication | ISO/checksum in `Qubix-OS/ISOs/<variant>/<channel>/v-<version>/`; per-variant GitHub Release containing links and provenance |
| Authentication | GitHub OIDC → Microsoft Entra federated credential; no client secret |
| GitHub permissions | `contents: write` for releases/tags; `id-token: write` for OneDrive OIDC |

### ISO inputs

| Input | Values | Default | Constraint |
|---|---|---|---|
| `image` | `standard`, `cachyos`, `nvidia` | `standard` | Active images only; the parked combined image is absent. |
| `image_tag` | Any valid published OCI tag | `latest` | Validated before it reaches the upstream action. |

### Embedded desktop Flatpaks

`build-container-installer` embeds no Flatpaks unless it receives
`flatpak_remote_refs` or `flatpak_remote_refs_dir`. The published OCI image contains
Aurora's Brewfiles and Qubix's first-boot Flatpak configuration, but neither is implicitly
an installer input. Omitting the action input therefore produced a valid OS installation
whose KDE layout referenced the missing Bazaar desktop file and whose Qubix applications
depended entirely on a later online timer (DD-061).

[`flatpak_refs/iso-refs.txt`](../flatpak_refs/iso-refs.txt) is the installer source of
truth. Its groups are:

| Source policy | Refs | Count |
|---|---|---:|
| [Aurora desktop defaults](https://github.com/get-aurora-dev/common/blob/main/system_files/shared/usr/share/ublue-os/homebrew/system-flatpaks.Brewfile) | 20 apps including Bazaar, Warehouse, Flatseal, KDE/GNOME utilities and Thunderbird; one Breeze theme runtime | 21 |
| [Aurora DX defaults](https://github.com/get-aurora-dev/common/blob/main/system_files/shared/usr/share/ublue-os/homebrew/system-dx-flatpaks.Brewfile) | Podman Desktop, Embellish, Dev Toolbox | 3 |
| Qubix additions | Ungoogled Chromium, Loupe | 2 |
| **Total** | | **26** |

Firefox is deliberately absent even though Aurora's upstream desktop Brewfile includes
it: DD-023 makes Ungoogled Chromium the only browser on a fresh Qubix installation. Zed is
also absent because IDE choice is personal; it remains available from the inherited
`ublue-os` Homebrew tap as documented in [`usage.md`](usage.md#homebrew-and-the-ublue-os-tap).

Before invoking the installer action, the workflow removes comments and blank lines,
validates every complete `app|runtime/<id>/x86_64/<branch>` ref, and fails unless all 26
refs are unique, Firefox is absent, and Bazaar, Ungoogled Chromium, Loupe, and the Breeze
theme runtime are present. The generated directory is passed as
`flatpak_remote_refs_dir`. The pinned action resolves runtime dependencies, creates an
offline Flathub repository, and exposes it to Anaconda, which installs those refs into the
new system. A rebase does not consume installer media, so the recipe's first-boot
Chromium/Loupe seeding remains necessary for that path.

Dependency resolution first unpacks the signed Qubix OCI image and runs Flatpak inside
that userspace. The action installs Ubuntu 24.04's `umoci` 0.4.7 for this step, but that
release predates zstd-compressed OCI layers and rejects current BlueBuild images. An
initial workaround downloaded the official
[`umoci` v0.6.0](https://github.com/opencontainers/umoci/releases/tag/v0.6.0)
Linux/amd64 binary, verified its hard-coded SHA-256, and prepended its temporary directory
through `GITHUB_PATH` before the action ran. That first workaround was insufficient: the
action invokes the unpack through `sudo make`, and sudo's secure path discarded the runner
override and selected `/usr/bin/umoci` 0.4.7 again.

The workflow now installs the verified binary at `/usr/local/bin/umoci`, which precedes
`/usr/bin` in both the runner and sudo secure paths. A separate step fails unless normal
and privileged command lookup both resolve that exact path and report version 0.6.0. The
action may install its distro package afterward, but it cannot replace the verified
`/usr/local/bin` copy.

Do not work around this by setting `enable_flatpak_dependencies: false`. The older Fedora
Lorax template installs dependencies into a temporary Flatpak repository but copies only
the explicitly requested refs into the ISO repository. The action's enabled scanner is
what expands the manifest to every required runtime and extension before embedding it.

This manifest is intentionally repository-owned rather than downloaded from Aurora during
CI: a Qubix commit determines its installer contents reproducibly and an upstream app-list
change cannot silently add Firefox or another application. When Aurora changes either
upstream system or DX Flatpak Brewfile linked above, review and mirror the wanted change
here explicitly.

### Automatic trigger guard

GitHub emits `workflow_run` after every completion of the `bluebuild` workflow. The ISO
workflow filters that event to `main`, then its selector job requires all three of these:

- the upstream conclusion is `success`;
- the upstream event is not `pull_request`;
- the upstream head branch equals the repository's default branch.

An accepted automatic run emits all three active image names and `latest` into the build
matrix. A manual run emits only the selected image and tag. `fail-fast: false` prevents
one Lorax failure from cancelling media for the other variants. Because the image workflow
itself must succeed first, a failed image variant prevents that upstream run from starting
any automatic ISO jobs. The upstream event also selects an independent retention channel:

| Image-build origin | OneDrive channel | Versions per variant |
|---|---|---:|
| Weekly `schedule` | `scheduled` | 3 |
| Default-branch `push` | `push` | 5 |
| Manually dispatched `bluebuild` | `push` | 5 |
| Directly dispatched `iso` | `push` | 5 |

Scheduled media is published as a normal GitHub Release. Push media and both manual paths
are published as prereleases. This affects GitHub presentation only: OneDrive directories
and count retention still follow the channel table.

The two manual paths are real: `workflow_run` observes a successful image
`workflow_dispatch`, and `iso.yml` retains its own manual one-variant route. Both share the
push/ad-hoc pool instead of creating an unbounded third class. An unknown upstream event
fails selection rather than choosing retention implicitly.

The preparation step maps the friendly variant to its exact GHCR image. The workflow then
checks that tag against [`cosign.pub`](../cosign.pub), extracts the signed manifest digest,
reads Fedora's major from that digest's `org.opencontainers.image.version` label, and gives
the installer action a `docker://…@sha256:…` source. There is deliberately no separately
maintained Fedora-version input. The mutable tag remains the installed system's update
target, where `image_signed: true` enables Qubix's embedded signature policy. Thus the ISO
contains the manifest that CI authenticated while later updates continue to follow the
selected channel and require valid signatures.

### Microsoft 365 OneDrive setup

The upload targets a **work or school** OneDrive owned by the configured Microsoft 365
user, including a tenant-native `user@tenant.onmicrosoft.com` account. One-time setup:

1. Make sure the target user is licensed for OneDrive and has opened OneDrive at least
   once, so its drive is provisioned.
   The tenant's SharePoint/OneDrive sharing policy must also permit anonymous links. A
   public GitHub Release cannot use an organization-only link, and Graph deliberately
   fails publication rather than emit a URL that outside users cannot open.
2. In Microsoft Entra ID, create a single-tenant app registration for this repository.
3. Under **API permissions**, add the Microsoft Graph **application** permission
   `Sites.ReadWrite.All`, grant tenant administrator consent, and add no client secret.
   Microsoft currently requires that application permission for
   [`createUploadSession`](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0).
   It can write every SharePoint site and OneDrive in the tenant, so use a dedicated app
   registration and review its consent like any other tenant-wide automation identity.
4. Add a federated credential to the app registration: scenario **GitHub Actions deploying
   Azure resources**, organisation `Qubik65536`, repository `qubix-os-bluebuild`, entity
   type **Environment**, environment `onedrive`. Its audience remains
   `api://AzureADTokenExchange`.
5. In GitHub, create the `onedrive` Actions environment and set these environment
   variables (not secrets):

   | Variable | Value |
   |---|---|
   | `ONEDRIVE_TENANT_ID` | Entra **Directory (tenant) ID** GUID |
   | `ONEDRIVE_CLIENT_ID` | App registration **Application (client) ID** GUID |
   | `ONEDRIVE_USER_ID` | Target user's object ID or full user principal name, such as `iso@tenant.onmicrosoft.com` |

No Azure subscription is required. The `build-iso` job names that environment, requests
`id-token: write`, and exchanges the run-scoped GitHub token directly for a Microsoft
Graph token. An environment approval rule can put a human gate before all three automatic
uploads, but it also means every automatic ISO run waits for that approval.

Issuer, subject, and audience matching is exact and case-sensitive. For the repository's
traditional name-based GitHub subject, the federated credential must contain:

| Federated credential field | Exact value |
|---|---|
| Issuer | `https://token.actions.githubusercontent.com` |
| Subject | `repo:Qubik65536/qubix-os-bluebuild:environment:onedrive` |
| Audience | `api://AzureADTokenExchange` |

GitHub repositories created, renamed, or transferred under its newer immutable-subject
policy can instead emit a subject containing numeric owner/repository IDs, such as
`repo:Qubik65536@<owner-id>/qubix-os-bluebuild@<repository-id>:environment:onedrive`.
Do not infer which form applies. The uploader prints a **non-secret** `GitHub OIDC claims`
line containing the exact `iss`, `sub`, `aud`, repository, environment, and immutable IDs
before exchange. Compare those three claims character-for-character with the Entra app's
federated credential; delete and recreate a mismatched credential. See GitHub's
[`sub` claim formats](https://docs.github.com/en/actions/reference/security/oidc) and
Microsoft's
[exact-match requirements](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-considerations).

### OneDrive layout and retention

Each matrix cell uploads directly from its runner; the multi-gigabyte ISO never passes
through GitHub artifact storage. The local action under
`.github/actions/upload-onedrive/` creates this layout:

```text
Qubix-OS/ISOs/
├── standard/
│   ├── scheduled/v-latest-f44-<digest>-run-<run>-<attempt>/
│   └── push/v-latest-f44-<digest>-run-<run>-<attempt>/
├── cachyos/{scheduled,push}/v-<version>/
└── nvidia/{scheduled,push}/v-<version>/
```

Each `v-*` directory contains exactly the generated ISO and its `-CHECKSUM` file. Uploads
create sessions through Graph's canonical
`/drives/<drive-id>/items/<parent-id>:/<filename>:/createUploadSession` route. The path
already targets a unique empty staging directory, so the request sends no optional
uploadable-item body and uses Graph's documented default fail-on-conflict behavior. The
HTTP request still declares `Content-Length: 0`: some OneDrive for Business front ends
reject a bodyless POST without that explicit transport length as `411 Length Required`.
The same header is applied to the bodyless `permanentDelete` action used by retention.
Data then moves in sequential 50 MiB fragments: 50 MiB is below Graph's 60 MiB request
limit and is divisible by its required 320 KiB boundary. Both remote byte counts must
match before the temporary `.upload-*` directory is renamed to `v-*`.
After the rename, the action creates durable anonymous, read-only sharing links for both
files. It does not record Graph's preauthenticated `downloadUrl`, because that URL is
short-lived and unsuitable for persistent release notes.

After publication, retention is evaluated **within that variant and trigger channel**.
The action sorts complete `v-*` directories by their OneDrive creation time, keeps three
under `scheduled` or five under `push`, and calls Graph's
[`permanentDelete`](https://learn.microsoft.com/en-us/graph/api/driveitem-permanentdelete?view=graph-rest-1.0)
for every older directory. Permanent deletion is deliberate: moving multi-gigabyte media
into the recycle bin would not reclaim the intended storage, and purged versions cannot be
restored. Staging directories are never counted as versions; the action removes its own
staging directory if an upload fails. A renamed new version remains rollback-owned until
retention succeeds. If listing or purging fails, cleanup attempts to permanently remove
that new version; an earlier old-version deletion may already have reduced the history
below its target.

All ISO workflow runs share one non-cancelling `iso-onedrive` concurrency group. Runs are
therefore serialized, while the three variants inside one automatic matrix still upload
in parallel. This prevents retention races and makes the storage ceiling finite.

### GitHub Release index

The ISO remains in OneDrive; GitHub stores only a small, searchable release record. Every
successful matrix cell creates one release and one unique tag:

```text
iso-<variant>-<scheduled|push>-<tag>-f<fedora>-<digest>-run-<run>-<attempt>
```

The release title names the Qubix variant, Fedora major, source class, and UTC date. Its
download table places the durable OneDrive ISO link and the literal SHA-256 on the same
row, followed by the checksum-file link. The rest of the notes record architecture,
installer type, selected image tag, exact signed OCI digest, source event and commit,
UTC publication timestamp, workflow run/attempt, byte size, verification commands, and
retention policy.

Release classification follows the originating image build rather than the event that
delivered `workflow_run`:

| Source | GitHub Release kind |
|---|---|
| Weekly `schedule` | Normal (official) release |
| Default-branch `push` | Prerelease |
| Either manual route | Prerelease |

When OneDrive permanently deletes a version beyond its channel's 3/5 count, the following
release step derives that version's exact generated tag and best-effort deletes both its
GitHub Release and tag. It also scans only tags in the strict generated ISO tag families
and best-effort removes releases whose `published_at` is older than three calendar months.
Cleanup warnings do not invalidate the new release: an API outage
can temporarily leave stale release metadata, but it cannot make a valid new ISO
undiscoverable. A later successful run retries the age scan. Release age does not add a
second OneDrive storage rule; OneDrive remains capped by the stricter per-channel counts.

### OneDrive capacity planning

For an 8 GB ISO, ignoring the tiny checksum files:

| Scope | Calculation | Retained storage |
|---|---:|---:|
| One variant | `(3 scheduled + 5 push) × 8 GB` | 64 GB |
| Three active variants | `3 × 64 GB` | 192 GB |

Retention runs after the new pair uploads, so one automatic matrix can temporarily add
one ISO per variant before the oldest directories are purged: `192 GB + (3 × 8 GB) =
216 GB` peak. A manual run uploads only one variant and cannot overlap another ISO workflow
run, so it does not exceed that automatic-run peak. If “8 GB” actually means 8 GiB, the
corresponding figures are 192 GiB (about 206 GB) retained and 216 GiB (about 232 GB) peak.
Because the measured ISO size is approximate and OneDrive has metadata overhead, provision
at least 250 GB of available quota. The 216 GB figure assumes Graph deletion is available;
a persistent permission/service failure can leave a rollback item needing manual cleanup.

[`usage.md`](usage.md#building-an-offline-iso) covers manual dispatch, downloading the
newest pair through GitHub Releases, and checking its checksum.

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
opens PRs for the BlueBuild, checkout, cosign, and container-installer actions. Review
upstream changelogs before merging. External ISO workflow actions use immutable commit
SHAs with release comments so Dependabot can retain the pinning style; the OneDrive
uploader is repository-local and changes with this repository.

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
   - **ISO workflow has only skipped jobs** → the upstream image run failed, was cancelled,
     came from a pull request/non-default branch, or no longer reports the expected
     workflow-run metadata. Skipping is the intended guard in the first three cases.
   - **ISO cosign verification failure** → the selected tag is absent, unsigned, signed by
     another key, or the registry is unavailable. Do not bypass the check.
   - **ISO version-label failure** → the selected image no longer carries BlueBuild's
     recognisable `org.opencontainers.image.version`; update the parser only after checking
     the replacement label is part of the verified manifest.
   - **ISO Flatpak manifest failure** → fix the malformed/duplicate ref, unexpected count,
     missing required ref, or Firefox entry in `flatpak_refs/iso-refs.txt`; do not
     weaken the fail-closed assertions.
   - **ISO Flatpak dependency/repository failure** → a listed Flathub ref or one of its
     runtimes is unavailable for `x86_64/stable`, or Flathub is unavailable. Confirm the
     application ID and retry a transient outage before changing the manifest.
   - **`umoci` rejects a zstd layer** → confirm the `Install zstd-capable umoci` step ran,
     its checksum passed, and `Verify umoci override` resolved `/usr/local/bin/umoci` for
     both user and sudo lookups. Do not return to a `GITHUB_PATH`-only override: the action
     unpacks under sudo. Do not disable Flatpak dependency discovery; update the pinned
     binary and checksum deliberately if the upstream release asset changes.
   - **ISO Lorax/repository failure** → Fedora may have retired or moved the selected old
     tag's installer repositories. The Fedora version is derived from the image, not typed.
   - **OneDrive action reports a required value is missing** → create/configure the GitHub
     `onedrive` environment and its three variables exactly as documented above.
   - **OneDrive OIDC exchange fails** → read the single Entra HTTP/error diagnostic, then
     compare the logged non-secret `iss`, `sub`, and `aud` claims character-for-character
     with the app's federated credential. Owner/repository/environment case matters, and a
     newer immutable subject may include numeric IDs. An application-not-found error
     instead points to the client ID or tenant ID. Do not replace federation with a stored
     client secret.
   - **OneDrive Graph request returns access denied** → confirm the app has the Graph
     application permission `Sites.ReadWrite.All` with tenant admin consent, and that the
     configured work/school user's OneDrive is provisioned.
   - **OneDrive anonymous-link creation fails** → allow anonymous read-only sharing in the
     tenant's SharePoint/OneDrive policy. Organization-only links are intentionally not
     accepted for public GitHub release notes.
   - **OneDrive upload stalls** → inspect the reported HTTP status and byte offset. The
     action queries the resumable session before retrying; do not reduce chunk alignment
     below Graph's 320 KiB contract or add an Authorization header to fragment PUTs.
   - **OneDrive upload-session creation fails** → read the reported Graph HTTP status,
     error code, message, and request ID. The action intentionally uses the canonical
     drive-ID route with no optional JSON body and an explicit `Content-Length: 0`; preserve
     that minimum request while diagnosing tenant/service failures.
   - **OneDrive retention fails** → the action attempts to roll back the newly renamed
     version. If Graph also rejects cleanup, remove that run's `v-*` directory manually;
     if failure came after one older deletion, the history may contain fewer than its
     target. Fix access and re-run the same source class.
   - **GitHub Release creation fails** → confirm the ISO job still has `contents: write`
     and that repository rules allow the generated `iso-*` tag. The OneDrive pair is
     already valid, but this run is failed because it is not discoverable as required.
   - **GitHub release cleanup warns** → the new release remains valid. Remove stale
     generated `iso-*` releases/tags manually if necessary, or let a later successful ISO
     run retry the three-month scan.
3. Record anything non-obvious: a `plan.md` task if it needs fixing, a `DD-###` record if
   it changes a decision, and a note in the relevant `docs/` page.
