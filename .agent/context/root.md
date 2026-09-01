# Context: repository root

**Covers:** `README.md`, `LICENSE`, `cosign.pub`, `.gitignore`

## Purpose

Public-facing entry point, licence, signing trust anchor, and ignore rules.

## Essential details

- **`README.md`** — the public front page: what Qubix OS is, its three active
  standard/CachyOS/NVIDIA variants, the parked NVIDIA+CachyOS recipe, the two-step install,
  weekly Sunday 00:00 UTC rebuild cadence, automatic and manual artifact-only ISO routes,
  cosign verification, and links into `docs/` and `AGENTS.md`. Keep it short; detail
  belongs in `docs/`.
- **`LICENSE`** — Apache License 2.0, inherited from the BlueBuild template.
- **`cosign.pub`** — the public half of the image signing keypair (DD-008). Users verify
  with `cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild`. Rotating it
  requires updating the `SIGNING_SECRET` repository secret too, and invalidates
  verification for existing installs until they rebase.
- **`.gitignore`** — ignores `cosign.key`, `cosign.private` (**private signing keys, never
  commit**), `/Containerfile` (BlueBuild's generated output), `.DS_Store`, and
  `__pycache__/`.

## Gotchas

- The `.DS_Store` rule matters more than it looks: macOS drops these into
  `files/system/`, and the `files` module would otherwise copy them into the image.
- Same for `__pycache__/`: running `python3 -m py_compile` on the overlay's scripts (the
  local syntax check in [`build-and-release.md`](../../docs/build-and-release.md)) drops
  one next to them, i.e. inside `files/system/usr/bin/`.
- `/Containerfile` is ignored with a leading slash — the *generated* root artifact only.
- Documentation-only edits (including to `README.md`) don't trigger a CI build (DD-010).

## Update when

You change the public description, the licence, or the signing key. A key rotation also
touches `docs/build-and-release.md`, `docs/usage.md`, and the `SIGNING_SECRET` secret.
