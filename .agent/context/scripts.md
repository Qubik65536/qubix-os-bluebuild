# Context: `files/scripts/` and `modules/`

**Covers:** `files/scripts/example.sh`, `modules/`

## Purpose

Unused extension points, kept so the mechanism is available without needing to be
rediscovered.

## Essential details

### `files/scripts/`

Scripts that the BlueBuild `script` module can run **at build time, in CI** — never on a
user's machine.

- `example.sh` — the untouched BlueBuild template placeholder. Prints two lines. **Not
  referenced by `recipe.yml`**, so it never runs. Its fate is open task `MNT-002`.
- Convention for any real script here: `#!/usr/bin/env bash`, then `set -oue pipefail` so a
  failing step fails the build instead of silently producing a broken image.
- To actually run one, add a `script` module to `recipe.yml` listing the filename.

### `modules/`

Where custom BlueBuild modules would live. Currently only `.gitkeep` — nothing custom
exists. Reach for a custom module only when no upstream module fits and the logic is
reused; a one-off belongs in a `containerfile` snippet or a script.

## Gotchas

- A script in `files/scripts/` does nothing unless `recipe.yml` invokes it. Adding the file
  is half the change.
- Build-time only. There is no mechanism here for running code on user machines, and
  adding one would contradict the "stay declarative" goal in `docs/overview.md`.

## Update when

You add a script, wire one into the recipe, or add a custom module. Then also update the
"extension points" table in `docs/architecture.md`.
