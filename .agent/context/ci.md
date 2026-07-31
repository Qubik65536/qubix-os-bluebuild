# Context: `.github/`

**Covers:** `.github/workflows/build.yml`, `.github/dependabot.yml`, `.github/CODEOWNERS`,
`.github/copilot-instructions.md`

## Purpose

Everything about how the image gets built, signed, and published — plus repository
automation. CI is the **only** place the image is ever built.

## Essential details

### `workflows/build.yml`

- Workflow `bluebuild`, **two jobs** on `ubuntu-latest`:
  - `select-recipes` — emits a JSON array of recipe filenames as its `recipes` output.
  - `bluebuild` — a matrix over that array; each job does all its work through
    `blue-build/github-action@v1.11`.
- **Triggers:** daily cron `00 06 * * *` (~20 min after Universal Blue starts, DD-009);
  `push` with `paths-ignore: "**.md"` (DD-010); every `pull_request`;
  `workflow_dispatch` with a `recipe` choice input (`all` | `recipe.yml` |
  `recipe-cachyos.yml`).
- **Concurrency:** grouped by workflow + ref, `cancel-in-progress: true` — a newer push
  cancels the running run, whole matrix included.
- **Permissions:** `contents: read`, `packages: write`, `id-token: write` (OIDC for
  Sigstore). Don't widen.
- **Matrix:** `recipe: ${{ fromJSON(needs.select-recipes.outputs.recipes) }}`,
  `fail-fast: false`, `timeout-minutes: 90`. Job name is `Build <recipe>`.
- **Inputs:** `cosign_private_key: ${{ secrets.SIGNING_SECRET }}`,
  `registry_token: ${{ github.token }}`, `pr_event_number`, `maximize_build_space: true`.
- **Images built:** `recipe.yml` → `qubix-os-bluebuild`; `recipe-cachyos.yml` →
  `qubix-os-bluebuild-cachyos` (`docs/variants.md`). Both signed with the same key.

### `dependabot.yml`

Daily updates for the `github-actions` ecosystem — in practice, bumps to
`blue-build/github-action`. Read its changelog before merging; a major bump can change
module semantics.

### `CODEOWNERS`

**Currently still `* @xynydev @fiftydinar`** — the BlueBuild template authors, not this
repo's maintainers. Tracked as open task `MNT-001`.

### `copilot-instructions.md`

Pointer to `AGENTS.md`. Contains no instructions of its own — keep it that way.

## Gotchas

- **Adding a variant means editing `build.yml` in two places:** the `workflow_dispatch`
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

## Update when

You change triggers, permissions, the action version, the matrix, or signing. Then also
update `docs/build-and-release.md`.
