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
    - The user confirms the rebased image reaches a login screen — **confirmed 2026-08-01**,
      the machine now boots to the greeter and logs in

---

## Open

### Desktop sessions

- [ ] **IMG-012** — Stop the Xwayland Video Bridge taking over the Niri session
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
      *(open — needs a build and hardware)*

- [ ] **IMG-013** — Give the Xwayland Video Bridge a start/stop control in Niri
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
      points *(open — needs a build and hardware; the overlay carries mode 100755, but
      nothing here verifies what the `files` module produced)*

- [ ] **BRD-002** — Give the Niri session a theme built from `#56728B`
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

- [ ] **IMG-007** — Confirm the Plymouth watermark survives without an `initramfs` module
  - **Category:** Image content
  - **Depends on:** —
  - **Notes:** BlueBuild's `initramfs` module exists because Plymouth theming lives in the
    initramfs. `recipe.yml` overrides `spinner/watermark.png` (DD-004) but never
    regenerates it, so the boot splash may still show Aurora's. The CachyOS variant
    regenerates the initramfs anyway (IMG-005), which is a useful comparison.
  - **Acceptance criteria:**
    - The boot splash of the standard image is checked on real hardware after a rebase
    - If the watermark does not apply, `recipe.yml` gains `- type: initramfs` before
      `signing`, with a note in `docs/branding.md`

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
