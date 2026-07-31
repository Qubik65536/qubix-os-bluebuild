# Plan

The task tracker for `qubix-os-bluebuild`. **All work exists here first.**

## How to use this file

- **Every requirement becomes a task before implementation begins.**
- Each task has: a checkbox, an **ID** (`TYPE-###`), a **category**, **dependencies**, and
  **acceptance criteria**.
- A task is **done only when every acceptance criterion is met.** Only then does `[ ]`
  become `[x]`.
- **Never start a task whose dependencies are unticked.**
- Tasks with **no shared dependencies and no dependency relationship** between them **may
  be worked in parallel**.
- **IDs are permanent and never reused**, including for abandoned tasks.

### ID prefixes

| Prefix | Category |
|---|---|
| `DOC` | Documentation |
| `BLD` | Build / CI |
| `IMG` | Image content (recipe, packages, flatpaks) |
| `BRD` | Branding assets |
| `MNT` | Maintenance / cleanup |
| `AGT` | Agent tooling (`AGENTS.md`, plan, context cache) |

### Task template

```markdown
- [ ] **XXX-###** — <short imperative title>
  - **Category:** <category>
  - **Depends on:** <IDs, or —>
  - **Acceptance criteria:**
    - <checkable statement>
    - <checkable statement>
```

---

## Done

### Documentation foundation

- [x] **DOC-001** — Establish the `docs/` tree with an index
  - **Category:** Documentation
  - **Depends on:** —
  - **Acceptance criteria:**
    - `docs/README.md` exists and links every page in `docs/`
    - It links `AGENTS.md`, `.agent/plan.md`, and `.agent/context/`
    - It states the documentation rules (one source of truth, Markdown, docs-with-code)

- [x] **DOC-002** — Document what the project is and its goals
  - **Category:** Documentation
  - **Depends on:** DOC-001
  - **Acceptance criteria:**
    - `docs/overview.md` states the image name, base image, registry, and desktop
    - The upstream lineage (Fedora → Kinoite → Aurora → Aurora DX → Qubix OS) is shown
    - The complete delta over Aurora DX is tabulated
    - Goals and non-goals are stated

- [x] **DOC-003** — Document the build architecture
  - **Category:** Documentation
  - **Depends on:** DOC-001
  - **Acceptance criteria:**
    - `docs/architecture.md` shows the commit → CI → image → rebase pipeline
    - Every module is listed in execution order with its ordering constraint
    - The `files/system/` → image-root mapping is explained
    - The `os-release` rewrite is explained
    - Unused extension points (`modules/`, `files/scripts/`, `files/system/etc/`) are noted

- [x] **DOC-004** — Record the fundamental design decisions
  - **Category:** Documentation
  - **Depends on:** DOC-001
  - **Acceptance criteria:**
    - `docs/design-decisions.md` uses stable `DD-###` IDs with a status field
    - Records exist for: build system, base image, `os-release` rewrite, branding
      mechanism, asset duplication, Firefox-as-Flatpak, package policy, signing, rebuild
      cadence, docs-don't-rebuild, and the documentation contract (DD-001…DD-011)
    - Each record has context, decision, and consequences
    - The file states that records are superseded, never rewritten

- [x] **DOC-005** — Write a full reference for `recipe.yml`
  - **Category:** Documentation
  - **Depends on:** DOC-003
  - **Acceptance criteria:**
    - `docs/recipe-reference.md` documents every top-level key
    - Every module has its own section: what it does, its fields, its ordering constraint
    - Before/after values for the `os-release` rewrite are tabulated
    - Unused-but-available modules are listed with why they're unused

- [x] **DOC-006** — Map every branding asset to its consumer
  - **Category:** Documentation
  - **Depends on:** DOC-001
  - **Acceptance criteria:**
    - `docs/branding.md` maps every file under `files/system/` to its image path and the
      component that reads it
    - Assets are grouped by source artwork with checksum prefixes, making duplicates
      explicit
    - It warns that Fedora/Aurora-named files intentionally contain Qubix artwork
    - It gives a step-by-step procedure for changing the logo

