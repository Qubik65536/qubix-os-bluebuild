# Design Decisions

Records of **why** this project is built the way it is. Each record has a stable ID
(`DD-###`), a status, the context that forced the decision, the decision itself, and its
consequences.

## Rules for this file

- **IDs are permanent** and never reused.
- A decision is **never edited away**. To change one, add a new record and mark the old
  one `Superseded by DD-###`.
- Statuses: `Accepted`, `Superseded by DD-###`, `Deprecated`.
- When a decision is implemented by a task, cross-reference the task ID from
  [`../.agent/plan.md`](../.agent/plan.md).

---

## DD-001 — Use BlueBuild instead of a hand-written Containerfile

**Status:** Accepted

**Context.** A custom Fedora Atomic image can be produced from a plain `Containerfile`,
from Universal Blue's `startingpoint` template, or from BlueBuild's recipe format. A
hand-written `Containerfile` means owning the boilerplate for package management, flatpak
seeding, signing policy, and image metadata — all of which are the same for every custom
image and all of which are easy to get subtly wrong.

**Decision.** Define the image declaratively in `recipes/recipe.yml` and let the
BlueBuild GitHub Action render and build it.

**Consequences.**
- The interesting content of the repo is ~50 lines of YAML instead of a few hundred lines
  of shell inside `RUN` layers.
- Module semantics (`dnf`, `default-flatpaks`, `signing`, `files`) are maintained upstream
  and get fixes for free.
- The project inherits BlueBuild's schema, so editors validate the recipe via the
  `yaml-language-server` schema comment at the top of the file.
- Escape hatch retained: the `containerfile` module allows raw `RUN` snippets when no
  module fits (used once — see DD-003).
- Cost: the build depends on a third-party action and BlueBuild's release cadence.

---

## DD-002 — Base on `ublue-os/aurora-dx`, tag `beta`

**Status:** Accepted

**Context.** The base image determines the desktop, the driver/codec situation, and how
much work this repo has to do. Candidates: stock `fedora-kinoite` (clean but missing
codecs, drivers and many quality-of-life fixes), Universal Blue `aurora` (Kinoite plus
those fixes), or `aurora-dx` (Aurora plus a developer toolchain: container tooling,
IDEs, virtualisation).

The tag also matters: `latest` tracks the current stable Fedora release, `beta` tracks
the same Fedora base but receives Universal Blue's changes earlier.

**Decision.** Base on `ghcr.io/ublue-os/aurora-dx`, tag `beta`.

**Consequences.**
- KDE Plasma is the desktop, permanently. GNOME-specific work is out of scope.
- The developer tooling this project would otherwise have to install is already present,
  which is why the `dnf` module installs only two packages.
- `beta` means accepting occasional upstream breakage in exchange for earlier fixes. The
  daily rebuild (DD-009) plus `rpm-ostree` rollback makes that risk acceptable.
- The tag pins a *channel*, not a Fedora version, so a major Fedora upgrade is a
  deliberate, visible change to `image-version` — not something that happens overnight.

---

## DD-003 — Rewrite `os-release` with a `containerfile` snippet, not a static file

**Status:** Accepted

