# Context Cache — Index

A **context cache**: one short Markdown entry per file or module, describing what it is
for and the essential details, so an agent (or a returning human) can orient without
reading the whole repository.

## Rules

- **Read** the relevant entry before touching a file.
- **Update** the entry whenever you change the file or module it describes.
- Keep entries **brief** — a summary, not a copy of the source. If an entry starts quoting
  the file at length, trim it and link to `docs/` instead.
- Every entry has the same shape: **Covers · Purpose · Essential details · Gotchas ·
  Update when**.

## Entries

| Entry | Covers |
|---|---|
| [`root.md`](root.md) | Repository root files: `README.md`, `LICENSE`, `cosign.pub`, `.gitignore` |
| [`recipe.md`](recipe.md) | `recipes/recipe.yml` — the image definition |
| [`ci.md`](ci.md) | `.github/` — workflow, dependabot, CODEOWNERS, Copilot pointer |
| [`files-system.md`](files-system.md) | `files/system/**` — the image root overlay (branding + desktop config) |
| [`scripts.md`](scripts.md) | `files/scripts/` and `modules/` — unused extension points |
| [`docs.md`](docs.md) | `docs/**` — the human + agent documentation set |
| [`agent-files.md`](agent-files.md) | `AGENTS.md`, `CLAUDE.md`, pointer files, and `.agent/` itself |

## Quick orientation

The repository builds one thing: a custom Fedora Atomic OCI image, defined by
`recipes/recipe.yml`, built by GitHub Actions via the BlueBuild action, published to GHCR,
and signed with cosign. There is no application code, no test suite, and **no local
build**. Roughly 90% of the non-documentation content is branding assets under
`files/system/`.
