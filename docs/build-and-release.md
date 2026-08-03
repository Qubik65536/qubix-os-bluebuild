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

## The workflow

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

`recipes/common-*.yml` files are **included**, never built ([`variants.md`](variants.md),
DD-016).

### Selecting recipes

`select-recipes` emits a JSON array that becomes the matrix:

- Push, PR, schedule → every recipe.
- `workflow_dispatch` → the `recipe` input: `all` (default) or a single recipe filename.

Manual single-variant runs exist for the case where one image needs a rebuild — an
upstream fix, or a COPR that was briefly broken — and rebuilding both would be waste.

**Adding a variant means editing this file in two places:** the `workflow_dispatch`
`options` list and the `all` branch of `select-recipes`. They are ten lines apart and both
carry a comment saying so.

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

## Signing

| Piece | Where it lives |
|---|---|
| Private key | GitHub Actions secret `SIGNING_SECRET` (repository settings). Never in git. |
| Public key | [`../cosign.pub`](../cosign.pub), committed. |
| Client trust policy | Installed **into the image** by the `signing` module in the recipe. |

Both images are signed with the same key. Verify a published image:

```bash
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild
cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild-cachyos
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
`image-version: latest` in the recipe, so a major Fedora jump only happens when that value
is deliberately changed. Note the two unrelated meanings of `latest` here: this project's
own `latest` tag is the newest successful build, while the base image's `latest` channel is
the current *stable* Fedora (DD-018).

## Dependency updates

[`.github/dependabot.yml`](../.github/dependabot.yml) checks GitHub Actions daily and
opens PRs for new versions (in practice, `blue-build/github-action`). Review the
BlueBuild action's changelog before merging — a major bump can change module semantics.

## When a build fails

1. Open the failing run in the Actions tab and read the BlueBuild step's log.
2. Classify it:
   - **Package not found / COPR error** → upstream repo problem. Often transient; retry via
     `workflow_dispatch` — targeting just the affected variant — before changing a recipe.
   - **`sed` matched nothing** → upstream changed `os-release`. Re-check DD-003's
     assumptions.
   - **File copy error** → a path under `files/system/` is wrong.
   - **One variant failed, the other passed** → the fault is in that recipe's own modules,
     not in `common-base.yml`. Both images share those.
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
   - **`test "$(git -C … rev-parse HEAD)" = …` failed** (both variants) → the
     `zsh-completions` tag no longer points at the pinned commit, or the clone failed. The
     assertion is doing its job: check the tag upstream, then update **both** the tag and
     the hash in `common-base.yml`. Do not remove the check. See DD-026.
   - **`sha256sum: WARNING: 1 computed checksum did NOT match`** (both variants) → the
     zellij release artifact is not the one that was pinned. Either the download was
     truncated, or upstream replaced the asset. Re-run first; if it repeats, check the
     release's `.sha256sum` file and update **both** the version and the hash in
     `common-base.yml`. Do not relax the check. See DD-033.
   - **`grep -qF '[CONFIG FILE]: Well defined.'` failed** (both variants) → the KDL in
     `files/system/etc/zellij/config.kdl` does not parse, or zellij did not resolve
     `/etc/zellij` as its config directory. The preceding `zellij setup --check` output is
     in the build log and names the error. See DD-033.
   - **Disk space** → confirm `maximize_build_space: true` is still set. Two images per
     run makes this likelier, but each job gets its own runner.
   - **Signing failure** → `SIGNING_SECRET` missing, malformed, or rotated.
3. Record anything non-obvious: a `plan.md` task if it needs fixing, a `DD-###` record if
   it changes a decision, and a note in the relevant `docs/` page.
