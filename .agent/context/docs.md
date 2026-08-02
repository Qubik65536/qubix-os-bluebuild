# Context: `docs/`

**Covers:** `docs/**`

## Purpose

The prose documentation set, written for humans and agents alike. `docs/` answers *what*
and *why*; `.agent/` answers *what do I need to know right now to touch this file*.

## Essential details

| File | Contents | Read it when |
|---|---|---|
| `README.md` | Index of everything, plus the documentation rules | Starting anywhere |
| `overview.md` | What Qubix OS is, upstream lineage, the full delta over Aurora DX, goals/non-goals | You need the big picture |
| `architecture.md` | Commit → CI → image → rebase pipeline; module order and constraints; the `files/` overlay mapping; unused extension points | Changing how the image is assembled |
| `design-decisions.md` | `DD-001`…`DD-020` — every "why" in the project | Before questioning any convention |
| `recipe-reference.md` | Per-file and per-module reference for `recipes/`, incl. unused-but-available modules | Editing a recipe |
| `variants.md` | The published images (standard, CachyOS kernel), their requirements, how to switch, how the kernel swap works | Adding a variant, or answering "which image should I run?" |
| `desktops.md` | The two sessions (Plasma, Niri), switching, Niri config and keybinds, default terminal, and the "Niri session shows nothing" procedure, which splits a stale panel from a dead compositor from a dead shell (IMG-012) | Touching either desktop session |
| `branding.md` | Asset → image path → consumer map, grouped by source artwork; logo-change procedure | Touching anything under `files/system/` |
| `build-and-release.md` | CI triggers, concurrency, permissions, signing, tags, failure triage | Changing CI or debugging a build |
| `usage.md` | Install, update, rollback, verify, ISO, uninstall | Answering a user-facing question |
| `contributing.md` | The four-part contract, the task workflow, and the commit rules (incl. the no-issue-reference rule, DD-020) | Before making any change |
| `glossary.md` | Project terminology | Writing docs, to stay consistent |

## Gotchas

- **One source of truth per topic.** If two pages would say the same thing, one links to
  the other. `design-decisions.md` owns every "why"; other pages cite `DD-###`.
- **Design decisions are superseded, never rewritten.** Add a new record and mark the old
  one `Superseded by DD-###`.
- Behaviour changes and their documentation go in the **same commit**.
- Docs are Markdown; reference material goes in tables, not prose.

## Update when

Any behaviour changes, or any convention is added or altered. Also update the index table
in `docs/README.md` when adding a page, and this entry when adding or removing a file.
