# Context: `.github/`

**Covers:** `.github/workflows/build.yml`, `.github/workflows/iso.yml`,
`.github/actions/upload-onedrive/**`, `.github/dependabot.yml`, `.github/CODEOWNERS`,
`.github/copilot-instructions.md`

## Purpose

Everything about how the images get built, signed, and published, and how installer ISOs
are retained in OneDrive and indexed as GitHub Releases — plus repository automation. CI
is the **only** place images and ISOs are built.

## Essential details

### `workflows/build.yml`

- Workflow `bluebuild`, **two jobs** on `ubuntu-latest`:
  - `select-recipes` — emits a JSON array of recipe filenames as its `recipes` output.
  - `bluebuild` — a matrix over that array; each job does all its work through
    `blue-build/github-action@v1.11`.
- **Triggers:** weekly cron `00 00 * * 0` (Sunday at 00:00 UTC, DD-055);
  `push` with `paths-ignore: "**.md"` (DD-010); every `pull_request`;
  `workflow_dispatch` with a `recipe` choice input (`all` or any of the three active
  recipes). The parked NVIDIA+CachyOS recipe is intentionally unavailable (DD-052).
- **Concurrency:** grouped by workflow + ref, `cancel-in-progress: true` — a newer push
  cancels the running run, whole matrix included.
- **Permissions:** `contents: read`, `packages: write`, `id-token: write` (OIDC for
  Sigstore). Don't widen.
- **Matrix:** `recipe: ${{ fromJSON(needs.select-recipes.outputs.recipes) }}`,
  `fail-fast: false`, `timeout-minutes: 90`. Job name is `Build <recipe>`.
- **Inputs:** `cosign_private_key: ${{ secrets.SIGNING_SECRET }}`,
  `registry_token: ${{ github.token }}`, `pr_event_number`, `maximize_build_space: true`.
- **Images built:** standard, CachyOS, and NVIDIA recipes → the matching
  `qubix-os-bluebuild{,-cachyos,-nvidia}` images. All use one signing key.
- **Disabled:** `recipe-nvidia-cachyos.yml` remains in `recipes/` but appears in neither
  selector location, so no trigger can build or publish it (DD-052).

### `workflows/iso.yml`

- Workflow `iso` consumes published images; it never builds or pushes them. It starts on a
  completed `bluebuild` run filtered to `main`, and still supports manual dispatch.
- `select-images` guards automatic events on upstream `success`, a non-PR event, and the
  repository default branch. It emits all three active images at `latest` automatically,
  or the one manually selected image/tag. It also emits the retention channel/count:
  upstream `schedule` → `scheduled`/3; upstream `push` or either manual route → `push`/5;
  any unknown upstream event fails closed.
- `build-iso` is an `ubuntu-latest` matrix with a 180-minute timeout and `fail-fast: false`;
  the limit covers both Lorax and the multi-gigabyte OneDrive transfer.
  Automatic runs build Standard, CachyOS, and NVIDIA independently; manual runs have one
  cell.
- Inputs: active `image` choice (`standard`, `cachyos`, `nvidia`) and `image_tag` (default
  `latest`). Fedora's major version is derived from the verified digest's
  `org.opencontainers.image.version` label rather than maintained as another input.
- Maps the choice to the exact `ghcr.io/qubik65536/qubix-os-bluebuild*` name and rejects
  unsafe tag input before it reaches shell-bearing action inputs.
- Checks out `cosign.pub`, verifies the selected tag, extracts its signed manifest digest,
  and passes that digest as `image_src` to `JasonN3/build-container-installer` v1.5.0.
  All external actions are pinned to immutable commits with release comments.
- `image_signed: true` makes the installed system follow the selected tag through Qubix's
  signature policy. It is distinct from the explicit pre-build cosign verification.
- Targets the GitHub `onedrive` environment and grants `id-token: write`. Environment
  variables provide `ONEDRIVE_TENANT_ID`, `ONEDRIVE_CLIENT_ID`, and `ONEDRIVE_USER_ID`;
  no Microsoft client secret or Azure subscription is used.
- The repository-local `actions/upload-onedrive` exchanges GitHub OIDC for a Graph token,
  uploads the ISO/checksum pair in aligned resumable chunks, verifies both byte counts,
  renames a staging directory into the complete `v-*` set, calculates the literal ISO
  SHA-256, and creates durable anonymous read-only links for both files.
- Before exchange, the uploader decodes only the non-secret JWT payload and logs `iss`,
  `sub`, `aud`, repository/environment, and immutable owner/repository IDs. Entra rejection
  reports one safe HTTP/error-code/description diagnostic; neither assertion nor Graph
  token is printed.
- OneDrive layout is `Qubix-OS/ISOs/<variant>/<scheduled|push>/v-<version>/`. After
  publication, Graph permanently deletes complete directories beyond three scheduled or
  five push/manual versions for that variant and channel. Staging directories are
  excluded and cleaned up on action failure.
