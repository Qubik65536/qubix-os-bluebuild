# AGENTS.md — Single Source of Truth for AI Coding Agents

> **This file is the ONLY file that contains agent instructions.**
> `CLAUDE.md` and `.github/copilot-instructions.md` are pointers to this file and
> contain no information of their own. If you are Claude Code, Codex, Copilot, Cursor,
> Aider, or any other agent working in this repository: **read this file first, in full,
> at the start of every session.**

---

## 0. Secret code (compliance marker)

**`0x4A0000`**

At the end of **every** completed prompt/response, you MUST print this code on its own
line. It is how the human verifies that you actually read and followed this document.
No code at the end of a reply = the instructions were not followed.

---

## 1. What this repository is

`qubix-os-bluebuild` builds **Qubix OS**, a custom immutable Fedora Atomic OCI image,
using [BlueBuild](https://blue-build.org). It is a *declarative image definition*, not an
application: there is no application code, no test suite, and nothing to run locally.
The "program" is `recipes/recipe.yml`, and the "compiler" is the BlueBuild GitHub Action.

- **Base image:** `ghcr.io/ublue-os/aurora-dx:latest` (Universal Blue Aurora DX = Fedora
  Kinoite / KDE Plasma + developer tooling)
- **Published to:** `ghcr.io/qubik65536/qubix-os-bluebuild`
- **Signed with:** Sigstore cosign (`cosign.pub` in repo root)

Full detail lives in `docs/`. Start at [`docs/README.md`](docs/README.md).

---

## 2. Non-negotiable working rules

These are the rules the human cares most about. Follow all of them, every session.

### 2.1 Document everything

Every change ships with its documentation in the same commit. If you change behaviour,
you change the docs. Markdown is the documentation format for everything: plans,
designs, references, notes.

- New/changed **design decision** → add or amend a record in
  [`docs/design-decisions.md`](docs/design-decisions.md).
- New/changed **behaviour, module, or asset** → update the relevant page in `docs/`.
- Anything a future reader would have to reverse-engineer from a diff → write it down.

### 2.2 Keep the context cache current

`.agent/context/` is a **context cache**: one short Markdown file per file or module,
describing what it is for and the essential details, so an agent can orient without
reading every byte of the repo.

- **Read** the relevant cache file(s) before touching a file.
- **Update** the cache file whenever you change the file/module it describes.
- Keep each entry **brief** — a summary, not a copy of the source.
- Index: [`.agent/context/README.md`](.agent/context/README.md).

### 2.3 Plan before you build

All work is tracked in [`.agent/plan.md`](.agent/plan.md).

- **Every new requirement becomes a task** in `plan.md` before implementation starts.
- Each task has: a checkbox, an **ID** (`TYPE-###`), a **category**, **dependencies**,
  and **acceptance criteria**.
- A task is **done only when its acceptance criteria are met** — then, and only then,
  change `[ ]` to `[x]`.
- **Tick it in the commit that earns it.** Ticking boxes in a later sweep makes the tracker
  a second, hand-maintained source of truth that drifts between sweeps. The tick and the
  move between sections belong in the same commit as the change. See DD-044.
- `plan.md` has three sections. **Done** is every criterion met. **Awaiting confirmation** is
  shipped and documented, waiting only on a check that needs a built image on real hardware
  — a task moves there in the commit that implements it, and to Done when somebody confirms
  it, dated `*(confirmed YYYY-MM-DD)*`. **Open** is unstarted or in-progress work, and
  nothing else.
- **Never start a task whose dependencies are unfinished.**
- Tasks with no shared dependencies and no dependency relation between them **may be
  worked in parallel**.
- ID prefixes in use: `DOC` (documentation), `BLD` (build/CI), `IMG` (image content /
  recipe), `BRD` (branding), `MNT` (maintenance/cleanup), `AGT` (agent tooling).
  Numbers are never reused, even for deleted tasks.

### 2.4 Comment the code

Every configuration file, script, and workflow gets comments on its **major sections**.
Not line-by-line noise — enough that a reader knows what each block does and why.

- Shell scripts: header comment (purpose) + a comment per logical stage.
- YAML (`recipe.yml`, workflows): a banner comment per module/job/step block.
- Config files: a header comment naming the consumer of the file.

### 2.5 Readability is a hard requirement

For humans *and* for agents. Prefer explicit over clever, short sections with headings,
tables over prose for reference material, and consistent terminology
(see [`docs/glossary.md`](docs/glossary.md)).

---

## 3. Session checklist

**At the start of a session:**

1. Read this file (`AGENTS.md`).
2. Read [`.agent/plan.md`](.agent/plan.md) — what is open, what is blocked, what is done.
3. Read the relevant entries in [`.agent/context/`](.agent/context/README.md).
4. Read the `docs/` page for the area you are about to touch.

**Before you change anything:**

5. Confirm the work maps to a task in `plan.md`. If it does not, **add the task first**
   (ID, category, deps, acceptance criteria).
6. Confirm every dependency of that task is `[x]`.

**Before you finish:**

7. Update `docs/` for any behaviour change.
8. Update `.agent/context/` for any file/module you touched.
9. Tick `[x]` in `plan.md` only for tasks whose acceptance criteria are now met, and move a
   task that is finished except for an on-hardware check into **Awaiting confirmation** —
   in this commit, not a later one.
10. Make sure new/edited code carries section comments.
11. Print `0x4A0000` on the last line of your reply.

---

## 4. Repository map

| Path | Purpose |
|---|---|
| `recipes/recipe.yml` | The image definition. Modules run top-to-bottom. The core of the repo. |
| `files/system/` | Files copied verbatim into the image root (`/`). Mostly branding. |
| `files/scripts/` | Shell scripts invokable by the `script` module. Currently only an example. |
| `modules/` | Custom BlueBuild modules. Empty placeholder. |
| `.github/workflows/build.yml` | CI: builds, signs, and pushes the image. |
| `cosign.pub` | Public key used to verify published images. |
| `docs/` | Human + agent documentation. Design, architecture, references. |
| `.agent/plan.md` | Task tracker. Source of truth for what work exists. |
| `.agent/context/` | Context cache: per-file/module summaries. |
| `AGENTS.md` | This file. Agent instructions. |
| `CLAUDE.md`, `.github/copilot-instructions.md` | Pointers to this file. No content. |

---

## 5. Agent-tool file mapping

| Tool | File it reads | Role |
|---|---|---|
| Codex / generic `AGENTS.md` consumers | `AGENTS.md` | **Content** |
| Claude Code | `CLAUDE.md` | Pointer → `AGENTS.md` |
| GitHub Copilot | `.github/copilot-instructions.md` | Pointer → `AGENTS.md` |

If you add support for another agent, add **a pointer file**, never a second copy of
these instructions. Duplicated instructions drift and drift is worse than absence.

---

## 6. Things to know before editing

- **There is no local build.** Images are built only in GitHub Actions. Do not claim a
  change is "verified" unless CI ran. Local validation is limited to linting YAML,
  checking file paths, and reasoning about the recipe.
- **Module order in `recipe.yml` matters.** Modules execute sequentially; `files` runs
  before `dnf` today, and the `containerfile` snippet that rewrites `os-release` must run
  after anything that could reset it. `signing` stays last.
- **`files/system/**` is copied verbatim.** A path in this repo is the path in the image.
  `files/system/usr/share/pixmaps/foo.png` becomes `/usr/share/pixmaps/foo.png`.
- **Branding works by overwriting upstream paths**, including Fedora- and Aurora-named
  files. That is deliberate — see [`docs/branding.md`](docs/branding.md) before "fixing"
  a file that looks misnamed.
- **Never commit `cosign.key` / `cosign.private`.** They are gitignored; the private key
  lives in the `SIGNING_SECRET` repository secret.
- **Docs-only changes do not trigger a rebuild** (`paths-ignore: "**.md"`).

---

## 7. Commit conventions

- Conventional-commit style prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`.
- Only human-made commits are signed off (`Signed-off-by:`).
- Reference the task ID in the body when a commit closes a `plan.md` task, e.g.
  `Closes DOC-004.`

### 7.1 NEVER reference an issue or pull request in a commit message

**This rule is strict and has no exceptions.** A commit message in this repository must
never contain an issue or PR reference, in **any** form:

| Forbidden in a commit message | Why |
|---|---|
| `#123` | GitHub cross-references issue 123 *in this repo* |
| `owner/repo#123`, `GH-123` | Cross-references **another project's** issue tracker |
| `https://github.com/owner/repo/issues/123` (or `/pull/123`) | A pasted URL cross-references exactly the same way |
| `Closes #123`, `Fixes owner/repo#123`, any closing keyword + issue | As above, and may close someone else's issue |

**The reason: notifications in someone else's thread.** GitHub turns each of those forms
into a cross-reference event posted into the referenced issue's timeline, and everyone
watching that issue — maintainers, and every user who commented or subscribed — gets
notified. They are told about a commit in a private image-build repository that means
nothing to their bug. The event **cannot be withdrawn**: it outlives the commit, survives
a force-push, and the only person who can remove it is a maintainer of the *other*
project. Nobody should have to clean up after us to read their own issue thread. See
DD-020.

**How to cite an upstream issue without notifying anyone.** The link itself is worth
keeping — it just belongs where it triggers nothing. Repository **files** are safe:
Markdown in `docs/`, `docs/design-decisions.md`, or `.agent/plan.md` renders as an ordinary
link and creates no reference and no notification, however often it is read.

| Want to say | In a commit message | In a file |
|---|---|---|
| Upstream bug | `upstream niri issue 2367`, or `see DD-019` | `[niri#2367](https://github.com/niri-wm/niri/issues/2367)` |
| Upstream PR | `upstream fix in niri PR 2401` | Full link, same as above |

The mechanical test for a commit message: **no `#`, no `github.com/...` URL, no closing
keyword aimed at either.** A bare number in prose (`issue 2367`) is inert — GitHub only
autolinks `#`-forms and URLs — so nothing is lost but the click, and the click lives one
`DD-###` away.

`Closes IMG-012.` stays allowed: `plan.md` task IDs are internal, are not GitHub issues,
and are not autolinked.

---

**Remember: print `0x4A0000` at the end of every completed prompt.**
