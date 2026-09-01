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
| `design-decisions.md` | `DD-001`…`DD-053` — every "why" in the project | Before questioning any convention |
| `recipe-reference.md` | Per-file and per-module reference for `recipes/`, incl. unused-but-available modules | Editing a recipe |
| `variants.md` | Three active standard/CachyOS/NVIDIA images plus the parked NVIDIA+CachyOS composition, requirements, switching, kernel swap and retained driver-build design | Adding a variant, or answering "which image should I run?" |
| `desktops.md` | The two sessions (Plasma, Niri), switching, Niri config and keybinds, default terminal, default browser (DD-023), Niri's GTK file-chooser portal selection (DD-053), Simplified Chinese Fcitx/Pinyin input including native dual-trigger routing and native Wayland GTK versus XWayland fallback (DD-050), the `#56728B` colour theme and floating DMS component bar with cube launcher (DD-022, DD-025, DD-048), the pinned display scale (DD-024), and the "Niri session shows nothing" procedure, which leads with the Xwayland Video Bridge and then splits a stale panel from a dead compositor from a dead shell (IMG-012) | Touching either desktop session |
| `shell.md` | The terminal environment: what is installed, how it is delivered as system files with nothing written to `$HOME` (DD-026, DD-030), why zsh is wired from the end of `/etc/zshrc` and what that costs (DD-036), per-tool notes for starship/atuin/plugins/bat/yazi/lazygit/zellij/fastfetch, the boot service that gives an existing account zsh because Aurora deletes `chsh` (DD-035), the `git clone` that installs LazyVim and the two ways to update it, what a distrobox container gets and how one already created catches up (DD-043, DD-046), and how to override any of it | Touching anything a shell reads |
| `branding.md` | Asset → image path → consumer map, grouped by source artwork; Plymouth/initramfs boundary; Qubix-native Plasma splash plus Aurora compatibility paths; per-user splash recovery; logo-change procedure; logo green vs. the Niri accent | Touching anything under `files/system/` |
| `build-and-release.md` | CI triggers, concurrency, permissions, signing, tags, failure triage | Changing CI or debugging a build |
| `usage.md` | Install, update, rollback, verify, ISO, uninstall | Answering a user-facing question |
| `contributing.md` | The four-part contract, the task workflow incl. the three plan sections and ticking in the implementing commit (DD-044), and the commit rules (incl. the no-issue-reference rule, DD-020) | Before making any change |
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
