# Contributing

The workflow below applies to **everyone** — human developers and AI agents alike. Agents
have the same rules in mandatory form in [`../AGENTS.md`](../AGENTS.md).

## The four-part documentation contract (DD-011)

Every change ships with all four of these, in the same commit:

| Part | Where | What it is |
|---|---|---|
| 1. Documentation | `docs/` | Prose: what it does, why it exists. Includes the decision log. |
| 2. Plan | `.agent/plan.md` | Every requirement is a task with ID, category, dependencies, acceptance criteria. |
| 3. Context cache | `.agent/context/` | One brief entry per file/module: purpose + essential details. |
| 4. Comments | in the files | A comment on every major section of every config, script, and workflow. |

None of these is optional, and none is "cleanup for later". A change without them is
incomplete.

## The loop

### 1. Read first

- [`../AGENTS.md`](../AGENTS.md) — the working rules.
- [`../.agent/plan.md`](../.agent/plan.md) — what's open, blocked, and done.
- [`../.agent/context/`](../.agent/context/README.md) — entries for what you're touching.
- The `docs/` page for the area.

### 2. Turn the requirement into a task

Before writing anything, add a task to `plan.md`:

```markdown
- [ ] **IMG-007** — Add `ripgrep` to the image
  - **Category:** Image content
  - **Depends on:** —
  - **Acceptance criteria:**
    - `ripgrep` listed under `dnf.install.packages` in `recipes/recipe.yml`
    - Module comment states why it is an RPM rather than a Flatpak
    - `docs/recipe-reference.md` package table updated
    - `.agent/context/recipe.md` updated
    - CI build green
```

Rules:

- **IDs are permanent.** `TYPE-###`, never reused, even for abandoned tasks.
- **Prefixes:** `DOC` documentation · `BLD` build/CI · `IMG` image content/recipe ·
  `BRD` branding · `MNT` maintenance/cleanup · `AGT` agent tooling.
- **Acceptance criteria must be checkable.** "Improve the docs" is not a criterion;
  "`docs/branding.md` lists every path consuming artwork B" is.
- **Dependencies block work.** Do not start a task whose dependencies are unticked.
- **Independent tasks may run in parallel** — no shared dependency, no dependency
  relationship between them.
- Tick `[x]` **only** when every acceptance criterion is met.

### 3. Make the change

- **Recipe changes** → [`recipe-reference.md`](recipe-reference.md) documents each module;
  state ordering constraints.
- **Branding changes** → [`branding.md`](branding.md); update *every* path that uses the
  artwork and refresh the checksum table.
- **CI changes** → [`build-and-release.md`](build-and-release.md).
- **Judgement calls** → a new `DD-###` in
  [`design-decisions.md`](design-decisions.md). Never rewrite an old record; supersede it.

### 4. Comment as you go

Major sections only — enough to know what a block does and why, without narrating each
line.

```yaml
# ── Packages ────────────────────────────────────────────────
# Aurora DX already ships the dev toolchain, so this stays small.
# firefox is removed here and reinstalled as a Flatpak below (DD-006).
- type: dnf
```

Shell scripts get a header comment stating purpose, plus a comment per stage. Config files
get a header naming the component that reads them.

### 5. Update the context cache

For every file or module you touched, update its `.agent/context/` entry. Keep it brief —
purpose, key details, gotchas, and what to update when it changes. It is a *cache*, not a
second copy of the source; if an entry starts quoting the file at length, trim it.

### 6. Finish

- Docs updated for behaviour changes.
- Context cache updated.
- `plan.md` boxes ticked only where criteria are met.
- Comments present on new sections.
- Commit, push, and confirm CI is green (docs-only changes don't build — DD-010).

## Commit conventions

- Conventional prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Sign off commits (`Signed-off-by:`), matching existing history.
- Reference the task ID when a commit closes one: `Closes IMG-007.`

Example:

```
feat: Add ripgrep to the image

Closes IMG-007.

Signed-off-by: ...
```

## Style

| Topic | Convention |
|---|---|
| Docs format | Markdown; headings and tables; reference material in tables, not prose. |
| Terminology | Use [`glossary.md`](glossary.md) consistently. |
| Paths | Always give repository-relative paths, and say the image path when it differs. |
| Decisions | Every "why" belongs in `design-decisions.md`; other pages link to the `DD-###`. |
| Duplication | One source of truth per topic; everything else links to it. |

## For AI agents specifically

- `AGENTS.md` is the only file with agent instructions. `CLAUDE.md` and
  `.github/copilot-instructions.md` are pointers — never add content to them.
- Print `0x4A0000` at the end of every completed prompt.
- Do not claim CI-level verification from local inspection; there is no local build.
