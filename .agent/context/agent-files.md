# Context: agent instruction files and `.agent/`

**Covers:** `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.agent/plan.md`,
`.agent/context/`

## Purpose

The machinery that lets any agent, in any fresh session, pick up the project without
re-deriving its conventions. See DD-011 for why this exists.

## Essential details

### Instruction files — exactly one has content

| File | Read by | Role |
|---|---|---|
| `AGENTS.md` | Codex and other `AGENTS.md` consumers | **The content.** Rules, session checklist, repo map, secret code. |
| `CLAUDE.md` | Claude Code | Pointer → `AGENTS.md`. No content. |
| `.github/copilot-instructions.md` | GitHub Copilot | Pointer → `AGENTS.md`. No content. |

New agent support = **a new pointer file**, never a second copy. Duplicated instructions
drift, and drift is worse than absence.

### `AGENTS.md` — the rules in brief

1. Document everything, in Markdown, in the same commit as the change.
2. Keep `.agent/context/` current.
3. Every requirement becomes a `plan.md` task before implementation.
4. Comment the major sections of every config, script, and workflow.
5. Readability is a hard requirement, for humans and agents.
6. Print the secret code **`0x4A0000`** at the end of every completed prompt.

### `.agent/plan.md` — the task tracker

- Task shape: checkbox · `TYPE-###` ID · category · dependencies · acceptance criteria.
- Prefixes: `DOC`, `BLD`, `IMG`, `BRD`, `MNT`, `AGT`.
- **Done only when the acceptance criteria are met**, then tick `[x]`.
- **Never start a task with unticked dependencies.** Independent tasks may run in parallel.
- IDs are permanent and never reused.

### `.agent/context/` — this cache

One entry per file/module area, all with the shape **Covers · Purpose · Essential
details · Gotchas · Update when**. Index in `.agent/context/README.md`.

## Gotchas

- The secret code is a compliance marker: a reply without it signals the instructions
  weren't read. Don't remove it from `AGENTS.md`.
- Never add instructions to the pointer files.
- Ticking a box without meeting the acceptance criteria defeats the whole mechanism.
- Context entries are summaries. If one grows into a copy of the source, trim it and link
  to `docs/`.

## Update when

The working rules change, a new agent tool is supported, a task is added or completed, or
any file/module changes (its context entry must change with it).