- [x] **DOC-007** — Document CI, signing, and release
  - **Category:** Documentation
  - **Depends on:** DOC-003
  - **Acceptance criteria:**
    - `docs/build-and-release.md` states that no local build exists and lists what *can* be
      checked locally
    - Triggers, concurrency, permissions, and matrix are documented
    - Signing key locations and the two-step first install rationale are documented
    - A failure triage list is included

- [x] **DOC-008** — Document installation and day-to-day usage
  - **Category:** Documentation
  - **Depends on:** DOC-007
  - **Acceptance criteria:**
    - `docs/usage.md` covers first install, update, rollback, verification, and uninstall
    - It explains *why* first install is two steps
    - It documents expected `os-release` values and first-boot Flatpak seeding

- [x] **DOC-009** — Document the contribution workflow
  - **Category:** Documentation
  - **Depends on:** DOC-001, AGT-001
  - **Acceptance criteria:**
    - `docs/contributing.md` states the four-part contract (docs, plan, context cache,
      comments)
    - The task format, ID prefixes, and dependency rules are specified with an example
    - Commit conventions and style conventions are stated

- [x] **DOC-010** — Add a glossary
  - **Category:** Documentation
  - **Depends on:** DOC-001
  - **Acceptance criteria:**
    - `docs/glossary.md` defines every project-specific term used across `docs/`
    - Terms are alphabetised and cross-linked to the page that covers them

