# Plan

The task tracker for `qubix-os-bluebuild`. **All work exists here first.**

## How to use this file

- **Every requirement becomes a task before implementation begins.**
- Each task has: a checkbox, an **ID** (`TYPE-###`), a **category**, **dependencies**, and
  **acceptance criteria**.
- A task is **done only when every acceptance criterion is met.** Only then does `[ ]`
  become `[x]`.
- **Tick it in the commit that earns it.** A box left `[ ]` after its work has shipped is
  indistinguishable from work nobody has started, so the tick and the move between sections
  belong in the same commit as the change — never in a later sweep.
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

### Sections

| Section | Holds |
|---|---|
| **Done** | Every acceptance criterion met. |
| **Awaiting confirmation** | Shipped, documented, and complete except for a criterion that can only be checked on a built image running on real hardware. |
| **Open** | Not started, or in progress. |

There is no local build (`AGENTS.md` §6), so most image work reaches a last criterion that
nobody can tick from a checkout. That criterion is a **confirmation**, not a task: the work
is finished and the change is in the image. A task therefore moves

- **Open → Awaiting confirmation** in the commit that implements it, and
- **Awaiting confirmation → Done** when the person with the hardware confirms it, with the
  date recorded in the criterion — `*(confirmed YYYY-MM-DD)*`.

Nothing stays in **Open** merely because CI has not run yet.

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

- [x] **AGT-005** — Forbid issue references in commit messages
  - **Category:** Agent tooling
  - **Depends on:** AGT-001
  - **Notes:** `#123`, `owner/repo#123`, and issue/PR URLs in a pushed commit message post
    a cross-reference into the referenced issue's timeline, which **notifies everyone
    subscribed to that thread** about a commit that means nothing to their bug. The event
    cannot be withdrawn — only a maintainer of the other project can hide it. `8a2f0ac`
    already did it to `niri-wm/niri#2367`; history is not rewritten, so the rule applies
    from here on. See DD-020.
  - **Acceptance criteria:**
    - `AGENTS.md` §7 states the rule as non-negotiable, with the forms it covers
    - The stated reason is the notification in the other project's thread, not visibility
    - Every page giving the rule also gives the safe way to cite an upstream issue
    - `.agent/context/agent-files.md` carries it as a gotcha
    - A `DD-###` record covers the mechanism and why `Closes IMG-###.` is unaffected

- [x] **AGT-004** — Create the context cache
  - **Category:** Agent tooling
  - **Depends on:** AGT-001
  - **Acceptance criteria:**
    - `.agent/context/README.md` indexes every entry and states the cache's rules
    - An entry exists for each file/module area: recipe, CI, branding overlay, build
      scripts, docs, agent files, repository root
    - Each entry states purpose, essential details, gotchas, and what to update on change
    - Entries are summaries, not copies of the source

- [x] **AGT-006** — Separate work that is finished from work that is unconfirmed
  - **Category:** Agent tooling
  - **Depends on:** AGT-003
  - **Notes:** Found on 2026-08-04 while auditing the tracker against the commits. Every
    commit since `c55107b` shipped its files, its docs, its `DD-###` and its context entries
    — and left its task `[ ]`, because each ends in a criterion that needs a built image on
    real hardware, which no checkout can satisfy. Twenty-two tasks accumulated in **Open**
    that way, alongside `MNT-001`, which nobody has started. The section that is supposed to
    answer "what should I pick up next?" could not.
    The criterion is right and stays; the *placement* was wrong. Splitting the tracker gives
    a shipped-but-unchecked task somewhere to wait that is not the backlog, and ticking in
    the implementing commit stops the tracker needing a periodic sweep to be true. See
    DD-044.
    All twenty-two were confirmed on the machine on 2026-08-04, so the new section starts
    empty — which is its intended steady state, not a sign it is unused.
  - **Acceptance criteria:**
    - `plan.md` has three sections — Done, Awaiting confirmation, Open — and states what
      each holds and what moves a task between them
    - Every task whose only unmet criterion was an on-hardware check is ticked and dated
      `*(confirmed YYYY-MM-DD)*`, or sits in Awaiting confirmation if it is not
    - **Open contains only unstarted or in-progress work**, verified task by task against
      the tree
    - The rule that the tick lands in the same commit as the work is stated in `AGENTS.md`,
      `plan.md` and `docs/contributing.md`, in one form
    - A `DD-###` records why a criterion nobody can check locally is not grounds for leaving
      finished work in the backlog
    - `.agent/context/agent-files.md` carries the three-section layout

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

- [x] **IMG-002** — Add Niri as a second desktop session alongside KDE Plasma
  - **Category:** Image content
  - **Depends on:** IMG-001
  - **Notes:** Niri is in Fedora's main repositories and ships
    `/usr/share/wayland-sessions/niri.desktop`, so SDDM lists it automatically.
    See DD-013 and DD-014.
  - **Acceptance criteria:**
    - `recipe.yml` installs `niri`
    - Both "Plasma (Wayland)" and "Niri" are selectable in SDDM at login
    - A system-wide `/etc/niri/config.kdl` gives a working session on first login
    - The Niri terminal keybind opens WezTerm
    - Nothing that ships with KDE Plasma is removed or disabled
    - `docs/desktops.md` exists, is indexed in `docs/README.md`, and explains switching
    - `.agent/context/` and a `DD-###` record cover the change

- [x] **IMG-003** — Use DankMaterialShell as the Niri desktop shell
  - **Category:** Image content
  - **Depends on:** IMG-002
  - **Notes:** <https://github.com/AvengeMedia/DankMaterialShell>. Packaged in COPR
    `avengemedia/dms`; its dependencies (`quickshell`, `dgop`, `matugen`, …) live in the
    companion COPR `avengemedia/danklinux`. See DD-015.
  - **Acceptance criteria:**
    - `recipe.yml` enables both COPRs and installs `dms`
    - `dms.service` starts with the Niri session and **only** with the Niri session
    - The shipped Niri config carries DankMaterialShell's keybinds
    - Plasma is unaffected — no DankMaterialShell component runs in a Plasma session
    - `docs/desktops.md`, `.agent/context/`, and a `DD-###` record cover the change

