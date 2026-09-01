# Context: `.github/`

**Covers:** `.github/workflows/build.yml`, `.github/workflows/iso.yml`,
`.github/dependabot.yml`, `.github/CODEOWNERS`, `.github/copilot-instructions.md`

## Purpose

Everything about how the images get built, signed, and published, and how ad-hoc installer
ISOs are retained — plus repository automation. CI is the **only** place images and ISOs
are built.

## Essential details

### `workflows/build.yml`

- Workflow `bluebuild`, **two jobs** on `ubuntu-latest`:
  - `select-recipes` — emits a JSON array of recipe filenames as its `recipes` output.
  - `bluebuild` — a matrix over that array; each job does all its work through
    `blue-build/github-action@v1.11`.
- **Triggers:** daily cron `00 06 * * *` (~20 min after Universal Blue starts, DD-009);
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

- Workflow `iso`, **manual dispatch only**, with one `build-iso` job on `ubuntu-latest`
  and a 120-minute timeout. It consumes a published image; it never builds or pushes one.
- Inputs: active `image` choice (`standard`, `cachyos`, `nvidia`) and `image_tag` (default
  `latest`). Fedora's major version is derived from the verified digest's
  `org.opencontainers.image.version` label rather than maintained as another input.
- Maps the choice to the exact `ghcr.io/qubik65536/qubix-os-bluebuild*` name and rejects
  unsafe tag/version input before it reaches shell-bearing action inputs.
- Checks out `cosign.pub`, verifies the selected tag, extracts its signed manifest digest,
  and passes that digest as `image_src` to `JasonN3/build-container-installer` v1.5.0.
  All external actions are pinned to immutable commits with release comments.
- `image_signed: true` makes the installed system follow the selected tag through Qubix's
  signature policy. It is distinct from the explicit pre-build cosign verification.
- Uploads the ISO and its generated checksum together with compression level 0, errors if
  either output is absent, retains them seven days, and has no release/publication step.
- Concurrency is per image/tag tuple and cancels a superseded identical run.
- Permission is only `contents: read`; source images are public and artifact upload needs
  no additional token scope. DD-054 owns the rationale.

### `dependabot.yml`

Daily updates for the `github-actions` ecosystem: BlueBuild plus the checkout, cosign,
container-installer, and artifact actions. Read changelogs before merging; action SHAs in
`iso.yml` must remain immutable and keep their release comments.

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
- ISO generation is not chained to the image workflow. Dispatch it only after the desired
  tag exists. If BlueBuild changes its version label format, the derivation fails closed.
- `image_signed` does not authenticate the builder's registry copy. The separate cosign
  step and digest-valued `image_src` do; do not remove either or replace the digest with
  the mutable tag.
- Adding an active variant also requires adding its choice and mapping in `iso.yml`.
- ISO artifacts expire after seven days and are not GitHub Releases.

## Update when

You change triggers, permissions, action versions, image/ISO selection, artifact retention,
the matrix, or signing. Then also update `docs/build-and-release.md`.