**Context.** Qubix OS needs its own `ID`, `NAME`, and `PRETTY_NAME`. The obvious approach
is to ship a complete `/usr/lib/os-release` through the `files` module. That fails for two
reasons: it would discard every other field upstream sets (`VERSION_ID`, `VARIANT`,
`OSTREE_VERSION`, bug/support URLs, and Universal Blue's `IMAGE_VERSION`), and the desired
`PRETTY_NAME` embeds the upstream `IMAGE_VERSION`, which is not known until build time.
The `files` module copies bytes and cannot template.

**Decision.** Patch the file in place with `sed` inside a `containerfile` module snippet,
reading `IMAGE_VERSION` out of the file first and interpolating it back into
`PRETTY_NAME`.

**Consequences.**
- Only the three intended fields change; everything upstream sets survives.
- `PRETTY_NAME` carries the upstream version, e.g.
  `Qubix OS (BlueBuild Image, Version: 42.20260505)`, so the base version is visible in
  `neofetch`, KDE's About page, and bug reports.
- The snippet must run **after** any module that can regenerate `os-release`; ordering is
  documented in [`architecture.md`](architecture.md).
- The `sed` patterns are anchored (`^ID=`) so they cannot accidentally match
  `VERSION_ID=` or similar.
- Cost: one piece of imperative shell in an otherwise declarative recipe. Accepted because
  no declarative alternative preserves upstream fields.

---

## DD-004 — Rebrand by overwriting upstream asset paths

**Status:** Accepted

**Context.** Distro branding on a KDE/Fedora system is not centralised. Plymouth reads
`/usr/share/plymouth/themes/spinner/watermark.png`; KDE's "About this system" reads a path
named in `kcm-about-distrorc`; the Plasma splash reads an image inside the look-and-feel
package directory; various applications read `/usr/share/pixmaps/fedora-logo*.png` or
`/usr/share/icons/hicolor/scalable/distributor-logo.svg`. Doing this "properly" would mean
forking Aurora's look-and-feel package and a Plymouth theme, then maintaining both.

**Decision.** Ship replacement files at the exact upstream paths via the `files` module,
including paths whose names mention Fedora or Aurora.

**Consequences.**
- Branding is a pure data change — no packaging, no theme fork, no scripts.
- Files in this repo are **intentionally misnamed** relative to their content:
  `fedora-logo.png` contains the Qubix banner, and the Plasma splash lives under
  `dev.getaurora.aurora.desktop/`. This looks like a mistake and is not. The complete map
  is in [`branding.md`](branding.md); read it before renaming anything.
- Risk: if upstream moves a path, the override silently stops applying and the upstream
  logo reappears. Detection is visual, on rebase. Accepted as low-impact.

---

## DD-005 — Duplicate identical assets rather than symlink or dedupe

**Status:** Accepted

**Context.** Following DD-004, the same source artwork ends up needed at several paths.
Today four files are byte-identical copies of one 512×512 logo, two are copies of one
banner SVG, two are copies of one 1600×450 banner PNG, and two are copies of one 128×36
watermark. Symlinks would save roughly 400 KB in the repo and the image.

**Decision.** Commit real, duplicated files.

**Consequences.**
- Each consumer's path can be re-pointed at different artwork later without untangling a
  symlink web — the paths are independent by construction.
- Symlinks across an OSTree overlay and an OCI layer add failure modes (dangling links,
  `/usr` merge behaviour) for a saving that is negligible next to a multi-gigabyte
  desktop image.
- Cost: changing the logo means updating several files. `branding.md` groups them by
  source artwork so the set is obvious, and the checksum table there makes drift
  detectable.

---

## DD-006 — Firefox as a Flatpak, not an RPM

**Status:** Accepted

**Context.** Aurora ships Firefox as a layered RPM. On an image-based system, layered
browser RPMs are updated only when the whole image is rebased, and they cannot be updated
independently of the OS. Flatpak Firefox updates on its own schedule and is sandboxed.

**Decision.** Remove `firefox` and `firefox-langpacks` in the `dnf` module; install
`org.mozilla.firefox` from Flathub via `default-flatpaks`.

**Consequences.**
- Browser security updates no longer wait for an OS rebuild.
- `firefox-langpacks` must be removed explicitly — it is a dependency that `dnf` does not
  drop automatically with the main package. This is noted inline in `recipe.yml` because
  it is the kind of thing that gets "cleaned up" by mistake.
- Ordering constraint: the flatpak install must come after the RPM removal.
- Flathub becomes a required remote for a working system; both system and user scopes are
  configured so user-scope installs also work out of the box.

---

## DD-007 — Minimal package additions, `starship` from COPR

**Status:** Accepted

**Context.** Aurora DX already carries the development toolchain, so almost nothing needs
adding. The two gaps are a lightweight terminal editor and a shell prompt. `starship` is
not in Fedora's main repositories; the maintainer-run COPR `atim/starship` is the usual
source.

**Decision.** Install `micro` from Fedora repos and `starship` from COPR `atim/starship`.
Add no other packages without a recorded reason.

**Consequences.**
- The image delta stays small and auditable, matching the "stay thin" goal in
  [`overview.md`](overview.md).
- One third-party COPR is trusted. COPRs are user-controlled and can disappear or change
  ownership; if `atim/starship` breaks, the fallback is vendoring the release binary via a
  script module.
- Any future package addition should be justified here or in `recipe.yml` comments —
  "why not upstream / why not a flatpak" is the question to answer.

---

## DD-008 — Sign images with Sigstore cosign

**Status:** Accepted

**Context.** A rebase pulls an entire operating system from a container registry. Without
verification, a registry compromise or a typo in an image name is a full system
compromise. BlueBuild supports cosign signing with a keypair.

**Decision.** Sign every published image. Commit `cosign.pub`; keep the private key only
in the `SIGNING_SECRET` GitHub Actions secret; install the verification policy into the
image itself via the `signing` module.

**Consequences.**
- Users can verify with `cosign verify --key cosign.pub ghcr.io/qubik65536/qubix-os-bluebuild`.
- Because the policy ships *inside* the image, first-time installs need the documented
  two-step rebase: unsigned first (to obtain the policy), then signed. This is why
  [`usage.md`](usage.md) has two rebase commands rather than one.
- `cosign.key` and `cosign.private` are gitignored. Committing either burns the key and
  requires regenerating and re-signing.
- Key rotation invalidates verification for existing installs until they rebase.

---

## DD-009 — Rebuild daily at 06:00 UTC

**Status:** Accepted

**Context.** The image is a thin layer over Aurora DX. When upstream publishes a new
Aurora build with security fixes, this image does not receive them until it is rebuilt.
Universal Blue's own images begin building shortly before 06:00 UTC.

**Decision.** Schedule a build at `00 06 * * *`, ~20 minutes after upstream starts, in
addition to building on push, pull request, and manual dispatch.

**Consequences.**
- Users are at most ~24 hours behind upstream security updates.
- The 20-minute offset is a heuristic, not a guarantee — if upstream runs long, that day's
  build layers onto the previous Aurora image. Harmless: the next day corrects it.
- Builds are serialised by the workflow's `concurrency` group with
  `cancel-in-progress: true`, so a push during a scheduled build cancels the older run
  rather than queueing.

---

## DD-010 — Documentation changes must not trigger rebuilds

**Status:** Accepted

**Context.** This project mandates heavy documentation (DD-011). Every documentation
commit triggering a full multi-gigabyte image build would waste CI minutes and produce
images identical to the previous one but with new digests.

**Decision.** `paths-ignore: "**.md"` on the `push` trigger in `build.yml`.

**Consequences.**
- Documentation and image builds are decoupled; docs can be committed freely.
- Caveat: a commit touching *both* a `.md` file and the recipe still builds — `paths-ignore`
  skips only when **every** changed path matches.
- Caveat: this applies to `push` only. Pull requests still build regardless, which is
  correct — PR builds validate the recipe.
- Consequence for agents: a docs-only change can never be "verified by CI". Say so rather
  than implying a build validated it.

---

## DD-011 — Documentation, plan, and context cache are part of the deliverable

**Status:** Accepted

**Context.** This repository is small but its content is almost entirely *conventions*:
which path overrides which upstream asset, why a file is deliberately misnamed, why a
package is removed and reinstalled as a flatpak. None of that is recoverable from the
files themselves. Work is done across sessions, by humans and by several different AI
agents, none of which retain memory between sessions.

**Decision.** Adopt a four-part documentation contract, mandatory for every contributor,
human or agent:

1. **`docs/`** — prose documentation, including this decision log.
2. **`.agent/plan.md`** — every requirement becomes a task with an ID, category,
   dependencies, and acceptance criteria; a task is done only when its criteria are met.
3. **`.agent/context/`** — a context cache with one brief entry per file/module, so an
   agent can orient without reading the whole repository.
4. **Code comments** — every major section of every config, script, and workflow.

**Decision on agent instruction files.** Exactly one file — `AGENTS.md` — contains the
instructions. `CLAUDE.md` and `.github/copilot-instructions.md` are pointers containing no
content of their own.

**Consequences.**
- Duplicated instructions cannot drift, because there are none. `AGENTS.md` is the only
  place to edit.
- Supporting a new agent means adding a pointer file, nothing else.
- Reading `AGENTS.md`, `plan.md`, and the relevant context-cache entries is a required
  first step of every session, and updating them is a required last step.
- A compliance marker (`0x4A0000`) is embedded in `AGENTS.md`; agents must print it at the
  end of every completed prompt. Its absence signals the instructions were not read.
- Cost: real overhead per change. Accepted deliberately — the cost of re-deriving these
  conventions, repeatedly, across sessions and agents, is higher.

---

## DD-012 — WezTerm as the default terminal, from WezTerm's own COPR

**Status:** Accepted

**Implements:** `IMG-001`

**Context.** One terminal emulator should be the default across every session on the
machine. WezTerm is **not packaged in Fedora** — not in the main repositories, not in
RPM Fusion. The available sources are Flathub (`org.wezfurlong.wezterm`) and the COPR
`wezfurlong/wezterm-nightly`, which is run by WezTerm's own author and builds from the
project's release pipeline.

A Flatpak is the wrong shape for a *default terminal*: it is what other applications
shell out to. "Open Terminal Here", `$TERMINAL -e …`, and a compositor keybind all expect
a plain executable on `$PATH` that inherits the caller's working directory. Wrapping every
one of those in `flatpak run` — from inside a sandbox that does not share the host
filesystem or shell environment — defeats the purpose. This is the opposite situation from
Firefox (DD-006), which is a leaf application nothing else invokes.

**Decision.** Layer the `wezterm` RPM from COPR `wezfurlong/wezterm-nightly`. Point the
two default-terminal mechanisms at it with configuration files, adding nothing and
removing nothing else:

| File | Consumer | Key |
|---|---|---|
| `/etc/xdg/kdeglobals` | KDE Frameworks (`KTerminalLauncherJob`) | `[General] TerminalApplication=wezterm` |
| `/usr/lib/environment.d/50-qubix-terminal.conf` | systemd user manager → every session | `TERMINAL=wezterm` |

**Consequences.**
- Konsole and every other KDE component stay installed. Only the *default* changes; a
  user who prefers Konsole changes one setting.
- `TerminalService` is deliberately **not** set. `KTerminalLauncherJob` prefers that key
  and appends `-e <command>` to the named desktop entry's `Exec`. WezTerm's entry is
  `Exec=wezterm start --cwd .`, and `-e` is an alias for the `start` *subcommand* rather
  than a flag of it, so `wezterm start --cwd . -e ls` fails to parse. With
  `TerminalApplication` alone the launcher produces `wezterm -e ls`, which is correct.
- `/etc/xdg/kdeglobals` is a **cascade fragment**, not a replacement. KConfig merges every
  `kdeglobals` on `$XDG_CONFIG_DIRS` key by key, so Fedora's fonts, icon theme and
  look-and-feel keep coming from `kde-settings`. This is also why `/etc` is used rather
  than `/usr` (see DD-011's preference): the only `/usr` directory on the KDE cascade is
  `/usr/share/kde-settings/kde-profile/default/xdg/`, where `kdeglobals` already exists —
  writing there would overwrite Fedora's defaults wholesale.
- The COPR builds nightly, so the version string is a datestamp
  (e.g. `20260731_083216_d69264df`) and the image tracks WezTerm's `main` branch. Accepted:
  the alternative is no Fedora-native WezTerm at all. If a build breaks, the fallback is
  pinning to an older COPR build or switching to the Flatpak.
- Second third-party COPR trusted, after `atim/starship` (DD-007). This one is upstream's
  own, which is the best available provenance short of Fedora proper.