- [x] **IMG-012** — Stop the Xwayland Video Bridge taking over the Niri session
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported 2026-08-01 against the `latest`-based standard image: a Niri login
    showed an empty desktop — no wallpaper, no DankMaterialShell bar, no application
    windows — while niri itself stayed healthy the whole time.
    **Cause, identified by the user on the machine:** `xwaylandvideobridge`, the "Wayland
    to X Recording bridge". It XDG-autostarts, `niri.service` pulls in
    `xdg-desktop-autostart.target`, and the bridge is designed to be invisible but leaves
    that to the compositor — KDE ships a KWin rule, niri has none, so the window just opens
    and takes the session (<https://github.com/niri-wm/niri/issues/2367>).
    Every symptom follows from that, and none of them were display faults: the session
    opened on niri's hotkey-overlay cheatsheet (so niri composited *and* presented), binds
    and DMS's IPC answered throughout, and hammering a keybind or switching workspaces
    brought everything up at once and correct.
    **First fix** was a `window-rule` in `files/system/etc/niri/config.kdl` matching
    `app-id=^xwaylandvideobridge$` — floating, unfocused, non-fullscreen, one pixel, corner,
    zero opacity (DD-019). It stopped the window covering the session, and **was not
    enough**: a hidden window is still a window, so it stayed in niri's toplevel list and
    went on appearing in DankMaterialShell's bar as a running application. Neither end can
    filter it — niri has no `skip-taskbar` equivalent, and DMS's Running Apps widget offers
    app-id substitutions but no exclusion list.
    **Second fix, and the one that settles it:** ship
    `files/system/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop` — upstream's entry
    plus `NotShowIn=niri;` — so the bridge does not autostart here. The window rule stays as
    a second line of defence for a hand-started bridge. DD-021 supersedes DD-019 and records
    the cost: X11 apps cannot capture the screen in the Niri session.
    Dead ends, recorded so they are not re-proposed:
    - **Panel Self Refresh — tested and refuted on the machine.** A window running
      `watch -n0.1 date` updated smoothly; after quitting it and letting the screen go
      quiet, `Mod+T` showed a new WezTerm normally. The panel takes frames from an idle
      screen. **`amdgpu.dcdebugmask=0x10` is not the fix and must not be shipped.**
    - **Quickshell falling back to the `xcb` QPA platform.** `dankgo/shellapp/env.go` sets
      `QT_QPA_PLATFORM=wayland;xcb` only when unset, so it is a real possibility — but it
      costs layer-shell and nothing else, and would not have hidden application windows.
    - **`dms.service` failing to claim `org.freedesktop.Notifications`** (it is `Type=dbus`
      on that name). Same objection: it explains a missing shell, not a missing desktop.
    Established by inspection and still true, worth keeping if the *shell alone* ever goes
    missing:
    - **The layer rule does not hide the bar.** niri's `place_within_backdrop()`
      (`src/layer/mapped.rs`) returns false unless the surface is on the **Background**
      layer *and* ignores the exclusive zone. DMS's bar is `dms:bar` on Top/Overlay, so it
      never matches `^quickshell$`.
    - **The backdrop does not swallow the wallpaper.** `src/niri.rs` renders backdrop layer
      surfaces in the normal path too, beneath the workspaces, so with
      `background-color "transparent"` the wallpaper shows outside the overview. Rule plus
      transparent background is upstream DMS's own documented setup.
    - **The unit wiring is sound.** Fedora's `niri.desktop` runs `niri-session`, which does
      `systemctl --user --wait start niri.service`, so the `/usr/lib/systemd/user/` drop-in
      is evaluated; `Wants=` pulls a *disabled* unit in regardless, and the order resolves
      to niri → `graphical-session.target` → dms.
    - **No environment race.** `niri --session` runs `systemctl --user import-environment`
      and **waits for it** before sending `READY=1`.
  - **Acceptance criteria:**
    - `/etc/niri/config.kdl` carries a window rule that hides `xwaylandvideobridge`, with a
      comment explaining what the bridge is and why it is hidden rather than removed
    - `/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop` stops it autostarting under
      Niri and **only** under Niri — a Plasma login still gets the bridge
    - No KDE package is removed or disabled to achieve either (DD-013 holds)
    - `DD-019`, `DD-021`, `docs/desktops.md`, and `.agent/context/files-system.md` cover the
      change, including what the Niri session loses
    - A Niri login on the rebased image comes up with wallpaper, bar, and working windows,
      and **no bridge in the bar**, on a fresh account, with no per-user setup
      *(confirmed 2026-08-04)*

- [x] **IMG-013** — Give the Xwayland Video Bridge a start/stop control in Niri
  - **Category:** Image content
  - **Depends on:** IMG-012
  - **Notes:** IMG-012 stopped the bridge autostarting under Niri (DD-021), which leaves X11
    screen capture available but only by typing `xwaylandvideobridge` into a terminal. That
    is a poor trade for the person who actually wants to share their screen to Discord.
    One gotcha decides the shape of this. **`pkill xwaylandvideobridge` never matches.**
    `pkill`/`pgrep` match `/proc/PID/comm`, which the kernel truncates to 15 characters;
    the name is 19, so the pattern silently finds nothing. Matching has to be `-f`, against
    the full command line — and a bare `pkill -f xwaylandvideobridge` then matches the
    *shell running the pkill*, because that shell's own command line contains the string.
    `-x -f` with an anchored pattern avoids both traps.
    That logic wants one home rather than being copy-pasted into a keybind and a desktop
    entry, hence a script rather than an inline `spawn-sh`.
  - **Acceptance criteria:**
    - A toggle exists as a niri keybind, and in the application launcher for anyone who
      does not remember keybinds
    - Both entry points run the same command, so the stop half always matches what the
      start half launched
    - It reports what it did through a desktop notification — a keybind has nowhere to
      print to
    - Nothing is added to a Plasma session, where the bridge still autostarts
    - `docs/desktops.md`, DD-021's consequences, and `.agent/context/files-system.md` cover it
    - The script is executable in the built image and the toggle works from both entry
      points *(confirmed 2026-08-04)*

- [x] **BRD-002** — Give the Niri session a theme built from `#56728B`
  - **Category:** Branding
  - **Depends on:** —
  - **Notes:** Requested 2026-08-01. The Niri session currently borrows the logo green
    `#47603b` for its focus ring and pairs it with a neutral grey `#3c3c3c`; everything else
    niri can colour is left at its default. That is one borrowed colour, not a theme.
    `#56728B` is `hsl(208, 24%, 44%)`. Deriving the rest of the palette by holding hue and
    saturation and moving only lightness keeps every surface visibly the same colour, which
    is the whole point of theming from one hex.
    **DMS still wins where it overlaps.** `/etc/niri/config.kdl` ends with
    `include optional=true "~/.config/niri/dms/colors.kdl"`, and niri includes override what
    came before them (DD-015). A user who turns on DankMaterialShell's dynamic theming gets
    matugen's wallpaper-derived colours over the top of this. That is deliberate and stays.
  - **Acceptance criteria:**
    - Every colour niri accepts is set from one derived palette: focus ring, border, shadow,
      tab indicator, insert hint, and the overview backdrop
    - `#56728B` itself is the focused-window colour, not a shade of it
    - The palette is written down with its derivation, so the next colour can be produced
      rather than guessed
    - Features that are off by default — border, shadow — stay off, but are pre-coloured so
      turning them on is one word and still matches
    - `background-color "transparent"` is untouched; DMS's wallpaper still shows through
    - A `DD-###` records the departure from the logo green, and `docs/branding.md` no longer
      implies `#47603b` is the only project colour

### Image variants

- [x] **IMG-004** — Split the recipe into shared module files and per-variant recipes
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Prerequisite for publishing more than one image. BlueBuild's `from-file:`
    includes a module list from another file under `recipes/`. See DD-016.
  - **Acceptance criteria:**
    - The modules every variant shares live in `recipes/common-*.yml`, each a
      `module-list-v1` file with banner comments
    - `recipes/recipe.yml` keeps its identity keys and composes the shared files with
      `from-file:`
    - The rendered module order for `recipe.yml` is unchanged: overlay → packages →
      flatpaks → identity → signing
    - `docs/recipe-reference.md`, `docs/architecture.md`, `.agent/context/recipe.md`, and a
      `DD-###` record cover the new layout

- [x] **IMG-005** — Publish a CachyOS-kernel variant of the image
  - **Category:** Image content
  - **Depends on:** IMG-004
  - **Notes:** CachyOS's own Fedora port lives in COPR `bieszczaders/kernel-cachyos`
    (`kernel-cachyos`, `-lts`, `-rt`, `-server`). The default kernel requires an
    **x86-64-v3** CPU. Swapping the kernel means removing Fedora's and regenerating the
    initramfs. See DD-017.
  - **Acceptance criteria:**
    - `recipes/recipe-cachyos.yml` builds `qubix-os-bluebuild-cachyos` from the same shared
      modules as `recipe.yml`, differing only in the kernel and in `PRETTY_NAME`
    - Fedora's kernel packages are removed and exactly one kernel remains in
      `/usr/lib/modules`, asserted at build time
    - The initramfs is regenerated for the CachyOS kernel
    - `docs/variants.md` exists, is indexed in `docs/README.md`, and states the hardware
      requirement, the Secure Boot caveat, and how to switch between variants
    - `.agent/context/recipe.md` and a `DD-###` record cover the change

- [x] **BLD-001** — Build every image variant from the workflow
  - **Category:** Build / CI
  - **Depends on:** IMG-005
  - **Notes:** The matrix currently names one recipe. It must name every published variant,
    and a manual run should be able to target just one of them.
  - **Acceptance criteria:**
    - The matrix builds `recipe.yml` and `recipe-cachyos.yml`, with `fail-fast: false`
    - `workflow_dispatch` takes a `recipe` input selecting one variant or all of them
    - Each matrix job's name identifies the variant it builds
    - `docs/build-and-release.md` and `.agent/context/ci.md` match the workflow

- [x] **BLD-002** — Temporarily disable NVIDIA+CachyOS publication
  - **Category:** Build / CI
  - **Depends on:** BLD-001, IMG-005
  - **Notes:** Requested 2026-08-31 after repeated Fedora 44 builds failed while compiling
    the NVIDIA Open module against the replacement CachyOS kernel. The combined recipe and
    shared module remain as parked implementation work, but every automatic and manual CI
    selection now excludes the recipe. The plain NVIDIA image remains the supported choice
    for Turing-or-newer NVIDIA hardware while this path is disabled.
  - **Acceptance criteria:**
    - Push, pull-request, schedule, and manual `all` runs select only the standard,
      CachyOS, and NVIDIA recipes
    - `workflow_dispatch` cannot select `recipe-nvidia-cachyos.yml` directly
    - The parked recipe remains in the repository and user-facing documentation clearly
      says that it is neither built nor currently published
    - Build, variant, recipe-reference, design-decision, and context-cache documentation
      reflects the three active images and the parked combined recipe
    - Workflow and recipe YAML parse locally, and the active selector contains exactly
      the three intended recipe filenames *(checked 2026-08-31)*

- [x] **BLD-003** — Build installable ISOs as GitHub Actions artifacts
  - **Category:** Build / CI
  - **Depends on:** DOC-007, BLD-001
  - **Notes:** Requested 2026-08-31. This established the manual, separate ISO workflow;
    BLD-005 later adds automatic generation after successful image publication.
    Actionlint, YAML parsing, shell parsing, the pinned upstream input contract, the current
    Fedora 44 image label, live cosign verification plus digest extraction, and the upstream
    commit-tagged builder container were checked locally on 2026-08-31. A hosted ISO build
    remains the operational verification.
  - **Acceptance criteria:**
    - A manually dispatched workflow builds an x86_64 Kinoite installer for any active
      Qubix image variant and an explicitly selected published image tag
    - The workflow uses `JasonN3/build-container-installer` at a fixed released revision,
      verifies the selected source with `cosign.pub`, pins that digest for the ISO payload,
      and configures signed future updates through the image's embedded policy
    - The ISO and its generated checksum are uploaded together as a GitHub Actions artifact
      with no GitHub Release or other publication step
    - Workflow inputs, retention, Fedora-version alignment, download steps, and failure
      triage are documented in `docs/`, the root README, and `.agent/context/`
    - The workflow parses as YAML and its action inputs match the pinned upstream action

- [x] **BLD-004** — Reduce scheduled image builds to weekly
  - **Category:** Build / CI
  - **Depends on:** BLD-001
  - **Notes:** Requested 2026-08-31. Only the timer-based build changes; push, pull-request,
    and manual dispatch triggers remain available.
  - **Acceptance criteria:**
    - The image workflow schedule is `00 00 * * 0` (Sunday at 00:00 UTC)
    - Push, pull-request, and manual dispatch behaviour is unchanged
    - Build documentation, the design-decision record, and context cache state the weekly
      cadence consistently
    - Workflow YAML parses locally and the configured cron has exactly the intended value

- [x] **BLD-005** — Build ISO artifacts after successful image publication
  - **Category:** Build / CI
  - **Depends on:** BLD-003, BLD-004
  - **Notes:** Requested 2026-08-31. Automatic generation is guarded to a successful,
    non-PR, default-branch `bluebuild` completion. Actionlint, YAML parsing, shell parsing,
    and both automatic/manual selector outputs were checked locally on 2026-08-31.
  - **Acceptance criteria:**
    - Completion of a successful `bluebuild` workflow on the default branch automatically
      starts the ISO workflow
    - An automatic run builds standard, CachyOS, and NVIDIA ISO artifacts from `latest`,
      with one variant failure not cancelling the other variants
    - Failed, cancelled, pull-request, and non-default-branch image runs do not build ISOs
    - Manual dispatch still builds one selected active variant from an explicit tag
    - Workflow comments, build/usage documentation, context cache, and a `DD-###` record
      describe the trigger relationship and artifact-storage consequence
    - Workflow YAML, expressions, and shell blocks pass local validation

- [x] **BLD-006** — Upload installer ISOs to Microsoft 365 OneDrive
  - **Category:** Build / CI
  - **Depends on:** BLD-005
  - **Notes:** Requested 2026-09-01 because the generated ISOs are too large for the
    repository's GitHub Actions artifact path. OneDrive becomes the media store; this is
    not a second copy after artifact upload. Workflow/action YAML, Bash syntax, executable
    mode, the 50 MiB/320 KiB chunk invariant, required-input failure, stale artifact
    references, and whitespace were checked locally on 2026-09-01. A configured hosted run
    remains the external integration check.
  - **Acceptance criteria:**
    - The ISO job uploads each ISO and its checksum directly to a configured Microsoft 365
      work/school OneDrive without first storing the ISO as a GitHub Actions artifact
    - Authentication uses a GitHub OIDC federated credential and keeps no Microsoft client
      secret in the repository or Actions configuration
    - Large files use resumable Microsoft Graph upload sessions with valid sequential chunk
      boundaries and fail closed on an incomplete transfer
    - Each variant has version directories containing one ISO/checksum pair, and retention
      permanently removes all but the three newest complete versions only after the new pair
      succeeds
    - Workflow configuration, Entra/OneDrive setup, retention semantics, failure triage,
      `DD-058`, and `.agent/context/` are documented
    - The workflow parses as YAML and the local action/script pass available static checks

- [x] **BLD-007** — Split ISO retention by originating build trigger
  - **Category:** Build / CI
  - **Depends on:** BLD-006
  - **Notes:** Requested 2026-09-01. Scheduled image builds and push image builds do not
    evict one another. The existing chain also accepts successful manually dispatched
    `bluebuild` runs, and `iso.yml` itself has a manual dispatch route; both count against
    the push/ad-hoc pool so no third unbounded retention class is introduced. YAML/Bash,
    all four supported selector paths, unknown-event rejection, action input wiring,
    global concurrency, channel validation, chunk alignment, whitespace, and the storage
    arithmetic were checked locally on 2026-09-01.
  - **Acceptance criteria:**
    - ISO selection maps an upstream `schedule` event to retention channel `scheduled`
      with three versions, and an upstream `push` event to channel `push` with five
    - Both manual ISO routes use the five-version `push` channel and unknown upstream event
      types fail closed
    - OneDrive stores and purges complete versions independently below
      `<variant>/scheduled/` and `<variant>/push/`
    - ISO workflow runs are globally serialized so concurrent staging uploads cannot make
      the documented maximum storage requirement unbounded
    - Documentation states the steady-state and peak storage calculation for 8 GB ISOs,
      and `DD-059` plus `.agent/context/` record the trigger and manual-run policy
    - Workflow/action YAML and Bash pass the available static checks

- [x] **BLD-008** — Publish discoverable GitHub releases for OneDrive-hosted ISOs
  - **Category:** Build / CI
  - **Depends on:** BLD-006, BLD-007
  - **Notes:** Requested 2026-09-01. YAML and Bash syntax, executable modes, all four
    source-event mappings, unsupported-event rejection, action output wiring, scheduled
    versus prerelease request bodies, literal-checksum placement, count/age cleanup
    targeting, cleanup lookup failure safety, pinned installer checksum format, and
    whitespace were checked locally on 2026-09-01. CI with the configured GitHub and
    Microsoft tenant remains the external integration check.
  - **Acceptance criteria:**
    - Every successfully uploaded ISO gets a per-variant GitHub Release with durable
      OneDrive links for the ISO and checksum, and the literal SHA-256 appears beside the
      ISO link
    - Release notes record the variant, Fedora release, architecture, source image digest,
      source trigger and commit, workflow run, file size, verification command, and the
      applicable retention policy
    - Scheduled ISO builds publish normal releases; push and either manual route publish
      prereleases
    - GitHub release/tag removal follows versions purged by OneDrive's three-scheduled and
      five-push limits, and generated ISO releases older than three calendar months are
      purged on a best-effort basis
    - Workflow permissions, OneDrive anonymous-link requirements, cleanup limitations,
      user documentation, design decision, and context cache are current
    - Workflow/action YAML, shell syntax, release-body rendering, trigger classification,
      retention mapping, and whitespace checks pass locally; CI remains the external
      verification for GitHub and Microsoft APIs

- [x] **IMG-008** — Make the CachyOS kernel swap actually build
  - **Category:** Image content
  - **Depends on:** IMG-005
  - **Notes:** First CI run of `recipe-cachyos.yml` failed. `kernel-cachyos-core`'s
    `%posttrans` runs `kernel-install`, which on a ublue base is hooked by
    `/usr/lib/kernel/install.d/05-rpmostree.install` → `dracut`, and dracut aborts with
    `modules.dep is missing. Did you run depmod?`. The CachyOS RPMs ship no `modules.dep`
    and nothing runs `depmod` in a container build. The transaction's scriptlet failure
    fails the whole build.
    The removal also took 11 unrelated packages with it — the libguestfs/virt-v2v stack,
    `virtualbox-guest-additions`, `kernel-devel-matched`, and the `kmod-*` packages.
  - **Acceptance criteria:**
    - The kernel install does not run the failing `kernel-install` hook
    - `modules.dep` exists for the new kernel before the `initramfs` module runs, asserted
      at build time
    - Packages removed as collateral are restored where the CachyOS kernel satisfies their
      dependencies; the build log lists everything the removal took
    - `docs/variants.md`, `docs/build-and-release.md`, DD-017 and `.agent/context/recipe.md`
      record the mechanism and what is not restorable

- [x] **DOC-014** — Document enabling Secure Boot on the CachyOS variant
  - **Category:** Documentation
  - **Depends on:** IMG-008
  - **Notes:** `docs/variants.md` currently says only "turn Secure Boot off". Verified
    against the published RPM: the CachyOS `vmlinuz` has **no PE certificate table** and
    the spec contains no signing step, so there is no CachyOS key to enrol — the kernel
    has to be signed with a key the user owns. `CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT` and
    `CONFIG_MODULE_SIG_FORCE` are both unset, so Secure Boot does not put this kernel into
    lockdown.
  - **Acceptance criteria:**
    - `docs/variants.md` has a Secure Boot section with the complete MOK procedure:
      generate, enrol, sign, verify
    - It states that signing must be repeated after every update, and what to do when it
      is forgotten
    - The tools the procedure needs are present on the variant, not left to the user to
      layer
    - DD-017 records why the kernel is unsigned and what the durable alternative is

### Boot regressions

- [x] **IMG-011** — Move the base image from the `beta` channel to `latest`
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported 2026-07-31: on an AMD ThinkPad T14, the standard image reaches the
    Plymouth spinner and then goes blank, with no login screen.
    Diagnosed as far as the hardware allows. Established on the machine:
    - The kernel and console are fine — from a text console,
      `systemctl start plasmalogin.service` blanks the screen on demand, and stopping it
      does not give the console back. The greeter's compositor **hangs holding the DRM
      master** rather than crashing, which is why nothing is logged, `Ctrl+Alt+F2` does
      nothing, and `Ctrl+Alt+Del` still reboots.
    - The same image booted to a working desktop a month earlier and ran for ~50 minutes,
      so this is a regression that arrived with an update, not a broken recipe.
    - Nothing in this repository is implicated. It configures no display manager, no PAM,
      no Plymouth theme beyond a watermark, and no graphics settings. `dms` was the one
      plausible route — `plasmalogin` runs its greeter as a systemd user session, so a
      globally enabled `dms.service` would start inside it — and
      `systemctl --user --global is-enabled dms.service` returns `disabled` on the machine.
    That leaves the base image. `beta` tracks the *next* Fedora, so the machine is running a
    pre-release kernel and Mesa that most AMD users are not, and an `amdgpu` display hang on
    a compositor's first frame is exactly the class of regression that channel carries.
    **This is a probable fix, not a proven one** — no kernel log was recovered, because the
    failing boots die before the journal is flushed. It is one line, and rebasing is
    reversible, which is why it is worth trying before anything more invasive.
  - **Acceptance criteria:**
    - Both recipes build from `image-version: latest`
    - DD-002 is superseded, not rewritten, by a record explaining the trade that changed
    - `docs/`, `README.md`, `AGENTS.md`, and `.agent/context/recipe.md` no longer describe
      the project as tracking `beta`
    - The user confirms the rebased image reaches a login screen *(confirmed 2026-08-01)* —
      the machine now boots to the greeter and logs in

### Build assertions

- [x] **MNT-003** — Make the `! grep` assertions able to fail
  - **Category:** Maintenance
  - **Depends on:** —
  - **Notes:** Found on 2026-08-03 while rehearsing IMG-025's snippet locally: the
    double-append guard did not fire on a second run. **`set -e` is specified to ignore a
    command whose exit status is inverted with `!`**, so `! grep -q pattern file` does not
    fail a build when the pattern *is* found. It reads like an assertion and asserts
    nothing.
    One instance already shipped: `! grep -q 'scheme was not found'` in the WezTerm font
    check (DD-034), which was meant to catch a renamed colour scheme and could never have.
    Both are now `if grep -q …; then echo …; exit 1; fi`, which fails and says why.
  - **Acceptance criteria:**
    - No `! <command>` is used as an assertion in `recipes/`
    - Each replacement prints what failed before exiting non-zero
    - Rehearsed locally: the guard exits 1 when its pattern is present *(done — the append
      snippet was run twice against Fedora's real `/etc/zshrc`, and the second run exits 1)*
    - The trap is written down where the next assertion will be added

### Applications

- [x] **IMG-014** — Make Ungoogled Chromium the default browser and drop Firefox
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Requested 2026-08-01. DD-006 chose *Flatpak over RPM* and left *which
    browser* unanswered — Firefox was inherited from Aurora, not chosen. It also left the
    association unset: `default-flatpaks` installs, it does not claim MIME types, so the
    default browser was whatever the desktop resolved first.
    Two mechanisms are needed, not one. `/etc/xdg/mimeapps.list` covers `xdg-open`, GIO and
    KIO; KDE's `OpenUrlJob` additionally checks `kdeglobals [General] BrowserApplication`
    **before** the associations, so KDE would otherwise be free to disagree with everything
    else. Both are fragments — per-type resolution and per-key merging respectively — so
    only the web types are claimed and `~/.config/mimeapps.list` still wins.
    Flathub ID verified against the Flathub API: `io.github.ungoogled_software.ungoogled_chromium`,
    desktop ID `io.github.ungoogled_software.ungoogled_chromium.desktop`. The v2
    `default-flatpaks` module validates IDs at build time, so a typo fails the build.
    **The one thing this cannot do:** v2 has no `remove:` key (v1 did), so the Firefox
    Flatpak stays on machines that already have it. Documented as a one-line manual
    uninstall in `docs/usage.md`; fresh installs are unaffected. See DD-023.
  - **Acceptance criteria:**
    - `common-base.yml` seeds `io.github.ungoogled_software.ungoogled_chromium` and no
      Firefox in any form; the `firefox`/`firefox-langpacks` RPM removal stays
    - `/etc/xdg/mimeapps.list` claims `http`, `https`, `about`, `unknown`, `text/html` and
      `application/xhtml+xml`, and **only** those — PDFs and images keep their viewers
    - `/etc/xdg/kdeglobals` sets `BrowserApplication` to the same desktop ID
    - A user's own choice in *Default Applications* still overrides both
    - DD-006 is superseded, not rewritten; `docs/desktops.md`, `docs/usage.md`,
      `docs/overview.md`, `docs/architecture.md`, `docs/recipe-reference.md`, `README.md`
      and `.agent/context/` cover the change, including the manual uninstall on rebase
    - On the rebased image, a link clicked in each session opens Ungoogled Chromium on a
      fresh account with no per-user setup *(confirmed 2026-08-04)*

- [x] **BRD-003** — Pin the built-in panel to scale 1
  - **Category:** Branding
  - **Depends on:** —
  - **Notes:** Requested 2026-08-01: the Niri session comes up at **1.25** on the laptop
    panel and should be **1**. That 1.25 is niri's own guess — with `scale` unset it derives
    one from the output's physical size and resolution, which on a ~14" 1920×1200 panel
    lands on 1.25.
    **Niri has no global scale setting.** `output` blocks match a connector name, or a
    manufacturer/model/serial triple; there is no wildcard and no default block. So the only
    way to say this in a shipped config is to name a connector, and the name for a laptop's
    built-in panel is conventionally `eDP-1`.
    That has a cost worth stating plainly: it applies to **every** machine running this
    image, including one with a genuinely HiDPI built-in panel, where niri's guess would
    have been right and a forced `scale 1` gives unreadably small text. External monitors
    are untouched and keep the automatic guess.
  - **Acceptance criteria:**
    - `/etc/niri/config.kdl` sets `scale 1` on the built-in panel and nothing else
    - The block says which connector it names and how to change or extend it, so a machine
      whose panel is not `eDP-1` is a one-line fix rather than a mystery
    - A `DD-###` records that this overrides an automatic value image-wide, and what that
      costs on HiDPI hardware
    - `docs/desktops.md` and `.agent/context/files-system.md` cover it

- [x] **BRD-004** — Make the theme apply by default and survive every rebase
  - **Category:** Branding
  - **Depends on:** BRD-002
  - **Notes:** BRD-002 defined the palette; it did not make it *arrive*. Two gaps, one per
    half of the session.
    **niri.** Niri prefers `~/.config/niri/config.kdl` and ignores `/etc/niri/config.kdl`
    entirely once it exists. Anyone who copied the system config to customise it — which
    `docs/desktops.md` told them to do — silently stopped receiving every system change,
    theme included. Niri's `include` is top-level only, but **included files are watched**,
    so splitting the palette into `/etc/niri/qubix-theme.kdl` lets a personal config keep
    tracking the image with one line.
    **DankMaterialShell.** It stores settings per user in
    `~/.config/DankMaterialShell/settings.json`, has no system-wide default, no
    `$XDG_CONFIG_DIRS` search, and its `theme` IPC target only switches light/dark. So an
    image cannot ship a chosen theme — only put one where a user's settings can point at
    it. Verified in its `Theme.qml`: `currentThemeName` and `currentThemeCategory` must be
    the literal `"custom"`, and `customThemeFile` is loaded through a **watched** FileView.
    That last detail is what makes this durable: keep the palette in `/usr` and seed only
    the *pointer*, and a rebase that changes the colours reloads live with nothing re-run.
  - **Acceptance criteria:**
    - The niri palette lives in its own file, included by the system config, and the file
      says how a personal config should include it
    - The DMS palette ships in `/usr` and is byte-for-byte the same colours as the niri one
    - A user service points DMS at it before `dms.service` starts, on every Niri session,
      and is scoped to Niri exactly as `dms.service` is
    - The seeder preserves unrelated settings, is idempotent, and **never** overwrites a
      `settings.json` it cannot parse
    - There is a one-command opt-out, documented
    - Every text pair in the DMS palette clears WCAG AA (4.5:1)
    - `docs/desktops.md`, a `DD-###`, and `.agent/context/files-system.md` cover it

### Terminal environment

- [x] **IMG-015** — Ship a configured interactive shell: zsh, starship, atuin, bat, yazi
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Requested 2026-08-02. `starship` has been installed since DD-007 and **never
    initialised** — no shell in the image ever ran `starship init`, so the prompt has been
    dead weight. This task makes it real and adds the rest of the terminal environment
    around it.
    **Where the wiring goes was the whole design problem.** Four candidate hooks, three of
    them traps:
    - **`/etc/profile.d/*.sh` for the interactive half.** Verified against Fedora's
      `zshrc.rhs`: zsh sources those files from inside `_src_etc_profile_d()`, which runs
      `emulate -L ksh`. `KSH_ARRAYS` and `SH_WORD_SPLIT` are active for anything sourced
      there, which is precisely the environment zsh plugin scripts are not written for.
      Env vars only.
    - **Replacing `/etc/zshrc`.** It carries real behaviour — the `/etc/profile.d` loop
      itself — that we would have to reproduce and keep in sync forever. Getting it subtly
      wrong silently stops every `profile.d` script under zsh.
    - **Replacing `/etc/zshenv`** (Fedora's is comments only, so nothing is lost). Rejected
      for ordering, not for safety: it runs **before** `~/.zshrc`, and
      zsh-syntax-highlighting must be sourced *after* every `zle -N` and after `compinit`
      (upstream `INSTALL.md`: "must be the last plugin sourced").
    - **A `source` line at the end of each user's `~/.zshrc`** — where upstream says to put
      it. Chosen. The line is a *pointer*: the content lives in `/usr` and a rebase changes
      it with nothing re-run, exactly as DD-025 does for the theme. Bash needs no such edit
      — Fedora's `~/.bashrc` already loops over `~/.bashrc.d/`.
    Package facts established against the f43/f44 repos rather than assumed:
    - `zsh-completions` is **not packaged by Fedora**, and the `@zsh-users/zsh-completions`
      COPR has no chroots at all. It is installed from a pinned upstream tag, verified by
      commit hash.
    - `yazi` is not in Fedora either; COPR `lihaohong/yazi` builds it for f43 and f44.
    - **atuin's bash integration needs `bash-preexec`, which Fedora does not package.** So
      atuin is wired into zsh only, and that asymmetry is documented rather than papered
      over.
    - `atuin`, `bat`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `fzf`, `ripgrep`,
      `fd-find` are all in the main repos.
    "Fully local" for atuin is mostly its default — nothing syncs without an account — so
    the shipped config states it explicitly (`auto_sync`, `update_check` off) rather than
    relying on a default that could change.
  - **Acceptance criteria:**
    - `zsh`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `atuin`, `bat` and `yazi` are
      installed, and `zsh-completions` lands on `$fpath` from a version-pinned source
    - Starship renders the shipped prompt with no per-user setup, and
      `~/.config/starship.toml` still overrides it if the user creates one
    - The zsh plugins load in an order that satisfies both upstreams: `compinit` → atuin →
      starship → autosuggestions → syntax highlighting **last**
    - atuin contacts no network: no account, no sync, no update check
    - `cat` resolves to `bat` in interactive shells and still behaves like `cat` when piped
    - `y` runs yazi and leaves the shell in the directory it was quit from
    - Bash gets everything that works in bash; what does not work in bash is documented,
      not silently missing
    - **Superseded by IMG-019, then by IMG-025:** nothing is written into `$HOME` at all —
      the shell is wired from the end of `/etc/zshrc` and from `/etc/profile.d`, both
      shipped in the image. IMG-019 used `/etc/zshenv`, which runs too early
    - `docs/shell.md`, a `DD-###`, `.agent/context/`, and `docs/recipe-reference.md` cover it
    - On the rebased image a fresh login gets the prompt, history search, and both plugins
      *(confirmed 2026-08-04)*

- [x] **IMG-016** — Ship Neovim with LazyVim, owned by the user
  - **Category:** Image content
  - **Depends on:** IMG-015
  - **Notes:** Requested 2026-08-02, with the explicit requirement that **edits to the
    config persist**. That rules out the obvious immutable-image approach. Neovim does read
    a system config — `$XDG_CONFIG_DIRS/nvim` — but LazyVim writes into its config
    directory (`lazy-lock.json`), so a read-only `/etc/xdg/nvim` would be broken from the
    first `:Lazy update`, and a config in `/usr` would be reset by every rebase anyway.
    So `~/.config/nvim` is the user's, seeded **once** from a vendored copy of the LazyVim
    starter and never touched again. This is the one place where seeding contents rather
    than a pointer is right: the whole point is that the user edits them.
    The starter is vendored into the overlay rather than cloned at build time, so the image
    contains no build-time dependency on GitHub being up, and the seed is reviewable in a
    diff. `lazy.nvim` itself still clones on first launch — that is LazyVim's bootstrap and
    needs network the first time `nvim` runs.
  - **Acceptance criteria:**
    - `neovim` is installed with the tools LazyVim's default keymaps actually shell out to
    - **Superseded by IMG-019:** `~/.config/nvim` is not seeded at all. It is the user's
      from the moment they create it, which is what "never overwritten" was protecting
    - Nerd Font glyphs render in the default terminal without per-user font configuration
    - `docs/shell.md`, a `DD-###`, and `.agent/context/` cover it, including what first
      launch needs the network for
    - On the rebased image, `nvim` starts LazyVim, installs its plugins, and an edit to
      `~/.config/nvim` survives the next rebase *(confirmed 2026-08-04)*

- [x] **IMG-017** — Make zsh the login shell
  - **Category:** Image content
  - **Depends on:** IMG-015
  - **Notes:** Requested 2026-08-02, reversing the position IMG-015 took. The login shell is
    a field in `/etc/passwd`, per account, and **no image can set it for an account that
    already exists** — which on a personal machine is the only account that matters. So it
    has to be changed on the machine, by something running as root.
    `/etc/default/useradd` was considered and is not enough on its own: it only affects
    accounts created *later*, and it means replacing a `%config(noreplace)` file owned by
    shadow-utils for a case that will rarely happen again.
    Two details decide the shape:
    - **Ordering.** `usermod` on a logged-in account is a fight nobody needs, so the unit
      runs `Before=systemd-user-sessions.service` — the gate that permits logins at all.
      Nobody is logged in when it runs.
    - **Consent.** It flips an account **once, ever**, stamped in `/var/lib/qubix-os/`, and
      only from bash — the inherited default. An account already on fish, or one that has
      been moved back to bash on purpose, is stamped and never touched again. Anything else
      is an image that overrules its owner every boot.
    `chsh` (as opposed to `usermod`) validates against `/etc/shells`, so the build asserts
    that zsh's `%post` actually registered itself there — otherwise the documented manual
    command fails with a confusing error.
  - **Acceptance criteria:**
    - **Superseded by IMG-019, and reinstated by IMG-024:** IMG-019 replaced the service
      with one documented `chsh`, which Aurora deletes from the image, so the service is
      back — this task's original position was right for the wrong reason
    - `/usr/bin/zsh` is present in `/etc/shells`, asserted at build time so `chsh` works
    - DD-026's "not the default shell" consequence is superseded, not rewritten; the recipe
      comments, `docs/shell.md`, `docs/usage.md` and `.agent/context/` no longer say the
      opposite
    - On the rebased image, a login lands in zsh with the prompt and plugins
      *(confirmed 2026-08-04)*

- [x] **IMG-018** — Make the seeded Neovim config updatable from upstream
  - **Category:** Image content
  - **Depends on:** IMG-016
  - **Notes:** Requested 2026-08-02. IMG-016 seeded the starter as **plain files**, so the
    two halves of a LazyVim installation updated very differently:
    - **LazyVim itself and every plugin** live in `~/.local/share/nvim/lazy/` and already
      update with `:Lazy update`. That half was never a problem.
    - **The starter config** in `~/.config/nvim` was a dead copy. When upstream changes
      `lua/config/lazy.lua` — as it has, for the `rocks` and `vim.uv` bootstraps — there
      was no way to receive it short of diffing by hand against `/usr/share`.
    Fix: seed it as a **git clone of `LazyVim/starter`**, so `git pull` is the answer and
    the user's own edits are commits on top. Network at first login is not a new
    requirement — LazyVim's own bootstrap clones `lazy.nvim` and ~40 plugins the first time
    `nvim` starts, so a config seeded offline could not have worked anyway.
    The vendored copy stays as the offline fallback, but it is now byte-identical to
    upstream (the Qubix header moves out of `init.lua` into a separate `QUBIX.md`), and the
    fallback path initialises a repo with upstream as its remote. That history is unrelated
    to upstream's, which is a real wart and is documented rather than hidden.
  - **Acceptance criteria:**
    - `~/.config/nvim` is a git repository tracking `LazyVim/starter`, so
      `git -C ~/.config/nvim pull` updates the config
    - **Superseded by IMG-019:** the clone is a documented one-line command rather than
      something the image runs, so there is no fallback path and no vendored tree
    - Both update paths — `:Lazy update` for plugins, `git pull` for the config — are
      documented, along with what to do after an OS rebase bumps Neovim
    - DD-027 is superseded, not rewritten
    - On the rebased image, `git -C ~/.config/nvim pull` and `:Lazy update` both work
      *(confirmed 2026-08-04)*

- [x] **IMG-019** — Replace the runtime seeders with plain system files
  - **Category:** Image content
  - **Depends on:** IMG-015, IMG-016, IMG-017, IMG-018
  - **Notes:** Requested 2026-08-02. IMG-015 through IMG-018 grew two Python scripts, two
    systemd units, two `.wants` symlinks, stamp directories and a clone-with-fallback, to
    deliver what is ultimately a handful of configuration files. Judged too complicated for
    what it buys, and removed.
    What made the machinery look necessary was one true constraint — **`/etc/profile.d`
    cannot carry the zsh half**, because Fedora's `/etc/zshrc` sources those files under
    `emulate -L ksh` — plus one assumption that turned out to be false: that reaching zsh
    therefore meant writing into `~/.zshrc`. **`/etc/zshenv` is comments-only in Fedora**,
    so replacing it costs nothing, is plain zsh at top level, and reaches every account
    including ones that already exist. The seeder existed to avoid a file replacement that
    replaces nothing.
    The other three fell out once that was settled:
    - **atuin** reads every setting from the environment —
      `Environment::with_prefix("atuin")` with `__` as the nesting separator, verified in
      its `settings.rs`, so `ATUIN_AUTO_SYNC` is the `auto_sync` key. No per-user file to
      seed. The environment is applied *after* the config file, so the block is guarded on
      the user having none of their own; otherwise it would override them.
    - **The login shell** keeps the one honest limit: `/etc/passwd` is per machine.
      `/etc/default/useradd` covers accounts created from now on, and an account that
      already exists takes one `chsh`. That was the position before IMG-017 and it is the
      right one — a boot-time service editing `/etc/passwd` is a large hammer for a command
      the owner runs once.
    - **Neovim** is a `git clone` of LazyVim's starter, which is what LazyVim's own
      install instructions say, and it is what made `git pull` work in IMG-018. Running it
      is one line the user types instead of two hundred in the image.
  - **Acceptance criteria:**
    - `qubix-seed-home` and `qubix-default-shell`, their units and their `.wants` symlinks
      are gone, and nothing in the image writes to `$HOME` or `/etc/passwd` at runtime
      — **`qubix-default-shell` and its unit return in IMG-024**, because the `chsh` this
      criterion traded them for does not exist on Aurora. Nothing writing to `$HOME` stands
    - zsh still gets the full set on an existing account, with no per-user file
    - atuin is still fully local, and a user's own `config.toml` still wins
    - The vendored LazyVim starter is gone; `docs/shell.md` gives the clone command
    - DD-026's delivery mechanism, DD-028 and DD-029 are superseded, not rewritten
    - Every page that described the seeders no longer does
    - On the rebased image a login gets prompt, plugins and history with nothing seeded
      *(confirmed 2026-08-04)*

- [x] **IMG-020** — Ship fastfetch with the oxocarbon box config
  - **Category:** Image content
  - **Depends on:** IMG-015
  - **Notes:** Requested 2026-08-02: install fastfetch and ship the config the user already
    runs on macOS (`~/.config/fastfetch/`, config plus its `retune.sh`).
    **Where it goes needed checking, not guessing.** fastfetch's config search path is built
    in `FFPlatform_unix.c`: `$XDG_CONFIG_HOME` → `~/.config` → `$HOME` → `$XDG_CONFIG_DIRS`
    → `/etc/xdg/` → `/etc/`. There is **no `/usr` entry** — `/usr/share/fastfetch/` is a
    *data* dir, for presets and logos, not for the default config. So `/etc/fastfetch/` is
    the only system-wide location, and it is a pure addition (the RPM ships nothing there),
    not a replacement like `/etc/zshenv`. A user's own file still wins, first entry in the
    list, exactly the DD-030 relationship with no wiring at all.
    **The layout is drawn with absolute cursor columns, so the logo width is load-bearing.**
    The config pins the four columns with CHA (`ESC[<n>G`) rather than counting characters,
    because Nerd Font glyphs are not all one cell wide. Every column is derived from the
    logo gutter, and auto-detection cannot supply a stable one here: `ID=qubix_os_bluebuild`
    (DD-003) matches no builtin logo, so fastfetch falls back to its 23-column generic
    penguin. Hence a pinned `fedora_small`.
    Widths were measured, not assumed — from the 2.66.0 tag's logo files (with `$N` colour
    codes stripped) and cross-checked against what fastfetch actually emits: `fedora` 38,
    `fedora_small` 16, `unknown` 23. The full Fedora mark would put the right spine at
    column 112; a WezTerm tiled to half of the 1920px panel (`default-column-width` is
    `proportion 0.5`) is around 100 columns, so it would not fit. `fedora_small` gives a
    22-column gutter and a 90-column box.
    `retune.sh` is shipped as the tool for anyone who changes the logo, adapted to take the
    config path as an argument instead of assuming it sits beside the script. Its `perl`
    dependency is satisfied: Fedora's `git`, already in the package list, requires
    `/usr/bin/perl`.
    **Superseded in part by IMG-031 (2026-08-03).** The two paragraphs above about *which*
    logo are wrong on both counts: detection reaches `ID_LIKE=fedora` and picks the full
    mark, never the penguin, and the fallback measures 30 wide rather than 23. The shipped
    logo is now `fedora`, the box is 112 columns, and the criterion below about fitting a
    half-tiled WezTerm no longer holds — see DD-041. Everything here about *where* the config
    goes still stands.
  - **Acceptance criteria:**
    - `fastfetch` is installed, and nothing runs it automatically — no login banner, no
      shell startup cost
    - The config lands at `/etc/fastfetch/config.jsonc`, and `~/.config/fastfetch/` still
      overrides it with no per-user setup and nothing to undo
    - The logo is pinned rather than detected, and the four box columns are derived from
      that logo's real gutter, with the derivation written down in the file
    - The box fits a terminal narrower than a half-tiled WezTerm on the laptop panel
    - `retune.sh` ships, runs against a config given as an argument, and says in its header
      to tune a copy rather than the system file
    - The one row that makes a network request is called out where a reader will see it
    - `docs/shell.md`, a `DD-###`, `docs/recipe-reference.md`, `docs/overview.md` and
      `.agent/context/` cover it
    - On the rebased image, `fastfetch` draws a square box on a fresh account
      *(confirmed 2026-08-04)*

- [x] **IMG-021** — Make lazygit a tool in its own right, not a LazyVim dependency
  - **Category:** Image content
  - **Depends on:** IMG-015
  - **Notes:** Requested 2026-08-02. `lazygit` is **already installed** — IMG-015 added it
    from COPR `atim/lazygit`, but only as one of the binaries LazyVim's `<leader>gg` shells
    out to. It appears in no tool table, has no configuration, and nothing tells a user it
    is there. This task promotes it.
    Two things the image knows and a user's bare lazygit does not:
    - **A Nerd Font is installed** (`cascadia-mono-nf-fonts`, DD-026). lazygit shows file
      and branch icons only when `gui.nerdFontsVersion` is set — it defaults to empty,
      meaning *no icons*, because upstream cannot assume the font.
    - **The project palette** (`#56728B`, DD-022). lazygit's theme keys accept hex; verified
      in `pkg/theme/style.go`, where a value is looked up in `ColorMap` and otherwise passed
      to `utils.IsValidHexValue` — and an unrecognised value is *silently ignored*, so a
      typo dims a border rather than failing to start.
    **How the config is delivered** decided the shape. lazygit reads exactly one path,
    `~/.config/lazygit/config.yml`, and there is no system-wide location — but
    `LG_CONFIG_FILE` takes a **comma-separated list**, and later files override earlier ones
    key by key. So the image's config goes first and the user's second, which is a better
    relationship than starship's all-or-nothing: a user overriding one colour keeps the
    rest. Verified in `pkg/config/app_config.go`: paths from `LG_CONFIG_FILE` carry
    `ConfigFilePolicyErrorIfMissing`, so the user's path may only be appended **when it
    exists**, and `SaveGlobalUserConfig` (the only writer) is integration-test-only and
    panics on multiple files — so a config in read-only `/usr` is safe.
    Upstream's `lg` wrapper (README, "Changing Directory On Exit") makes the shell follow
    lazygit when you switch repos inside it and quit with `q`. It is the same trade as
    yazi's `y`, so it is shipped the same way — with `mktemp` instead of upstream's
    `~/.lazygit/newdir`, so nothing is left in `$HOME`.
  - **Acceptance criteria:**
    - `lazygit` is listed and commented as a tool of its own in `common-base.yml`, still
      noting that LazyVim's `<leader>gg` needs it
    - The shipped config sets the Nerd Font version and the `#56728B` palette, and lives in
      `/usr` — nothing is written to `$HOME`
    - `LG_CONFIG_FILE` is set only when the user has not set it, and names the user's own
      config **only when that file exists**, so lazygit never errors on a missing path
    - A user's `~/.config/lazygit/config.yml` overrides the image's key by key, and deleting
      it returns to the image's
    - `lg` runs lazygit in both shells and leaves the shell in the repo lazygit was last in
    - `docs/shell.md`, a `DD-###`, `docs/recipe-reference.md`, `docs/overview.md` and
      `.agent/context/` cover it
    - On the rebased image, `lg` works and lazygit shows icons on a fresh account
      *(confirmed 2026-08-04)*

- [x] **IMG-022** — Ship zellij, the terminal multiplexer
  - **Category:** Image content
  - **Depends on:** IMG-015
  - **Notes:** Requested 2026-08-02.
    **Where it comes from was the whole question.** Established rather than assumed:
    - **Fedora does not package zellij** — no `zellij` or `rust-zellij` in dist-git, and
      repology lists no Fedora or Terra build.
    - **Upstream endorses no COPR.** zellij's README and installation page give no Fedora
      instructions at all, unlike yazi, whose own docs point at `lihaohong/yazi` (DD-026).
    - The COPRs that exist are thin: `varlad/zellij` is stuck on 0.42.2 from July 2025,
      `boobaa/zellij` has one successful build, `frodo/zellij` has six since March 2026 and
      one of them failed. Enabling any of them adds a party who can run scriptlets in
      **every** Qubix image, for one tool.
    So: upstream's own release artifact, pinned by version and asserted by SHA-256 — the
    pattern DD-026 already uses for zsh-completions. The published `.sha256sum` is the hash
    of the **binary inside** the tarball, not of the tarball, so the assertion is on the
    artifact that ships.
    **The `no-web` build, deliberately.** zellij 0.43 added a local web server (`zellij web`,
    `web_sharing`); it is off by default, but upstream also publishes a build compiled
    without `web_server_capability`, which makes it unavailable rather than merely disabled.
    That is the right default for an image that promises atuin is local and calls out
    fastfetch's one network row (DD-031). It is also 4 MB smaller.
    **Configuration.** `SYSTEM_DEFAULT_CONFIG_DIR` is `/etc/zellij` (verified in
    `zellij-utils/src/consts.rs`), and `find_default_config_dir()` returns the **first
    existing** directory of `~/.config/zellij` → `$XDG_CONFIG_HOME/zellij` → `/etc/zellij`,
    so a user's directory shadows the image's wholesale — the DD-031 relationship again,
    with no wiring. Nothing auto-creates `~/.config/zellij`:
    `try_create_home_config_dir()` has no caller in the binary's path.
    **The theme is written in zellij's named-style form, not its 11-colour palette form**,
    and that was not the first choice. The palette form is four lines shorter, but
    `impl From<Palette> for Styling` (`zellij-utils/src/data.rs`) maps the names to *roles*:
    `green` becomes the focused pane frame and the selected ribbon's background, `blue` is
    used for one emphasis and one player colour. Feeding it `blue "#56728B"` would have hidden
    the project colour almost entirely, and six colours the mapping also reads — `gold`,
    `silver`, `purple`, `brown`, `pink`, `gray` — are not settable in that form at all, so
    they would have stayed at zellij's defaults. Naming the elements costs lines and leaves
    nothing to chance. Hex strings are accepted in both forms (`is_six_digit_hex`).
    **The accents are lifted from DD-022's `hsl(h, 55%, 50%)` to `hsl(h, 55%, 68%)`**,
    because in zellij every accent is text on a dark surface and the L50 row does not clear
    WCAG AA there (magenta 3.6:1, red 3.0:1 on `#1B242C`). At L68 all six clear 4.5:1 on
    both backgrounds this theme puts text on.
    `copy_command` is left unset on purpose: the default is OSC 52, which WezTerm supports
    and which keeps working over SSH, whereas `wl-copy` would tie copy to a local Wayland
    session and to a package this image does not install.
  - **Acceptance criteria:**
    - `zellij` is installed from upstream's `no-web` musl release, pinned by version and
      verified by the published SHA-256 of the binary, so a changed artifact fails the build
    - Nothing starts zellij automatically — no shell hook, no autostart script
    - The config lands at `/etc/zellij/config.kdl`, is themed from the `#56728B` palette, and
      `~/.config/zellij/` still shadows it with no per-user setup
    - Every UI element zellij can colour is set explicitly — nothing falls back to zellij's
      own theme — and every text pair clears WCAG AA (4.5:1), with the ratios written down;
      the one pair that does not is a frame line, states its ratio, and says why
    - The build asserts that zellij resolves `/etc/zellij/config.kdl` **and** parses it, so a
      broken KDL fails CI rather than a login
    - zsh and bash completions are installed, generated by the binary that ships
    - Nothing is left in the build container's `$HOME`
    - `docs/shell.md`, a `DD-###`, `docs/recipe-reference.md`, `docs/overview.md`,
      `docs/glossary.md` and `.agent/context/` cover it, including how to bump the version
    - On the rebased image, `zellij` starts with the Qubix theme on a fresh account
      *(confirmed 2026-08-04)*

- [x] **IMG-024** — Set the login shell to zsh from the image, because `chsh` does not exist
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported 2026-08-03: neither zsh nor starship-on-zsh is working on the
    machine. One upstream fact explains both, and it invalidates DD-030.
    **Aurora deletes `/usr/bin/chsh`.** `ublue-os/aurora`,
    `build_files/base/16-override-install.sh` line 8: `rm -f /usr/bin/chsh /usr/bin/lchsh`,
    commented "Footgun", citing ublue-os main issue 598. So
    `chsh -s /usr/bin/zsh` — the command in `docs/shell.md`, `docs/usage.md`,
    `docs/overview.md`, `docs/recipe-reference.md` and the recipe comments, and the **only**
    route to zsh for an account that already exists — fails with `command not found` on
    every Qubix image ever published. DD-030 rested on that command being available. It
    never was.
    The starship complaint is the same bug one step later: WezTerm sets no `default_prog`,
    so a terminal spawns the login shell, which is still bash. The zsh half of the
    environment was only ever reachable by typing `zsh`.
    **`usermod -s` is the replacement**, not a different `chsh`. It is shadow-utils, which
    Aurora keeps, it does not consult `/etc/shells`, and it needs no password when run as
    root — which is what makes the boot service the natural home for it.
    So DD-028's service comes back, with its three rules intact (ordered
    `Before=systemd-user-sessions.service`, UID 1000–60000 so root keeps bash, and one
    attempt per account, stamped in `/var/lib/qubix-os/`). DD-030 removed it as "a large
    hammer for a command the owner runs once"; the command it was traded for does not exist.
  - **Acceptance criteria:**
    - A boot service sets `/usr/bin/zsh` as the login shell for human accounts that are
      still on bash, once per account, and never touches an account twice
    - `root` is never touched, and an account moved back to bash stays there
    - `/etc/default/useradd` still covers accounts created afterwards
    - The build asserts that `usermod` exists, so the service cannot ship without its tool
    - **No page tells anyone to run `chsh`.** Every instruction that survives is `usermod`,
      and the reason chsh is absent is written down where a reader will hit it
    - DD-030's login-shell half is superseded, not rewritten, by a record carrying the
      upstream evidence; DD-028's status points at it
    - On the rebased image, the first login after a boot lands in zsh on an account that was
      created before the rebase *(confirmed 2026-08-04)*

- [x] **IMG-025** — Wire zsh from the end of `/etc/zshrc`, not from `/etc/zshenv`
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Found while diagnosing IMG-024. `/etc/zshenv` is the **first** file zsh
    reads, and `/etc/profile.d/qubix-shell-env.sh` is reached later — through `/etc/zprofile`
    for a login shell, through `/etc/zshrc` for an interactive one. So today every variable
    the image exports for these tools (`STARSHIP_CONFIG`, `ATUIN_*`, `LG_CONFIG_FILE`,
    `EDITOR`) is set **after** `starship init` and `atuin init` have already run. It works
    only because both tools re-read their environment at prompt time; nothing about the
    design makes that safe, and the next tool that reads its config at init time breaks.
    Two more costs of that position, established against Fedora's own files rather than
    assumed (rawhide dist-git, `zshrc.rhs`):
    - `/etc/zshrc` line 11 is `[[ "$PROMPT" = "%m%# " ]] && PROMPT=...`. It runs *after*
      `/etc/zshenv`, so the only thing standing between Fedora's prompt and starship's is
      that guard. Ours should simply run later.
    - `/etc/zshenv` is read by **every** zsh, scripts included, which is why the file needs
      an `-o interactive` guard to hold interactive setup at all.
    `/etc/zshrc` is the file zsh documents for interactive setup, it is sourced only by
    interactive shells, and it is where the `/etc/profile.d` loop already lives — so
    appending to its end puts the shell environment after everything the system sets and
    before the user's own `~/.zshrc`, which still wins.
    **Appended at build time rather than shipped as a file.** Vendoring Fedora's 50 lines
    into the overlay to add six of ours means owning their copy forever; a `containerfile`
    snippet appends only what is ours, so upstream changes flow through untouched. The
    snippet asserts Fedora's `_src_etc_profile_d` is present before appending, and runs
    `zsh -n` over the result, so a base image that reorganises `/etc/zshrc` fails the build
    instead of silently producing a shell with no prompt.
    Rejected, and recorded so it is not re-proposed: deferring the setup to the first
    `precmd` hook from `/etc/zshenv`. It would run later still — after `~/.zshrc` — but it
    mutates `precmd_functions` while zsh is iterating over it, and it is a great deal of
    cleverness for an ordering that appending already gets right.
  - **Acceptance criteria:**
    - The zsh half is sourced from the end of `/etc/zshrc`, after the `/etc/profile.d` loop
      and after Fedora's default `PROMPT` line
    - `files/system/etc/zshenv` is gone, and Fedora's own file comes back on a rebase
    - Fedora's `/etc/zshrc` is not vendored: the build appends to it and asserts both that
      upstream's content is there first and that the result parses
    - A user's `~/.zshrc` still runs last and still wins
    - DD-030's zsh-wiring half is superseded, not rewritten
    - `docs/shell.md`, `.agent/context/` and `docs/recipe-reference.md` no longer say the
      shell is wired from `/etc/zshenv`
    - On the rebased image, a zsh login has the starship prompt, atuin history search and
      both plugins *(confirmed 2026-08-04)*

- [x] **IMG-023** — Ship the WezTerm configuration, and the fonts it names
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Requested 2026-08-02: take the WezTerm config the user already runs on macOS
    (`~/.config/wezterm/`, `wezterm.lua` plus two colour schemes) and make it the image's
    default. DD-012 installed WezTerm and made it the default terminal; it left WezTerm
    running on its own built-in defaults.
    **Where it goes was the whole design problem, and the obvious answer is a trap.**
    WezTerm resolves its config from `$WEZTERM_CONFIG_FILE` → `~/.wezterm.lua` →
    `$XDG_CONFIG_HOME/wezterm/wezterm.lua` → each `$XDG_CONFIG_DIRS` entry
    (`config/src/config.rs`, `load_with_overrides`). `WEZTERM_CONFIG_FILE` is the shape
    `STARSHIP_CONFIG` (DD-026) and `LG_CONFIG_FILE` (DD-032) established here — and it is
    inserted at the **front** of that list, so it would beat the user rather than lose to
    them. `/etc/xdg/wezterm/` is reached from the *back*, which is the DD-031/DD-033
    relationship with no wiring at all. Colour schemes resolve the same way
    (`compute_color_scheme_dirs()` appends `colors/` to each config dir), so they stay
    available even to someone whose own `wezterm.lua` has replaced the file above them; a
    scheme's name is its `[metadata] name`, not its filename.
    **`$XDG_CONFIG_DIRS` has to be stated, not assumed.** WezTerm reads the variable
    literally and does **not** apply the XDG spec's `/etc/xdg` default when it is unset, so
    without it this config does not exist. Plasma sets it, niri does not. It goes in the
    existing `environment.d` file as `${XDG_CONFIG_DIRS:-/etc/xdg}` — the `:-` form is
    supported there, and the man page's own example is this exact shape.
    **The fonts had to become real**, or the config would be a list of names WezTerm silently
    drops. Availability was checked against the f43 repositories and the upstream releases,
    not assumed: Fedora packages **no** `monaspace-fonts` in any form, and `ibm-plex-fonts`
    6.4.0 has **no `math` subpackage**. Those two come from upstream, pinned and hash-asserted
    (the DD-026/DD-033 pattern); IBM Plex Mono and Sans are ordinary RPMs. **CJK is a
    substitution:** IBM publishes Plex Sans SC/TC/JP only as 523/367/317 MB release archives
    and Fedora packages no CJK Plex at all, so `google-noto-sans-cjk-fonts` stands in — the
    *static* package, whose `.ttc` files expose `Noto Sans CJK SC`/`TC`/`JP` as plain family
    names. The SC → TC → JP order is preserved because it decides which regional form a
    shared Han character is drawn in.
    The Nerd-Font-patched Monaspace is taken even though WezTerm bundles Symbols Nerd Font
    Mono and plain Monaspace would draw the same glyphs, because only the patched build
    answers to `Monaspace Krypton NF` — the name the config asks for everywhere else. Only
    the normal widths are installed; the archive carries every weight three times over.
    Three macOS-only settings are dropped (`macos_window_background_blur` and the two
    `send_composed_key_when_*_alt_is_pressed`, of which the left-alt one was assigned twice).
    `window_background_opacity` is kept and behaves differently: WezTerm never requests a
    blurred background region on Wayland, so KWin's blur does not apply and niri has none.
  - **Acceptance criteria:**
    - The config lands at `/etc/xdg/wezterm/wezterm.lua` with its schemes in
      `colors/` beside it, and `~/.config/wezterm/` still shadows it with no per-user setup
    - `WEZTERM_CONFIG_FILE` is **not** set by the image, and the file says why
    - `XDG_CONFIG_DIRS` is guaranteed to contain `/etc/xdg` without clobbering an inherited
      value
    - Every family the font stack names is installed by the image — no entry resolves to a
      fallback — and the two Fedora does not package are pinned by version and asserted by
      SHA-256, so a changed artifact fails the build
    - The build asserts that WezTerm **resolves** `/etc/xdg/wezterm/wezterm.lua` by its real
      search path, parses it, finds the colour scheme, and loads all seven families
    - Redistribution licences ship for both upstream fonts
    - What the macOS config loses, and what `window_background_opacity` does here, are
      written down rather than silently changed
    - `docs/desktops.md`, a `DD-###`, `docs/recipe-reference.md`, `docs/overview.md`,
      `docs/architecture.md`, `docs/glossary.md` and `.agent/context/` cover it
    - On the rebased image, a WezTerm opened in either session comes up with the Monaspace
      stack and the Oxocarbon scheme on a fresh account
      *(confirmed 2026-08-04)*

- [x] **IMG-026** — Stop guarding the shell setup on variables a child shell inherits
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported 2026-08-03: starship does not appear when zsh is started from bash,
    or bash from zsh. **Reproduced from the source, not guessed.** Every guard in the
    terminal environment tests an *exported* variable, and an exported variable is
    inherited by every child process, so each guard reads "somebody, somewhere, once" when
    it was written to mean "this shell, already".
    - `starship init zsh` ends with `export STARSHIP_SHELL="zsh"`, and `starship init bash`
      with `export STARSHIP_SHELL="bash"` — verified against starship's own
      `--print-full-init` output. `qubix.bash` and `qubix.zsh` both skip `starship init`
      when `STARSHIP_SHELL` is non-empty, so **no nested shell of any kind gets the
      prompt**: zsh→bash, bash→zsh, and zsh→zsh alike.
    - `atuin init zsh` does `export ATUIN_SESSION=$(atuin uuid)`, and `qubix.zsh` skips
      atuin when that is set. atuin already handles nesting itself — its own guard is
      `[[ -z "${ATUIN_SESSION:-}" || "${ATUIN_SHLVL:-}" != "$SHLVL" ]]` — so ours does
      nothing but defeat it. A nested zsh gets no Ctrl-R search and no widgets.
    - The same mistake in `/etc/profile.d/qubix-shell-env.sh` costs something subtler.
      `STARSHIP_CONFIG`, `LG_CONFIG_FILE` and the `ATUIN_*` block are resolved from whether
      the user has a config of their own, exported, and then never reconsidered — and the
      **session itself** reads that file (SDDM's `wayland-session` sources `/etc/profile`),
      so the answer is fixed at login and inherited by every terminal under it. "Create
      `~/.config/starship.toml` and it wins", as the docs promise, has meant "log out and
      back in".
    The fix is one rule: **guard on something the shell cannot inherit.** Functions are not
    inherited, so `prompt_starship_precmd` / `_atuin_precmd` are true per-shell tests; the
    exported variables are instead re-resolved in every shell, and left alone whenever they
    hold anything other than the image's own literal path.
  - **Acceptance criteria:**
    - starship initialises in every interactive shell, including one started from another
      shell, in both directions and in both shells
    - atuin initialises in every interactive zsh, and its own `$SHLVL` bookkeeping is left
      to it
    - Neither tool is initialised twice in one shell, including for a user who runs
      `starship init` from `~/.zshenv`
    - `STARSHIP_CONFIG`, `LG_CONFIG_FILE` and the `ATUIN_*` block are re-resolved in every
      shell, so a config file created after login wins in the next shell rather than the
      next session
    - A value in any of those variables that is **not** the image's own is never touched
    - DD-036's "the tools guard against double initialisation" consequence still holds
    - `docs/shell.md`, a `DD-###` and `.agent/context/` cover it
    - On the rebased image, `zsh` from bash and `bash` from zsh both come up with the
      prompt *(confirmed 2026-08-04)*

- [x] **IMG-027** — Make `XDG_CONFIG_DIRS` reach every shell, not only systemd's units
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported 2026-08-03 alongside IMG-026: the WezTerm theme is not applied.
    `XDG_CONFIG_DIRS` is the only route to `/etc/xdg/wezterm/wezterm.lua` — WezTerm reads
    that variable literally and does **not** fall back to the `/etc/xdg` the XDG base
    directory specification calls the default (DD-034) — and the image sets it in exactly
    one place, `/usr/lib/environment.d/50-qubix-terminal.conf`. That file has two holes:
    - **environment.d only reaches what the systemd *user manager* starts.** A shell over
      SSH, on a text console, or through `su -` is a child of sshd, of logind's TTY, or of
      su — none of them the user manager — so none of them has the variable, and neither
      does anything they launch.
    - **`${XDG_CONFIG_DIRS:-/etc/xdg}` does nothing when the variable is already set.**
      `:-` only fills in an *empty* value, so a session that exports a list without
      `/etc/xdg` in it keeps that list and the system config stays unreachable. Plasma's
      list does contain `/etc/xdg` (kde-settings), which is why this has not bitten in a
      Plasma login; nothing guarantees the next session manager is as kind.
    Both are fixed by appending rather than defaulting: `${XDG_CONFIG_DIRS:+…:}/etc/xdg` in
    environment.d — the shape systemd's own man page gives for `LD_LIBRARY_PATH`, and `:+`
    is confirmed supported there — and a membership-tested append in
    `/etc/profile.d/qubix-shell-env.sh` for every shell environment.d cannot reach.
    `/etc/xdg` goes **last** in both, so a session that put its own directories first keeps
    its precedence.
  - **Acceptance criteria:**
    - `/etc/xdg` is present in `$XDG_CONFIG_DIRS` in every interactive shell, including one
      reached over SSH or on a text console
    - It is added to a list that lacks it, rather than only filling an empty one
    - It is never added twice by the shell path, never removed, and never reordered ahead of
      a directory the session chose
    - No KDE behaviour changes: a Plasma login's list is already correct and is left as it is
    - `docs/desktops.md`, `docs/shell.md`, DD-034's consequences and `.agent/context/` cover it
    - On the rebased image, a WezTerm opened in either session comes up with the Oxocarbon
      scheme and the Monaspace stack *(confirmed 2026-08-04)*

- [x] **IMG-028** — Give the shipped configuration a one-command route into `~/.config`
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Requested 2026-08-03. Every configuration this image ships lives in `/usr` or
    `/etc`, where a rebase replaces it and a user's own file shadows it. That default is
    right and stays (DD-030). What it leaves awkward is *starting* to customise: you have to
    know which of six paths holds the file, whether your copy replaces the image's wholesale
    or merges with it, and — for niri — that copying it verbatim **breaks the session**.
    Three shapes were considered. `/etc/skel/.config/` is nearly free and reaches only
    accounts created afterwards, which on a personal machine is nobody. A login seeder
    reaches existing accounts and is exactly the machinery IMG-019 deleted, and it would
    make every account's config a dead copy by default — the trap DD-025 and DD-030 exist to
    avoid. **A command run on demand** gives the same convenience to the people who want it
    and changes nothing for anybody else, so that is what this is.
    Two details are worth more than the copying:
    - **niri's palette include is relative.** `/etc/niri/config.kdl` ends its theme block
      with `include "qubix-theme.kdl"`, which niri resolves against the *including file's*
      directory. Copied verbatim into `~/.config/niri/` that names a file which is not
      there. The copy is rewritten to the absolute `/etc/niri/qubix-theme.kdl` — which is
      also the line `docs/desktops.md` already tells people to keep, and which leaves the
      palette tracking the image.
    - **Two entries deliberately copy less than they could.** WezTerm's colour schemes stay
      in `/etc/xdg/wezterm/colors/`, where they remain available to a personal
      `wezterm.lua` and go on tracking the image; lazygit's config merges key by key, so a
      whole copy is usually the wrong thing and the command says so.
    A copy is still a fork, so `--diff` shows what the image has changed since you took one.
  - **Acceptance criteria:**
    - `/usr/bin/qubix-config` copies any shipped configuration into `~/.config`, lists what
      is available with its source and whether you already have a copy, and diffs your copy
      against the image's current version
    - **Nothing runs it.** No login hook, no service, no first-boot seeding; an account that
      never runs it has nothing in `~/.config` and keeps tracking the image
    - It never overwrites without `--force`, and `--force` keeps the previous file
    - The niri copy has its theme `include` rewritten to an absolute path, and the command
      **fails rather than writing** a config whose include did not rewrite
    - Entries whose relationship with the image is not "replaces it wholesale" say so at the
      moment they are copied
    - It refuses to write as root, so `sudo` cannot leave root-owned files in a home
      directory
    - The build asserts that every path it names exists in the image and that the niri
      rewrite still matches, so a moved config fails CI rather than a user's copy
    - Every scattered `cp …` instruction in `docs/` is replaced by it
    - `docs/shell.md`, `docs/desktops.md`, a `DD-###`, `docs/recipe-reference.md` and
      `.agent/context/` cover it, including that a copy stops receiving image changes
    - On the rebased image, `qubix-config niri` produces a session that loads and still
      themes *(confirmed 2026-08-04)*

- [x] **IMG-029** — Make `#` start a comment on zsh's command line
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Found 2026-08-03 in a diagnostic paste, which is the only way this ever shows
    up. **zsh does not honour comments on an interactive command line unless
    `INTERACTIVE_COMMENTS` is set**, and it is off by default — unlike bash, unlike sh, and
    unlike every zsh *script*, where `#` always comments. So pasting
    `wezterm ls-fonts | grep -i scheme    # empty output means it resolved` sends `#`,
    `empty`, `output` … to grep as filenames, and a `?` anywhere in the trailing prose
    becomes a glob that kills the whole line with `no matches found`. Both happened, in one
    paste, to commands copied out of this repository's own documentation.
    Verified rather than assumed: `setopt | grep -c interactivecomments` is `0` in a bare
    `zsh -f -i`. It cannot be reproduced with `zsh -c`, because a `-c` string is parsed as a
    script, where `#` is always a comment — which is exactly why this is invisible until
    somebody pastes into a real prompt.
  - **Acceptance criteria:**
    - `#` starts a comment in an interactive zsh, so a commented command pasted from `docs/`
      runs as written
    - It is set in `qubix.zsh`, before anything a user might paste, and `~/.zshrc` can still
      `unsetopt` it
    - `docs/shell.md` and `.agent/context/` note that the image sets it and why
    - On the rebased image, pasting a trailing-comment command works *(confirmed
      2026-08-04)*

- [x] **IMG-030** — Make the name `fastfetch` reach fastfetch
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Root cause of the "fastfetch config is ignored" reports of 2026-08-03,
    established on the machine after three wrong guesses:
    ```
    $ type -a fastfetch
    fastfetch is an alias for ublue-fastfetch
    $ grep -rn fastfetch /etc/profile.d/
    /etc/profile.d/ublue-fastfetch.sh:3:alias fastfetch='ublue-fastfetch'
    ```
    Aurora aliases `fastfetch` to its own wrapper, which passes
    `/usr/share/ublue-os/fastfetch.jsonc` explicitly. **An alias is resolved before `$PATH`,
    and an explicit `--config` before any config directory**, so the alias beat the whole
    search path DD-031 reasoned about — `/etc/fastfetch/config.jsonc` was correct, present
    and unreachable, and so was `~/.config/fastfetch/config.jsonc`.
    The ordering is the trap in the fix: `/etc/profile.d` is sourced alphabetically and
    `qubix-shell-env.sh` sorts before `ublue-fastfetch.sh` (q < u), so an unalias in the
    file we already ship is undone a moment later. Hence a second file named to sort last.
    Aurora's file is not replaced — it carries `neofetch`/`neowofetch` aliases that are
    upstream's, and replacing it would mean owning their copy to delete one line.
  - **Acceptance criteria:**
    - `fastfetch` runs `/usr/bin/fastfetch`, so `/etc/fastfetch/config.jsonc` is read and a
      user's `~/.config/fastfetch/config.jsonc` still wins over it
    - Aurora's file is left alone; `ublue-fastfetch`, `neofetch` and `neowofetch` all still
      work and still print Universal Blue's banner
    - The undo is a no-op when upstream stops setting the alias, and never removes an alias
      somebody set deliberately
    - The build asserts the **result** — every `/etc/profile.d` file sourced in order, then
      the alias must be gone — not the file-sort order, and the assertion is rehearsed
      against a `zzz-*.sh` that reinstates it *(done — it fails as intended)*
    - DD-031's status says the config was unreachable until now; a `DD-###` records the
      mechanism, and `type -a` is written down as the first thing to check for any
      "my config is ignored" report
    - `docs/shell.md` and `.agent/context/` cover it
    - On the rebased image, `fastfetch` draws the Qubix box *(confirmed 2026-08-04)*

- [x] **IMG-031** — Draw the full Fedora mark, and move the box out of its way
  - **Category:** Image content
  - **Depends on:** IMG-020
  - **Notes:** Requested 2026-08-03: the `"logo"` block can go, but with it gone fastfetch
    draws the **full** Fedora mark and the box — pinned at columns 23/29/39/90 — is written
    on top of it, because the full mark occupies columns 1–44.
    **DD-031's reason for pinning was wrong, and this is how it was found.** It claimed
    detection falls back to the generic penguin because `ID=qubix_os_bluebuild` matches no
    builtin logo. Detection does not stop at `ID`: fastfetch tries `ID`, then `NAME`, then
    each word of `ID_LIKE`, then the kernel's name, then `unknown`
    (`logoGetBuiltinDetected`, `src/logo/logo.c`). DD-003 rewrites `ID` and `NAME`, so the
    field that still says fedora is `ID_LIKE` — by elimination, since the mark that appeared
    is Fedora's and no other step can produce it — which is why deleting the block draws the
    full 38-column mark and not a penguin.
    Measured with fastfetch 2.61.0 against this config's padding (+2 left, +4 right):
    `fedora` 44-column gutter, `fedora_small` 22, `unknown` 36 — so DD-031's "23 wide,
    29-column gutter" for the fallback was stale too.
    The columns were re-derived by running the image's own `retune.sh` against the config,
    which is the first time that tool has been used for the job it was written for.
  - **Acceptance criteria:**
    - The full `fedora` mark is what the box is drawn beside, and the two do not overlap
    - All four columns are re-derived from the 44-column gutter — spine 45, label 51,
      separator 61, right spine 112 — in every key, in `display.separator`, and in the four
      rule lines
    - The logo stays **pinned**, so a fastfetch that ships a `qubix` logo or a base image
      that drops `ID_LIKE` cannot move the columns silently
    - The config's header comment states the real detection order, and says the box now
      needs a 112-column terminal — more than Niri's default half column gives it
    - `retune.sh` describes the logo the shipped config is actually tuned for
    - A `DD-###` supersedes the logo half of DD-031, including its wrong fallback reasoning;
      `docs/shell.md` and `.agent/context/` follow
    - On the rebased image, `fastfetch` draws the box beside the full mark *(confirmed
      2026-08-04)*

- [x] **IMG-032** — Teach `retune.sh` to measure a gutter fastfetch no longer steps over
  - **Category:** Image content
  - **Depends on:** IMG-031
  - **Notes:** Reported from the machine on 2026-08-03, right after IMG-031:
    `retune: could not measure the logo gutter`.
    fastfetch **2.64.0** reworked built-in logo printing to go line by line. The
    `ESC[<gutter>C` step the script grepped for does not exist any more; the gutter is now
    `<gutter>` literal spaces at the start of each module line. The image tracks Fedora's
    fastfetch, which is past 2.64, so the tool DD-031 shipped for this job could not do it
    on the image it ships in.
    Confirmed against two binaries rather than reasoned about: the installed 2.61.0 emits
    `ESC[1G ESC[20A ESC[44C`; an upstream 2.66.0 release tarball emits 44 spaces.
    The new reading needs `--logo-padding-top 1`, or the first line carries the logo's first
    row as well as the padding and the gutter could only be recovered by counting art —
    which fails on any logo glyph that is not one byte and one column wide.
    **The box was never affected**; that was checked first. CHA is absolute, so the shipped
    config renders identically under both binaries.
  - **Acceptance criteria:**
    - `retune.sh` measures the gutter on fastfetch ≤ 2.63 *and* ≥ 2.64, verified end to end
      against both binaries, including on a config with the `"logo"` block deleted
      *(done — both rewrite 23/29/39/90 to the same numbers for the same logo)*
    - The failure path names both forms, prints the command to run by hand, echoes
      fastfetch's stderr instead of discarding it, and states `gutter + 1/7/17/68`
    - The shipped config's four columns are unchanged — this is a tool fix, not a layout fix
    - `DD-042`, `docs/shell.md` and `.agent/context/` cover it
    - On the rebased image, `retune.sh -n` reports a 44-column gutter *(confirmed
      2026-08-04)*

- [x] **IMG-033** — Give a distrobox container the same interactive shell as the host
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Requested 2026-08-04: the shell inside `distrobox enter` has none of what
    the host's has — no starship prompt, no atuin history search, no zsh plugins.
    **It could not have.** A container is a different distribution with its own `/etc` and
    its own `/usr`, and every one of those tools is a host package read from a host path.
    Established against distrobox **1.8.2.5** — the version in both f43 and f44, and the one
    `ublue-os/main`'s `packages.json` puts in every ublue base image, Aurora DX included:
    - **The shell itself already crosses.** `distrobox-create` passes
      `--env SHELL=$(basename $SHELL)`, and `distrobox-init` installs the package of that
      name and gives the container user that shell (`shell_pkg`, then `useradd --shell`).
      So a container created while the host account is on zsh has zsh — and one created
      *before* `qubix-default-shell.service` ran has bash, which is the retrofit case.
    - **The host's root filesystem is at `/run/host`**, either as `/:/run/host` or, on
      podman+runc, mounted directory by directory. `--security-opt label=disable` is passed,
      so nothing in there is denied by SELinux. `$HOME` is the same directory in both.
    - **`/etc/distrobox/distrobox.conf` is the last system-wide file** in distrobox's config
      hierarchy (`/usr/share` → `/usr/etc` → `/etc` → `~/.config` → `~/.distroboxrc`), and
      the Fedora `distrobox` RPM **owns no file there** — verified against the package's file
      list, so this replaces nothing. `ublue-os-just` ships `*.ini` assemble manifests in the
      same directory and is untouched.
    - **`container_init_hook` is eval'd as root inside the container**, at the end of
      `distrobox-init`. Command-line flags are parsed *after* the config files are sourced,
      so `distrobox create --init-hooks …` — and any `distrobox assemble` entry with an
      `init_hooks=` key — overrides this. That is the per-container opt-out.
    - **`distrobox-init` runs with `set -o errexit` and `eval`s the hook**, so a non-zero
      exit from it aborts container setup and leaves a half-built container. This is why the
      hook may never fail, and why the packages are installed one at a time when a batch
      fails rather than through `container_additional_packages` (a single missing name there
      — Debian and Ubuntu package neither starship nor atuin — would break creation).
    **Text is linked, binaries are installed.** starship and atuin are compiled against the
    host's glibc and cannot be run from `/run/host`; the plugins, the prompt configuration
    and the shell files are plain text and can. One symlink,
    `/usr/share/qubix-os` → `/run/host/usr/share/qubix-os`, makes every absolute path in the
    host's own shell files — and in `STARSHIP_CONFIG` and `LG_CONFIG_FILE`, which the host
    exports into the container — resolve inside it, so a rebase changes the container's shell
    too with nothing to re-run. That is DD-030 one level down.
    Two distribution differences are absorbed by the script rather than by teaching a host
    file about every distro: Arch and Alpine put the plugins in `/usr/share/zsh/plugins/`,
    and Debian and Ubuntu install bat as `batcat`.
  - **Acceptance criteria:**
    - A container created after the rebase has the prompt, history search and both plugins,
      with nothing typed into it
    - Nothing is copied: the container reads the host's configuration live through
      `/run/host`, so a rebase changes it too
    - The hook cannot break `distrobox create` — every step is best-effort and it exits 0
      from inside a container whatever happened
    - It refuses to run on the host, where it would append a second block to `/etc/zshrc`
    - Re-running it is how an existing container catches up, including one whose user is
      still on bash because it predates the login shell being zsh
    - A guest distribution whose repositories lack starship or atuin gets everything else,
      and is told what it did not get
    - There is an opt-out for one container and an opt-out for all of them, both documented
    - The build asserts that distrobox is in the image, that the config names the script, and
      that the script parses
    - `docs/shell.md`, a `DD-###`, `docs/recipe-reference.md`, `docs/glossary.md` and
      `.agent/context/` cover it
    - On the rebased image, `distrobox create` then `distrobox enter` lands in a zsh with the
      Qubix prompt *(confirmed 2026-08-04)*

---

## Awaiting confirmation

Implemented, documented, and shipped; waiting only on a check that needs a built image on
real hardware. A task here is **not** work anybody should pick up — it is work somebody
should look at.

### Desktop sessions

- [ ] **IMG-038** — Restore file chooser dialogs in the Niri session
  - **Category:** Image content
  - **Depends on:** IMG-002
  - **Notes:** Reported 2026-08-31: portal-backed chooser dialogs do not open in Niri,
    including Zed's save-path selector and Ungoogled Chromium's download-location
    selector. Niri's upstream portal profile prefers the GNOME backend. Since GNOME 47,
    that backend delegates file choosing to Nautilus; Qubix installs the GNOME and GTK
    portal backends through niri's weak dependencies, but not Nautilus. The image now
    selects the already-installed GTK backend for `FileChooser` explicitly instead of
    adding a second graphical file manager. Static configuration checks pass; the two
    reported dialogs await a rebuilt Niri-session check.
  - **Acceptance criteria:**
    - The Niri-specific portal profile selects `gtk` for
      `org.freedesktop.impl.portal.FileChooser`
    - Niri retains the GNOME backend for screencasting and the existing GTK/gnome-keyring
      selections for other explicitly mapped interfaces
    - Plasma's portal selection is unchanged
    - The portal profile is commented, parses as an INI file, and its backend names match
      the portal packages installed in every image
    - `qubix-config niri-portals` copies the complete profile into the user's higher-priority
      configuration path and the existing build assertion covers its source path
    - `docs/desktops.md`, `docs/design-decisions.md`, and `.agent/context/files-system.md`
      document the cause, selection, and override path
    - On the rebased image, Zed can choose a save path and Ungoogled Chromium can choose a
      download location in Niri *(open — needs a build and hardware)*

- [ ] **IMG-036** — Configure Simplified Chinese Pinyin input with Fcitx 5
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** The Rocky Linux 10 reference guide builds Fcitx 5, its Chinese addons, and
    its KDE configuration tool because RHEL-family repositories do not carry the complete
    stack. Fedora carries all of them, so Qubix OS can use signed distro packages instead
    of maintaining locally compiled copies. The image supplies an XDG fallback profile;
    a user's own Fcitx or KWin configuration remains higher priority. The first Niri
    hardware check found Fedora's broad `GTK_IM_MODULE` export alongside a working
    Wayland frontend. A later terminal check proved that both Fcitx's explicit engine
    selection and the image helper worked, while `Ctrl+Space` remained unresponsive: Niri
    was not invoking its system compositor binding. The image therefore leaves
    `Ctrl+Space` unbound in Niri and makes it a native Fcitx trigger alongside
    `Super+Space`; Niri consumes only the latter for DMS. It awaits a rebuilt check.
  - **Acceptance criteria:**
    - Every image installs Fcitx 5, Fedora's Pinyin engine, the KDE configuration UI,
      autostart integration, and GTK/Qt input-method bridges from Fedora packages
    - Accounts without personal Fcitx configuration get English (US) and Pinyin, with
      native Fcitx triggers for both `Super+Space` (Windows/Meta key + Space) and
      `Ctrl+Space`
    - Plasma's documented input shortcut is `Super+Space`; Niri consumes `Super+Space` for
      the DMS application launcher and leaves `Ctrl+Space` unbound so it reaches Fcitx
    - Plasma selects the host Fcitx desktop entry as its default Wayland virtual keyboard;
      Niri starts Fcitx through XDG autostart
    - Wayland sessions leave `GTK_IM_MODULE` unset so native GTK uses the compositor's
      working text-input protocol without Fcitx's duplicate-path diagnostic; GTK 3/4
      X11 and XWayland clients select the packaged Fcitx module through system settings
    - Per-user Fcitx and KWin settings override the image defaults and are not rewritten
    - The recipe, desktop, design-decision, and context-cache documentation covers the setup
    - On the rebased image, Pinyin enters Simplified Chinese in native Wayland and XWayland
      applications under both Plasma and Niri *(open — needs a build and hardware)*

- [x] **BRD-005** — Give the Niri bar floating component capsules and the Qubix logo
  - **Category:** Branding
  - **Depends on:** BRD-004
  - **Notes:** Approved 2026-08-05 after an ASCII design check. The first built preset was
    rejected on hardware: it left DMS's large outer surface visible and turned component
    backgrounds into square outlines. Current DMS source shows why — `noBackground`
    controls each `BasePill`, while `transparency` controls the outer `BarCanvas`. Version
    2 makes the canvas transparent, retains rounded component backgrounds, removes the
    outlines, and keeps the canonical cube launcher. See DD-048.
  - **Acceptance criteria:**
    - The default Niri bar has no continuous background; each visible component is a
      separate adequately rounded Qubix Slate surface with spacing and padding
    - Components have no square or decorative outline around their rounded background
    - The launcher capsule displays the canonical Qubix cube artwork
    - Existing widget ordering and unrelated DMS settings are preserved
    - The corrected preset migrates once as version 2, including accounts stamped by
      version 1, while later user styling is not reset at every login
    - Invalid DMS settings are never overwritten and the settings update remains atomic
    - `docs/desktops.md`, `docs/design-decisions.md`, and `.agent/context/files-system.md`
      document the corrected DMS semantics and opt-out/reapply behavior
    - A Niri login on the built image shows only the approved rounded component surfaces
      and logo on real hardware

### Boot branding

- [ ] **BRD-006** — Theme GRUB as the Qubix Boot Console
  - **Category:** Branding
  - **Depends on:** BRD-002
  - **Notes:** Approved 2026-08-31 from a background sketch and a full representative
    boot-menu mockup. Fedora Atomic keeps GRUB's readable assets on the mutable `/boot`
    filesystem, outside the image's `/usr`; both bootupd's static configuration and
    Fedora's generated configuration source `/boot/grub2/custom.cfg`. The image therefore
    owns immutable source assets in `/usr/share/qubix-os/` and installs a delimited theme
    hook plus those assets into `/boot` without regenerating or replacing the boot menu.
    A first manual install showed the background only briefly before a blank handoff;
    bootupd's static config defaults to a one-second timeout, so the managed block now
    explicitly displays the approved menu for eight seconds. The next hardware photo
    showed the background and opaque panel but none of the labels or actual entries.
    Fedora GRUB's canvas prepends each parsed component and then paints the list from its
    head, reversing theme-file order: the panel declared first was painted last over every
    foreground component. The theme now declares foreground components first and its
    opaque panel last, with a build assertion protecting that counterintuitive ordering.
    The following hardware render confirmed the real entries and selection row, but its
    compact autoboot bar was enlarged and displaced: GRUB hard-codes a 200×28 minimum for
    that widget, overriding the requested six-percent width and four-pixel height. The
    redundant bar is removed; the correctly placed `AUTOBOOT 7s` numeric indicator stays.
    The approved hardware layout then requested Monaspace Krypton. Module 4d already
    installs its normal-width Nerd Font Regular and Bold OTF faces before the GRUB payload
    is built. Protocol v2 converts those exact files instead of IBM Plex Mono and retains
    only Latin text, arrows, and box-drawing glyphs; private-use Nerd Font icons are not
    needed by the boot selector and would unnecessarily enlarge every retained `/boot`
    revision.
  - **Acceptance criteria:**
    - GRUB renders the approved near-black Qubix Slate background, wireframe cube,
      terminal-style frame, boot-entry list, selected slate row, navigation help, and
      an eight-second numeric timeout indicator long enough to use the menu, without a
      second progress widget that can escape the footer layout
    - All visible GRUB text uses build-generated Monaspace Krypton NF Regular/Bold PF2
      fonts with the documented bounded glyph range
    - The theme styles whatever entries GRUB supplies; it does not hard-code operating
      systems, deployments, kernels, or firmware entries
    - An idempotent image-owned installer atomically synchronises the theme into
      content-addressed `/boot/grub2/themes/qubix-v<version>-<manifest-hash>` storage and
      manages only its delimited block in `custom.cfg`, preserving unrelated user content
    - The installer works with bootupd's static GRUB configuration and Fedora's legacy
      generated configuration without running `grub2-mkconfig`
    - The setup applies to every image variant, has a documented opt-out/reapply path,
      and fails safely without making the machine unbootable if `/boot` is unavailable
    - Build assertions cover required assets, executable syntax, GRUB theme structure,
      reverse canvas ordering, the visible timeout, and the managed-block markers
    - `docs/branding.md`, `docs/design-decisions.md`, `docs/recipe-reference.md`, and the
      context cache document the implementation and ownership boundaries
    - On a rebased image, the visible GRUB menu remains available for eight seconds,
      matches the approved design, and still boots current, rollback, firmware, and
      discovered external entries *(open — needs a build and hardware)*

- [ ] **IMG-007** — Replace inherited branding throughout boot and Plasma login
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** Reported from the standard image on 2026-08-05: boot still shows Aurora's
    watermark, and a Plasma login still shows inherited Aurora/KDE artwork. BlueBuild's
    `initramfs` module is required because Plymouth theming lives in the initramfs;
    copying `spinner/watermark.png` into `/usr` cannot change the initramfs Aurora already
    built. The Plasma splash has two more gaps: Aurora copies it into separate dark and
    light look-and-feel packages, while this repository overrides only the dark logo, and
    Aurora's `Splash.qml` draws a separate KDE footer after the distro logo.
  - **Acceptance criteria:**
    - The standard recipe regenerates the initramfs after the branding overlay and before
      `signing`; the CachyOS recipe retains its late post-kernel-swap regeneration
    - Aurora's dark and light Plasma splash packages both render the Qubix mark and no
      inherited Aurora or KDE logo/footer
    - The image default selects the branded splash; `docs/branding.md` explains how an
      existing user's `~/.config/ksplashrc` can override it and how to select it again
    - Recipe, branding, design-decision, and context-cache documentation matches the change
    - On the rebased standard image, cold boot shows the Qubix Plymouth watermark and a
      Plasma login shows only Qubix splash artwork *(open — needs a build and hardware)*

### Terminal environment

- [ ] **IMG-034** — Stop a package a container does not have from ending `distrobox enter`
  - **Category:** Image content
  - **Depends on:** IMG-033
  - **Notes:** Reported from the machine on 2026-08-04, entering a cross-compilation
    container on the image IMG-033 shipped:
    ```
    Executing init hooks...   Error: Unable to find a match: zsh-autosuggestions
                              zsh-syntax-highlighting starship atuin bat
    ```
    and the enter stopped there — no shell, no `[ OK ]`, no further output.
    **The cause is not the missing packages.** It is that `distrobox enter` follows the
    container's log while it initialises and **switches on the start of every line**
    (`distrobox-enter`, the `while IFS= read -r line` loop): `Error:*` is printed in red and
    followed by `exit 1`, `Warning:*` prints in yellow, `distrobox:*` becomes the name of
    the setup step, and **everything else is discarded, stdout and stderr alike**. dnf says
    `Error: Unable to find a match: …` for a name a distribution does not carry, so the
    watcher on the HOST abandoned the enter — regardless of the hook's own exit status,
    which IMG-033 was careful about and which was never the thing being tested.
    Two more consequences of that loop, both visible in the paste: every
    `qubix-distrobox-shell: …` line the script printed was **silently dropped**, because it
    matched no prefix; and the per-package fallback did run, but each retry printed another
    fatal `Error:` line into a log nobody was reading any more.
    The guest is also the case IMG-033 called "reported and skipped": a dnf container with
    **none** of the five packages. That path was correct in principle and useless in
    practice — a container with no starship is a container with no prompt, which is the
    whole point of the feature.
    So, three changes:
    - **Nothing may reach the log with an `Error:` prefix.** Every package manager runs with
      its output captured to `/var/tmp/qubix-distrobox-shell.log`, and the log is only ever
      echoed back through `warn()`, which re-prefixes each line — a diagnostic that killed
      the enter would be a poor diagnostic.
    - **Say it in the language the watcher reads.** `distrobox: ` for progress, `Warning: `
      for anything the user must see. The script's own name as a prefix meant invisibility.
    - **Borrow from the host what the container cannot install** — and prove it first.
      Plain text (the plugins, the shell files, the configuration) is always safe. A host
      *binary* is glibc-linked: it runs in a Fedora-family container, cannot run against
      musl (Alpine, Wolfi) and fails on a symbol against an older glibc (Debian 11), so
      `--version` is run in the container and the link is made only if it answers. It is
      linked into `/usr/local/bin`, not reached by putting `/run/host/usr/bin` on `$PATH`,
      which would expose every host binary and make `command -v` lie.
    Also folded in, from the same family of bugs: `compaudit` cannot establish ownership
    through the `/run/host` bind mount, so the host's `site-functions` on `$fpath` makes
    `compinit` stop and ask at every shell. The guest block now runs `compinit -u` itself,
    before the host file that would otherwise run it plain.
  - **Acceptance criteria:**
    - No line this hook produces, or any command it runs produces, can begin with `Error:`
    - What it does and what it could not do are **visible** during `distrobox create` and
      `distrobox enter`, using the two prefixes that loop displays
    - A container whose repositories carry none of the tools still gets the prompt, the
      history search and both plugins, from the host
    - A host binary is never linked into a container that cannot execute it, and the reason
      is reported when it is not
    - `/run/host/usr/bin` is never put on the container's `$PATH`
    - The skip-unavailable flag is separate from the install command, so a manager that does
      not know the flag still gets the name-by-name pass
    - **Superseded by IMG-035:** `compinit` does not prompt about insecure directories in a
      container. `-u` covered only the image's own call, and a container was carrying a
      block no re-run could replace
    - `DD-045` amends DD-043, and `docs/shell.md` and `.agent/context/` follow
    - On the rebased image, `distrobox enter ungoogled-chromium-macos-cross` reaches a shell
      with the Qubix prompt *(open — needs a build and hardware)*

- [x] **IMG-035** — Stop `compinit` asking about insecure directories in a container
  - **Category:** Image content
  - **Depends on:** IMG-034
  - **Notes:** Reported from the machine on 2026-08-04:
    ```
    $ distrobox enter fedora-box
    zsh compinit: insecure directories and files, run compaudit for list.
    Ignore insecure directories and files and continue [y] or abort compinit [n]?
    ```
    at the top of every shell in every container — the exact thing IMG-034's `compinit -u`
    was written to stop. Two separate faults, and the second is the one that matters beyond
    this bug.
    **`-u` on our own `compinit` settles nothing, because ours is not the last one.** The
    guest block puts `/run/host/usr/share/zsh/site-functions` on `$fpath`, and `compaudit`
    cannot establish ownership through that bind mount: the host's root is an unmapped uid
    inside a rootless container, so the directory is owned by neither root nor the user. `-u`
    silences *that* call and no other, and there is reliably another — Fedora's skeleton
    `~/.zshrc` calls `compinit` plainly, `$HOME` is shared, and `~/.zshrc` runs after
    `/etc/zshrc`. Answering `y` does not even buy the completions: `compinit` drops every
    insecure directory from `$fpath` before it dumps (`fpath=(${fpath:|_i_wdirs})`, straight
    after the prompt), so they were discarded either way. Nothing fixes this at the file's
    end — `compaudit`'s glob qualifiers use `-`, so they follow symlinks and see the host's
    uid, and a copy is the thing DD-043 exists not to make. So the host's completions come
    off `$fpath`, `compinit` runs plainly from `shell/qubix.zsh` as it does on the host, and
    no shell has a question to ask.
    **The hook could not have delivered the fix anyway.** It found
    `qubix-os/shell/qubix.zsh` in the container's `zshrc`, said "already carries the Qubix
    block" and stopped — so every container was pinned to the block shipped on the day it was
    created, and the documented catch-up command could not change a line of it. A container
    is not rebuilt by a rebase; that command is the only route in. The block is now delimited
    by a start and an end marker and a re-run **replaces** the range, building the result in a
    candidate file and installing it with `cat` (keeping mode, owner and SELinux label) only
    after `zsh -n` parses it.
    Rehearsed locally against a copy of the block a container is carrying today: the first run
    replaces it, the second is byte-identical, and no `/run/host` path is left on `$fpath`.
  - **Acceptance criteria:**
    - No `compinit` in a container prompts about insecure directories — including one in a
      user's own `~/.zshrc`, which runs after everything the image wires
    - Nothing under `/run/host` is put on a container's `$fpath`
    - Re-running the hook replaces the block it wrote rather than skipping the file, so a
      container that already exists receives a change made to the image
    - Two runs in a row leave the container's `zshrc` byte-identical, rehearsed before
      shipping
    - A failure anywhere in the rewrite leaves the container's `zshrc` exactly as it was
    - The one-off migration of a block with no end marker is announced and the file is kept
    - `DD-046` amends DD-045 and DD-043; `docs/shell.md` and `.agent/context/` follow,
      including what a container loses by not borrowing the host's completions
    - On the rebased image, `distrobox enter fedora-box` — after one re-run of the hook —
      reaches a shell with the Qubix prompt and no question *(open — needs a build and
      hardware)*

*Everything else implemented up to and including `9c141bf` was confirmed on the machine
on 2026-08-04.*

---

## Open

### Image variants

- [ ] **IMG-037** — Publish NVIDIA and NVIDIA+CachyOS variants
  - **Category:** Image content
  - **Depends on:** IMG-004, IMG-005, BLD-001
  - **Notes:** Requested 2026-08-30. The Fedora-kernel NVIDIA recipe remains active and
    inherits Aurora's matched NVIDIA Open stack. The combined recipe rebuilds
    Negativo17's `akmod-nvidia` against `kernel-cachyos-devel-matched`, but repeated Fedora
    44 CI failures prevented it from reaching hardware validation. BLD-002 and DD-052 now
    park that recipe outside every CI selector. Resume this task only when the combined
    build can pass cleanly without weakening its module assertions; then re-enable it in
    both workflow selector locations before returning this task to Awaiting confirmation.
  - **Acceptance criteria:**
    - `recipe-nvidia.yml` publishes `qubix-os-bluebuild-nvidia` from
      `aurora-dx-nvidia-open`, preserving its matching NVIDIA Open driver and Fedora kernel
    - `recipe-nvidia-cachyos.yml` publishes `qubix-os-bluebuild-nvidia-cachyos`, performs
      the shared CachyOS swap, rebuilds NVIDIA Open modules for that exact kernel, and
      fails the build unless the kernel modules and `nvidia-smi` are present
    - CI builds all four recipes automatically and can dispatch either NVIDIA recipe alone
    - The recipe, CI, user documentation, context cache, and a `DD-###` record explain the
      supported GPU generation, custom-kernel risk, Secure Boot caveat, and variant names
    - Both new recipes pass local YAML parsing and composition/order checks
    - Both published images boot on matching NVIDIA hardware; `nvidia-smi` works on each,
      and the combined image reports the CachyOS kernel *(open — combined publication is
      parked; needs a clean build and hardware)*

- [ ] **IMG-009** — Sign the CachyOS kernel at build time
  - **Category:** Image content
  - **Depends on:** DOC-014
  - **Notes:** The per-deployment signing DOC-014 documents is correct but has to be
    repeated after every update. Signing in CI turns that into a single `mokutil --import`
    on each machine. **Blocked on a human:** it needs an X.509 key pair whose private half
    goes in a repository secret (`SECURE_BOOT_KEY`) and whose certificate is committed.
    The private key must never reach a published layer, so the signing has to happen in a
    BlueBuild `stages:` build stage, not in the final image.
  - **Acceptance criteria:**
    - The published CachyOS image's `/usr/lib/modules/<kver>/vmlinuz` carries a PE
      signature (`sbverify --list` shows the certificate)
    - The certificate ships in the image; the private key appears in no layer, verified by
      inspecting the published image
    - `docs/variants.md` replaces the per-update signing procedure with one enrolment
    - A `DD-###` record covers the key's provenance and rotation

- [ ] **IMG-006** — Decide whether the CachyOS variant ships the CachyOS addons
  - **Category:** Image content
  - **Depends on:** IMG-005
  - **Notes:** COPR `bieszczaders/kernel-cachyos-addons` carries `cachyos-settings` (sysctl
    and udev tuning), `scx-scheds` (sched_ext schedulers), `ananicy-cpp`, and `uksmd`.
    DD-017 deliberately ships the kernel alone first; this task revisits that once the
    kernel itself is known to boot.
  - **Acceptance criteria:**
    - Each addon is assessed for what it changes and whether it conflicts with Aurora's own
      tuning
    - The outcome is recorded as a new `DD-###` (adopting or rejecting), with the recipe
      matching it

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
  - **Notes:** BLD-003 and BLD-005 replaced the upstream-only link with automatic and
    manual workflow paths; BLD-006 moved delivery from an oversized Actions artifact to
    OneDrive. GitHub CLI dispatch/watch, OneDrive download, and checksum procedures plus
    the multi-gigabyte expectation are documented. This task remains open until the
    workflow produces a OneDrive version, its measured size is recorded, and that ISO is
    booted.
  - **Acceptance criteria:**
    - `docs/usage.md` contains the exact command sequence used for this image
    - Prerequisites and approximate output size are stated
    - The procedure has been run at least once and the result booted
