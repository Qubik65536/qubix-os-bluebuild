# Context: `docs/`

**Covers:** `docs/**`

## Purpose

The prose documentation set, written for humans and agents alike. `docs/` answers *what*
and *why*; `.agent/` answers *what do I need to know right now to touch this file*.

## Essential details

| File | Contents | Read it when |
|---|---|---|
| `README.md` | Index of everything, plus the documentation rules | Starting anywhere |
| `overview.md` | What Qubix OS is, upstream lineage, the full delta over Aurora DX including Homebrew desktop/icon integration, goals/non-goals | You need the big picture |
| `architecture.md` | Commit → CI → image → rebase pipeline; module order and constraints; the `files/` overlay mapping; unused extension points | Changing how the image is assembled |
| `design-decisions.md` | `DD-001`…`DD-071` — every "why" in the project | Before questioning any convention |
| `recipe-reference.md` | Per-file and per-module reference for `recipes/`, incl. unused-but-available modules | Editing a recipe |
| `variants.md` | Three active standard/CachyOS/NVIDIA images plus the parked NVIDIA+CachyOS composition, requirements, switching, kernel swap and retained driver-build design | Adding a variant, or answering "which image should I run?" |
| `desktops.md` | The two sessions (Plasma, Niri), switching through Plasma Login Manager, complete Breeze Dark and DMS-safe KDE Qt integration (DD-063, DD-066), desktop-aware Fcitx environment split (DD-067), Aurora's package-free Plasma launcher defaults and Qubix panel launcher (DD-068, DD-069), the shared Qt private-ABI guard for Quickshell and the pre-login greeter (DD-070, DD-071), Homebrew application discovery/refresh (DD-062), Niri config/keybinds, default terminal/browser, portals, Simplified Chinese input, theme, scale, and troubleshooting | Touching either desktop session |
| `shell.md` | The terminal environment: what is installed, how it is delivered as system files with nothing written to `$HOME` (DD-026, DD-030), the shell half of Homebrew application discovery through `XDG_DATA_DIRS` (DD-062), why zsh is wired from the end of `/etc/zshrc` and what that costs (DD-036), per-tool notes for starship/atuin/plugins/bat/yazi/lazygit/zellij/fastfetch, the boot service that gives an existing account zsh because Aurora deletes `chsh` (DD-035), the `git clone` that installs LazyVim and the two ways to update it, what a distrobox container gets and how one already created catches up (DD-043, DD-046), and how to override any of it | Touching anything a shell reads |
| `branding.md` | Asset → image path → consumer map, including the clean visual `Qubix OS` versus technical BlueBuild identity split and Anaconda `PRODBUILDPATH` overlay (DD-065), Plasma 6.7's compiled-launcher/Breeze-alias branding boundary (DD-068), GRUB delivery/layout, Plymouth/initramfs boundary, Plasma splash, and logo-change procedure | Touching branding or product identity |
| `build-and-release.md` | Weekly OCI and automatic/manual ISO workflows, digest pinning, Anaconda pre-start product branding (DD-065), the offline Flatpak repository and pinned `umoci` shim (DD-061), permissions, signing, OneDrive retention, release indexing, capacity, and failure triage | Changing CI or debugging a build |
| `usage.md` | Install/rebase app-delivery differences, the inherited `ublue-os` Homebrew tap and Zed command, Homebrew launcher discovery/recovery plus stable version-independent cask icons (DD-062), update, rollback, verify, build/download/check an ISO, uninstall | Answering a user-facing question |
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
