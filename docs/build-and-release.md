# Build and Release

## There is no local build

Images are built **only** by GitHub Actions. This is not a limitation to work around — it
is what makes every published image reproducible from a commit and signed by CI.

What you *can* do locally:

| Check | How |
|---|---|
| Recipe schema | The `yaml-language-server` comment at the top of `recipe.yml` gives editors live validation. |
| YAML syntax | `python3 -c 'import yaml,sys; yaml.safe_load(open("recipes/recipe.yml"))'` |
| Asset paths | Confirm the path under `files/system/` matches the intended image path. |
| Asset sync | `shasum -a 256` across the branding groups — see [`branding.md`](branding.md). |

What you cannot do locally: confirm a package exists, confirm a COPR resolves, confirm the
`sed` patterns match upstream's `os-release`, or confirm anything renders. Those need CI.

> **For agents:** never describe a change as "verified" or "working" on the basis of local
> inspection. Say what you checked and say that CI is the actual verification.

## The workflow

[`.github/workflows/build.yml`](../.github/workflows/build.yml)

| Aspect | Value | Notes |
|---|---|---|
| Name | `bluebuild` | |
| Runner | `ubuntu-latest` | |
| Action | `blue-build/github-action@v1.11` | Does the whole build, tag, sign, and push. |
| Matrix | `recipe: [recipe.yml]` | Add a recipe filename here to publish additional variants. |
| `fail-fast` | `false` | One failing variant doesn't cancel the others. |
| `maximize_build_space` | `true` | Reclaims runner disk before building; the image is large. |

### Triggers

| Trigger | When | Notes |
|---|---|---|
| `schedule` | `00 06 * * *` (daily, 06:00 UTC) | ~20 min after Universal Blue starts building. DD-009. |
| `push` | Any branch, **except** commits touching only `**.md` | `paths-ignore` — DD-010. |
| `pull_request` | Every PR | Always builds, even docs-only. This validates the recipe before merge. |
| `workflow_dispatch` | Manual | Use after an upstream fix lands, instead of waiting for the cron. |

### Concurrency

```yaml
group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
cancel-in-progress: true
```

One build per ref at a time; a newer push cancels the running build. Rapid pushes cost one
build, not five.

### Permissions

| Permission | Why |
|---|---|
| `contents: read` | Check out the repository. |
| `packages: write` | Push the image to GHCR. |
| `id-token: write` | OIDC token for Sigstore/cosign signing. |

Nothing needs more; do not widen these.

## Signing

| Piece | Where it lives |
|---|---|
| Private key | GitHub Actions secret `SIGNING_SECRET` (repository settings). Never in git. |
| Public key | [`../cosign.pub`](../cosign.pub), committed. |
| Client trust policy | Installed **into the image** by the `signing` module in the recipe. |

Verify a published image:

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
```

Because the trust policy ships inside the image, a machine that has never run Qubix OS
does not yet have it — hence the two-step first install in [`usage.md`](usage.md).

`.gitignore` excludes `cosign.key` and `cosign.private`. Committing either means
regenerating the keypair, updating `cosign.pub` and `SIGNING_SECRET`, and every existing
installation failing verification until it rebases.

## Tags

| Tag | Meaning |
|---|---|
| `latest` | The most recent successful build. What users rebase to. |
| `<date>` / `<version>` | Per-build tags produced by the BlueBuild action. Useful for pinning or rolling back to a specific day. |
| PR tags | Pull-request builds are tagged separately via `pr_event_number` and are not `latest`. |

`latest` tracks builds, not Fedora versions. The Fedora base is pinned by
`image-version: beta` in the recipe, so a major Fedora jump only happens when that value
is deliberately changed.

## Dependency updates

[`.github/dependabot.yml`](../.github/dependabot.yml) checks GitHub Actions daily and
opens PRs for new versions (in practice, `blue-build/github-action`). Review the
BlueBuild action's changelog before merging — a major bump can change module semantics.

## When a build fails

1. Open the failing run in the Actions tab and read the BlueBuild step's log.
2. Classify it:
   - **Package not found / COPR error** → upstream repo problem. Often transient; retry via
     `workflow_dispatch` before changing the recipe.
   - **`sed` matched nothing** → upstream changed `os-release`. Re-check DD-003's
     assumptions.
   - **File copy error** → a path under `files/system/` is wrong.
   - **Disk space** → confirm `maximize_build_space: true` is still set.
   - **Signing failure** → `SIGNING_SECRET` missing, malformed, or rotated.
3. Record anything non-obvious: a `plan.md` task if it needs fixing, a `DD-###` record if
   it changes a decision, and a note in the relevant `docs/` page.