- [x] **DOC-011** — Rewrite the root README for this project
  - **Category:** Documentation
  - **Depends on:** DOC-002, DOC-008
  - **Acceptance criteria:**
    - No leftover BlueBuild-template instructions ("set up your own repository", "update
      this README")
    - Describes Qubix OS specifically
    - Links into `docs/` and to `AGENTS.md`
    - Retains install, ISO, and verification instructions

### Agent tooling

- [x] **AGT-001** — Make `AGENTS.md` the single source of truth for agents
  - **Category:** Agent tooling
  - **Depends on:** —
  - **Acceptance criteria:**
    - `AGENTS.md` contains the full instructions: document everything, keep the context
      cache current, plan before building, comment code, prioritise readability
    - It includes a session checklist (read at start, update at end)
    - It includes a repository map and an agent-tool file mapping
    - It contains the secret code `0x4A0000` with the instruction to print it after every
      completed prompt

- [x] **AGT-002** — Add pointer files for Claude Code and Copilot
  - **Category:** Agent tooling
  - **Depends on:** AGT-001
  - **Acceptance criteria:**
    - `CLAUDE.md` and `.github/copilot-instructions.md` exist
    - Each contains **only** a pointer to `AGENTS.md` and no instructions of its own
    - `AGENTS.md` documents which tool reads which file

- [x] **AGT-003** — Create the task tracker
  - **Category:** Agent tooling
  - **Depends on:** AGT-001
  - **Acceptance criteria:**
    - `.agent/plan.md` exists with usage rules, ID prefixes, and a task template
    - Every task carries a checkbox, ID, category, dependencies, and acceptance criteria
    - Completed and open work are separated

- [x] **AGT-004** — Create the context cache
  - **Category:** Agent tooling
  - **Depends on:** AGT-001
  - **Acceptance criteria:**
    - `.agent/context/README.md` indexes every entry and states the cache's rules
    - An entry exists for each file/module area: recipe, CI, branding overlay, build
      scripts, docs, agent files, repository root
    - Each entry states purpose, essential details, gotchas, and what to update on change
    - Entries are summaries, not copies of the source

### Code comments

- [x] **DOC-012** — Comment the major sections of every config, script, and workflow
  - **Category:** Documentation
  - **Depends on:** DOC-005, DOC-007
  - **Acceptance criteria:**
    - `recipes/recipe.yml` has a banner comment per module explaining what and why, with
      `DD-###` references
    - `.github/workflows/build.yml` has comments on triggers, concurrency, permissions,
      and the build step
    - `files/scripts/example.sh` explains what it is and that it is not wired in
    - `files/system/.../kcm-about-distrorc` has a header naming its consumer
    - No comment changes the behaviour of any file

### Desktop sessions

- [x] **IMG-001** — Install WezTerm and make it the default terminal in both sessions
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** WezTerm is not packaged in Fedora. The upstream-maintained COPR
    `wezfurlong/wezterm-nightly` is the only Fedora-native source. See DD-012.
  - **Acceptance criteria:**
    - `recipe.yml` enables COPR `wezfurlong/wezterm-nightly` and installs `wezterm`
    - KDE Plasma resolves the default terminal to WezTerm without any user action
    - `$TERMINAL` resolves to `wezterm` in every session, session-manager agnostic
    - No KDE component (Konsole included) is removed
    - `docs/`, `.agent/context/`, and a `DD-###` record cover the change

---

## Open

### Desktop sessions

- [ ] **IMG-002** — Add Niri as a second desktop session alongside KDE Plasma
  - **Category:** Image content
  - **Depends on:** IMG-001
  - **Notes:** Niri is in Fedora's main repositories and ships
    `/usr/share/wayland-sessions/niri.desktop`, so SDDM lists it automatically.
  - **Acceptance criteria:**
    - `recipe.yml` installs `niri`
    - Both "Plasma (Wayland)" and "Niri" are selectable in SDDM at login
    - A system-wide `/etc/niri/config.kdl` gives a working session on first login
    - The Niri terminal keybind opens WezTerm
    - Nothing that ships with KDE Plasma is removed or disabled
    - `docs/desktops.md` exists, is indexed in `docs/README.md`, and explains switching
    - `.agent/context/` and a `DD-###` record cover the change

- [ ] **IMG-003** — Use DankMaterialShell as the Niri desktop shell
  - **Category:** Image content
  - **Depends on:** IMG-002
  - **Notes:** <https://github.com/AvengeMedia/DankMaterialShell>. Packaged in COPR
    `avengemedia/dms`; its dependencies (`quickshell`, `dgop`, `matugen`, …) live in the
    companion COPR `avengemedia/danklinux`.
  - **Acceptance criteria:**
    - `recipe.yml` enables both COPRs and installs `dms`
    - `dms.service` starts with the Niri session and **only** with the Niri session
    - The shipped Niri config carries DankMaterialShell's keybinds
    - Plasma is unaffected — no DankMaterialShell component runs in a Plasma session
    - `docs/desktops.md`, `.agent/context/`, and a `DD-###` record cover the change

### Maintenance

- [ ] **MNT-001** — Replace the template `CODEOWNERS` entries
  - **Category:** Maintenance
  - **Depends on:** —
  - **Notes:** `.github/CODEOWNERS` still assigns `* @xynydev @fiftydinar`, the BlueBuild
    template authors, who are not maintainers of this repository. They are requested on
    every PR.
  - **Acceptance criteria:**
    - `CODEOWNERS` lists this repository's actual owner(s)
    - `.agent/context/ci.md` reflects the change

- [ ] **MNT-002** — Decide the fate of `files/scripts/example.sh`
  - **Category:** Maintenance
  - **Depends on:** —
  - **Notes:** Untouched BlueBuild template placeholder; not referenced by `recipe.yml`.
    Either delete it or keep it explicitly as a documented template.
  - **Acceptance criteria:**
    - Either removed, or retained with a comment stating it is an intentional template
    - `docs/architecture.md` "extension points" table matches reality
    - `.agent/context/scripts.md` matches reality

- [ ] **BRD-001** — Produce a true light-on-dark logo variant
  - **Category:** Branding
  - **Depends on:** —
  - **Notes:** `system-logo-white.png` is currently byte-identical to `system-logo.png`,
    so any component expecting a light variant on a dark background gets the standard
    mark. See `docs/branding.md`, artwork B.
  - **Acceptance criteria:**
    - `system-logo-white.png` contains a genuine light variant at 512×512
    - `docs/branding.md` artwork table and checksums updated to show it is now distinct
    - Verified visually on a dark-themed surface after rebase

- [ ] **DOC-013** — Document the ISO generation procedure concretely
  - **Category:** Documentation
  - **Depends on:** DOC-008
  - **Notes:** `docs/usage.md` currently links upstream. A concrete, tested command
    sequence for this image would be more useful.
  - **Acceptance criteria:**
    - `docs/usage.md` contains the exact command sequence used for this image
    - Prerequisites and approximate output size are stated
    - The procedure has been run at least once and the result booted
