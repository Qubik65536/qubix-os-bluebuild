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
any file/module changes (its context entry must change with it). `IMG-007` now tracks the
reported inherited branding across both Plymouth and Plasma login, not only a speculative
Plymouth check, and sits in **Awaiting confirmation** until the built image is checked.
`IMG-036` tracks the packaged Fcitx 5/Pinyin setup on Plasma's `Super+Space` and Niri's
`Ctrl+Space` (while Niri retains `Super+Space` for DMS) and waits there for a two-session
input check on the built image. Its first Niri check exposed Fedora's duplicate GTK module
environment; a later terminal test proved Fcitx switching worked but Niri did not invoke
its system binding. The task now tracks the Wayland correction and Fcitx's dual native
triggers, with `Ctrl+Space` deliberately absent from Niri's compositor bindings.
`IMG-040` isolates `QT_QPA_PLATFORMTHEME=kde` from DMS after the global systemd-user
environment added for KDE applications blanked Niri's shell surfaces; `IMG-041` adds the
desktop-aware Plasma/Niri Fcitx environment split; `IMG-042` restores Aurora's package-free
Plasma taskbar/application-launcher defaults; and `BRD-009` replaces the Breeze aliases
requested by compiled Kickoff/Kicker with Qubix's distributor artwork. All four wait in
Awaiting confirmation after static checks pass.
`IMG-037` added NVIDIA and NVIDIA+CachyOS recipes. The plain NVIDIA image remains active;
repeated Fedora 44 failures kept the combined driver from reaching hardware validation.
`BLD-002` therefore parks that combined recipe and removes it from automatic and manual
CI selection (DD-052). IMG-037 is back in Open until a clean combined build justifies
re-enabling publication; the retained recipe still fails closed.
`IMG-038` selects the already-installed GTK backend for Niri's file chooser because the
upstream GNOME selection needs Nautilus, which the image does not install. It waits in
Awaiting confirmation for Zed and Flatpak Chromium dialog checks on a built image (DD-053).
`BLD-003` completed the manual, signed-source, digest-pinned ISO workflow requested on
2026-08-31; `DOC-013` remains open until a OneDrive-hosted ISO is built and booted.
`BLD-004` changes only the unattended image timer to Sunday at 00:00 UTC each week;
push, pull-request, and manual image builds remain unchanged (DD-055).
`BLD-005` completed automatic all-variant ISO generation after successful default-branch
image publication, while retaining the manual single-variant path (DD-056); BLD-006 later
replaced its artifact storage.
`BLD-006` replaces the oversized Actions-artifact handoff with a GitHub OIDC-authenticated
Microsoft 365 OneDrive upload. Complete ISO/checksum pairs are retained as the newest three
versions per variant; older directories are permanently purged (DD-058).
`BLD-007` separates scheduled history (three) from push/manual history (five), maps both
manual ISO routes into the bounded push pool, and serializes whole ISO workflow runs so an
8 GB payload has a documented 192 GB steady/216 GB peak ceiling across three variants
(DD-059).
`BLD-008` indexes every retained OneDrive ISO as a per-variant GitHub Release: scheduled
builds are normal releases, push/manual builds are prereleases, the literal SHA-256 sits
beside the OneDrive link, count purges remove matching release/tag records, and generated
releases older than three months are cleaned up best-effort (DD-060).
`BLD-009` makes Entra federation failures diagnosable without tokens: the uploader logs
safe GitHub OIDC claims, captures one structured Entra rejection, and the setup guide uses
canonical owner case while explaining exact and immutable subject matching.
`BLD-010` reduces Graph upload-session creation to the canonical drive-ID route with no
optional body and expands Graph failures to status/code/message/request-ID diagnostics.
`BLD-011` adds an explicit zero-byte length to bodyless Graph POST actions because the
OneDrive for Business HTTP front end can require it even when Graph defines no JSON body.
`BLD-012` makes installer media carry a validated 25-app-plus-theme offline Flathub set
rather than assuming the installer reads Flatpak intent from the OCI image. It preserves
Qubix's no-Firefox browser policy and keeps Zed optional through `ublue-os/tap`. Its first
CI run exposed Ubuntu `umoci` 0.4.7's lack of zstd-layer support; BLD-012 is open while
the checksum-pinned `/usr/local/bin` v0.6.0 override for the action's sudo unpack awaits
an ISO rerun (DD-061).
`BRD-006` remains in Awaiting confirmation while hardware iterations converge: the menu
now overrides bootupd's one-second timeout, respects GRUB's reverse canvas order, omits its
minimum-sized progress widget, and uses protocol-v2 bounded Monaspace Krypton NF PF2 fonts.
`BRD-007` is in Awaiting confirmation after supplying and build-checking complete Breeze
Dark/KDE integration for an empty home. `BRD-008` is open again: its first ISO attempt
proved additional Lorax templates run before `/.buildstamp` exists. The replacement uses
Anaconda's pre-start `PRODBUILDPATH` overlay for the clean visual product while preserving
Lorax/OCI/boot technical identity; it needs a successful ISO rerun before returning to
Awaiting confirmation (DD-065). `IMG-043` tracks the Quickshell private-ABI mismatch:
`common-base.yml` refreshes the three Qt runtime families used by Quickshell and runs
`qs --version` as a build-time loader smoke test; it waits in Awaiting confirmation for a
rebuilt image and Niri hardware check (DD-070).
