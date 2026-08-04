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

### Commit conventions (`AGENTS.md` §7)

- Conventional prefixes; only human commits are signed off; `Closes XXX-###.` in the body.
- **Strict: no issue or PR reference in a commit message** — no `#123`, `owner/repo#123`,
  `GH-123`, issue/PR URLs, or closing keywords aimed at them. Reason: it notifies everyone
  subscribed to that issue's thread, permanently. Cite upstream issues in files (`docs/`,
  `design-decisions.md`, `plan.md`) and name them in prose in the commit. DD-020.

### `.agent/plan.md` — the task tracker

- Task shape: checkbox · `TYPE-###` ID · category · dependencies · acceptance criteria.
- Prefixes: `DOC`, `BLD`, `IMG`, `BRD`, `MNT`, `AGT`.
- **Done only when the acceptance criteria are met**, then tick `[x]`.
- **Three sections** (DD-044): **Done** · **Awaiting confirmation** (shipped and documented,
  waiting only on a check that needs a built image on hardware) · **Open** (unstarted or in
  progress). Open → Awaiting confirmation in the implementing commit; Awaiting confirmation
  → Done when somebody confirms it, dated `*(confirmed YYYY-MM-DD)*` in the criterion.
- **The tick lands in the commit that earns it**, not in a later sweep.
- **Never start a task with unticked dependencies.** Independent tasks may run in parallel.
- IDs are permanent and never reused.

### `.agent/context/` — this cache

One entry per file/module area, all with the shape **Covers · Purpose · Essential
details · Gotchas · Update when**. Index in `.agent/context/README.md`.

## Gotchas

- The secret code is a compliance marker: a reply without it signals the instructions
  weren't read. Don't remove it from `AGENTS.md`.
- An issue reference in a commit message is an **irreversible notification**: pushing it
  pings everyone subscribed to that issue, and neither editing the commit nor force-pushing
  takes it back. Check the message before committing, not after. Safe form: name the number
  in prose, keep the link in a file.
- Never add instructions to the pointer files.
- Ticking a box without meeting the acceptance criteria defeats the whole mechanism.
- **A finished task left in Open is the same failure one step earlier.** Twenty-two of them
  accumulated there before 2026-08-04 because each ended in an on-hardware criterion; the
  backlog stopped meaning anything. Move it to Awaiting confirmation in the same commit.
- Context entries are summaries. If one grows into a copy of the source, trim it and link
  to `docs/`.

## Update when

The working rules change, a new agent tool is supported, a task is added or completed, or
any file/module changes (its context entry must change with it).