- No ISO is uploaded as a GitHub Actions artifact or release asset. The local
  `actions/publish-iso-release` action instead creates one per-variant GitHub Release whose
  notes contain the OneDrive links, literal SHA-256, OCI digest, and build provenance
  (DD-060). Scheduled builds are normal releases; push and manual builds are prereleases.
- OneDrive count purges return exact version names so their matching generated GitHub
  Release/tag can be removed. The release action also best-effort removes generated ISO
  releases more than three calendar months old; cleanup warnings do not fail the new
  publication.
- Every trigger uses the non-cancelling `iso-onedrive` concurrency group. Whole workflow
  runs serialize; the three automatic matrix cells still run in parallel. This bounds
  staging to three concurrent ISOs and prevents cross-run retention races (DD-059).
- ISO job permissions are `contents: write` for release/tag publication and
  `id-token: write` for OneDrive. DD-054/DD-056 own source and trigger policy, DD-058/DD-059
  own OneDrive transfer/count retention, and DD-060 owns release indexing and age cleanup.

### `dependabot.yml`

Daily updates for the `github-actions` ecosystem: BlueBuild plus the checkout, cosign, and
container-installer actions. Read changelogs before merging; external action SHAs in
`iso.yml` must remain immutable and keep their release comments. The OneDrive action is
local and is reviewed with this repository.

### `CODEOWNERS`

**Currently still `* @xynydev @fiftydinar`** — the BlueBuild template authors, not this
repo's maintainers. Tracked as open task `MNT-001`.

### `copilot-instructions.md`

Pointer to `AGENTS.md`. Contains no instructions of its own — keep it that way.

## Gotchas

- **Adding or re-enabling a variant means editing `build.yml` in two places:** the `workflow_dispatch`
  `options` list and the `all` branch of `select-recipes`. Miss the second and the image
  is never built; miss the first and it can't be dispatched on its own.
- Only `recipes/recipe*.yml` may appear there. A `common-*.yml` file has no `name:` or
  `base-image:` and is not buildable (DD-016).
- `paths-ignore` skips a push only when **every** changed path matches; a commit touching a
  `.md` file *and* a recipe still builds.
- `paths-ignore` applies to `push` only — PRs always build.
- A docs-only change therefore can't be "verified by CI". Don't imply it was.
- `SIGNING_SECRET` is a repository secret; `cosign.key` / `cosign.private` are gitignored
  and must never be committed.
- Automatic ISO generation is chained only to a successful default-branch image workflow;
  failed, cancelled, PR, and non-default-branch completions consume no ISO build jobs.
  Manual dispatch still requires the desired tag to exist. If BlueBuild changes its
  version label format, derivation fails closed.
- `image_signed` does not authenticate the builder's registry copy. The separate cosign
  step and digest-valued `image_src` do; do not remove either or replace the digest with
  the mutable tag.
- Adding an active variant also requires adding its choice and mapping in `iso.yml`.
- The OneDrive target must be a provisioned Microsoft 365 work/school drive. The Entra app
  needs tenant-admin consent for application permission `Sites.ReadWrite.All`, which is
  tenant-wide even though the action addresses only the configured user.
- The tenant must permit anonymous SharePoint/OneDrive sharing. Organization-only links
  are rejected because GitHub Releases are public; short-lived Graph download URLs must
  never be persisted in release notes.
- Entra federation matching is exact and case-sensitive. The traditional subject is
  `repo:Qubik65536/qubix-os-bluebuild:environment:onedrive`, with issuer
  `https://token.actions.githubusercontent.com` and audience `api://AzureADTokenExchange`.
  Newer GitHub immutable subjects can add numeric IDs; the logged `sub` is authoritative.
- Retention uses `permanentDelete`, not ordinary drive-item deletion. Excess versions do
  not enter the recycle bin and cannot be restored. Item IDs come only from the selected
  variant directory, and retention begins only after both new files verify.
- A new `v-*` remains rollback-owned until retention succeeds. Upload or retention failure
  attempts to permanently remove that invocation's directory; persistent Graph failure
  can require manual cleanup, and a partial purge can leave fewer versions.
- Manually dispatched image builds also trigger `workflow_run`, and `iso.yml` has its own
  dispatch. Both intentionally share the five-version `push` pool; do not add a third
  retention class implicitly.
- With three active variants at 8 GB each, the steady retained payload is 192 GB and the
  post-upload/pre-purge peak is 216 GB. Approximate sizes and metadata justify 250 GB of
  available quota.
- Release tags use `iso-<variant>-<channel>-<version>`. Cleanup validates that strict family
  before mutation, deletes releases before tags, and remains best-effort so a GitHub API
  cleanup outage cannot hide a newly published installer.

## Update when

You change triggers, permissions, action versions, image/ISO selection, OneDrive identity
or retention, the matrix, or signing. Then also update `docs/build-and-release.md`.
