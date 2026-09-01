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

**Status:** Superseded by [DD-018](#dd-018--track-the-latest-channel-not-beta) *(the tag
only — the choice of `aurora-dx` as the base still stands)*

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
  *(Narrowed by DD-013: Plasma remains the inherited desktop and is never removed, but it
  is no longer the only session installed.)*
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

**Status:** Superseded by [DD-023](#dd-023--ungoogled-chromium-as-the-default-browser-firefox-not-shipped)
*(the browser only — "the browser is a Flatpak, never a layered RPM" is the part that
survives, and the `firefox`/`firefox-langpacks` removal stays for the reason below)*

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

**Status:** Superseded by DD-055

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

---

## DD-013 — Add Niri as a second session; never remove KDE Plasma

**Status:** Accepted

**Implements:** `IMG-002`

**Narrows:** DD-002's consequence "KDE Plasma is the desktop, permanently"

**Context.** A scrollable-tiling Wayland compositor and a full traditional desktop are
good at different things. Wanting both is not the same as wanting to migrate. The obvious
failure mode when adding a compositor to a KDE image is to start pruning "redundant" KDE
pieces — the Plasma panel, KWin, Konsole, the KDE portal — which quietly makes the Plasma
session worse in ways that only surface weeks later, on hardware you no longer have in
front of you.

Fedora packages `niri` in its main repositories, and the RPM installs
`/usr/share/wayland-sessions/niri.desktop`. SDDM builds its session list from that
directory, so a second session needs no display-manager configuration at all.

**Decision.** Install `niri` as a **purely additive** layer. Both sessions are present at
all times and the choice is made per login in SDDM. No KDE Plasma package is removed,
masked, or reconfigured. Where a default has to name one thing (the terminal, DD-012), the
default is changed for both sessions rather than one session being special-cased.

**Consequences.**
- Session switching is a login-screen choice, remembered per user. Documented in
  [`desktops.md`](desktops.md).
- The image grows by niri plus its weak dependencies: `waybar`, `fuzzel`, `swaylock`,
  `gnome-keyring`, `wireplumber`, `xdg-desktop-portal-gnome`, `xdg-desktop-portal-gtk`,
  and the hard dependency `xwayland-satellite`. Weak dependencies are left enabled
  deliberately: a bare compositor with no panel, launcher, or locker is not a session
  anyone can log into.
- The GTK and GNOME portals do **not** affect Plasma. Portal selection is per-desktop via
  `$XDG_CURRENT_DESKTOP` and each desktop's `*-portals.conf`.
- `brightnessctl` is added for niri's backlight keys. Plasma has its own power management
  and does not need it; the package is ~50 KB.
  *(Reversed by DD-015: DankMaterialShell handles brightness natively, so the package was
  dropped again.)*
- Xwayland needs no configuration: since niri 25.08 the compositor exports `$DISPLAY` and
  spawns `xwayland-satellite` on demand.
- Desktop *state* is not shared between the sessions — panels, wallpaper, and shortcuts
  live in unrelated places. This is inherent, not a defect to fix.
- Cost: two desktops to keep working instead of one, and upstream niri moves fast. The
  mitigation is that neither can break the other — they share no configuration.

---

## DD-014 — Ship the Niri config as a system default in `/etc/niri/config.kdl`

**Status:** Accepted

**Implements:** `IMG-002`

**Context.** Niri's built-in default config is a bare compositor: no panel, and a terminal
keybind pointing at whatever the upstream default happens to be. A first login on a fresh
install should land in a session that works. Niri resolves its config as
`$XDG_CONFIG_HOME/niri/config.kdl`, falling back to `/etc/niri/config.kdl`; if **neither**
exists, it writes its own 600-line annotated default into the user's home directory.

There is no `/usr` path in that search order. This project otherwise prefers `/usr`,
because `/etc` is three-way merged across updates while `/usr` is replaced wholesale.

**Decision.** Ship a short, commented `/etc/niri/config.kdl` as the system default. Do not
attempt to seed a per-user config.

**Consequences.**
- A first login gets a working session with the project's defaults, including WezTerm as
  the terminal (DD-012), without any per-user setup step.
- **Because the system file exists, niri no longer auto-creates
  `~/.config/niri/config.kdl`.** Customising means copying the system file first. This is
  a real change in behaviour for anyone who knows niri's normal bootstrap, so it is called
  out in [`desktops.md`](desktops.md) and in the file's own header comment.
- `/etc` is used against the general preference because niri offers no `/usr` alternative.
  Practical effect: a user who edits `/etc/niri/config.kdl` in place keeps their edits
  across rebases, and updates to the shipped version are three-way merged. Editing
  `~/.config/niri/config.kdl` instead sidesteps that entirely and is what the docs
  recommend.
- The file is kept deliberately short rather than being a copy of niri's annotated
  default. Unset options keep niri's built-in defaults, so the file stays readable and
  does not silently pin behaviour that upstream later improves.

---

## DD-015 — DankMaterialShell as the Niri shell, started only under Niri

**Status:** Accepted

**Implements:** `IMG-003`

**Context.** Niri is a compositor, not a desktop. On its own it has no panel, launcher,
notification daemon, lock screen, volume OSD, or power menu. The traditional answer is to
assemble those from separate projects — waybar, fuzzel, mako, swaylock, wlogout — each
with its own configuration format and its own idea of theming.
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) is a single
Quickshell-based shell that provides all of them, is built for niri specifically, and is
packaged for Fedora by its authors.

Getting it to run only in the right session is the interesting part. DMS ships
`dms.service` with `WantedBy=graphical-session.target`. Enabling that unit in the image
would start the shell in **every** graphical session, including KDE Plasma — producing two
panels, two notification daemons competing for the
`org.freedesktop.Notifications` bus name, and two lock screens.

**Decision.** Install `dms` and leave its unit **disabled**. Pull it in from niri's own
unit with a `/usr` drop-in:

```ini
# /usr/lib/systemd/user/niri.service.d/50-qubix-dms.conf
[Unit]
Wants=dms.service
```

**Consequences.**
- DMS starts with the Niri session and with nothing else. A Plasma login is byte-for-byte
  the session it was before this change — which is the invariant DD-013 exists to protect.
- This is the image-wide equivalent of upstream's documented per-user setup step,
  `systemctl --user add-wants niri.service dms`. Doing it as a drop-in in `/usr` means no
  user has to run anything, and a user who disagrees overrides it in
  `~/.config/systemd/user/niri.service.d/`.
- **Two COPRs are needed**, not one: `avengemedia/dms` carries the shell, and its runtime
  dependencies (`quickshell`, `dgop`, `matugen`, `material-symbols-fonts`, `cliphist`)
  live in the companion `avengemedia/danklinux`. Enabling only the first leaves `dms`
  uninstallable. That coupling is declared in the COPR's own metadata and is easy to miss.
- The fonts DMS renders with are **not** hard RPM dependencies, so they are installed
  explicitly. Without `material-symbols-fonts` every icon in the shell is a missing-glyph
  box — a failure that looks like a theming bug rather than a missing package.
- `brightnessctl`, added in IMG-002 for the interim config's backlight keys, is removed
  again: DMS handles brightness natively through logind, sysfs, and DDC, so the package no
  longer has a consumer. DD-007 requires every package to have a reason.
- The keybinds in `/etc/niri/config.kdl` follow upstream DMS's recommended binds
  (`dms ipc call …`), so they stay recognisable against upstream's documentation.
- niri's own weak dependencies (`waybar`, `fuzzel`, `swaylock`) remain installed but
  unused by the shipped config. They are left in place as a fallback: if DMS fails to
  start, a user can still bind them by hand. Removing them would also mean fighting the
  `niri` RPM's dependency set for no real gain.
- Dynamic theming: DMS's matugen writes `~/.config/niri/dms/colors.kdl`, which the shipped
  config includes with `optional=true` at the **end** of the file. Niri includes are
  positional and override what came before them, so the position is load-bearing.
- Cost: a third-party COPR pair with a fast-moving upstream, now on the critical path for
  one of the two sessions. Plasma is unaffected if it breaks, which bounds the blast
  radius.

---

## DD-016 — One recipe per variant, composed from shared module files

**Status:** Accepted

**Implements:** `IMG-004`

**Context.** Publishing a second image — one that differs in a single dimension, such as
the kernel (DD-017) — needs a second recipe, and BlueBuild's matrix is a list of recipe
files. The obvious move — copy `recipe.yml` to
`recipe-cachyos.yml` and edit two lines — creates two files that must be kept identical
forever, in a repository whose stated goal is a delta small enough to read in one sitting.
The failure mode is silent: a package added to one recipe and not the other produces two
images that differ in a way nobody notices until something is missing on one of them.

BlueBuild's `from-file:` includes a module list from another file under `recipes/`, so the
shared part can exist once.

**Decision.** Split the modules into shared files and compose them per variant:

| File | Contents | Included by |
|---|---|---|
| `recipes/common-base.yml` | `files`, `dnf`, `default-flatpaks` — everything that makes an image Qubix OS | every recipe |
| `recipes/common-identity.yml` | The `os-release` rewrite (DD-003) | every recipe |
| `recipes/common-kernel-cachyos.yml` | COPR + kernel swap (DD-017) | `recipe-cachyos.yml` |
| `recipes/recipe*.yml` | Identity keys, the `from-file:` composition, and whatever is variant-specific | — (built directly) |

Naming is the contract: **`recipe*.yml` is built, `common-*.yml` is included.** The build
matrix names recipe files explicitly, so a shared file can never be built by accident.

**Consequences.**
- The rendered module order for `recipe.yml` is unchanged — `files`, `dnf`,
  `default-flatpaks`, `containerfile`, `signing`. The split is a refactor, not a
  behaviour change.
- A change meant for every image goes in `common-base.yml`. A change meant for one image
  goes in that recipe. There is no third place for it to hide.
- Ordering constraints now cross file boundaries. `common-identity.yml` is a separate file
  from `common-base.yml` precisely because of one: it has to run after *everything* that
  can regenerate `os-release`, which for a kernel-swapping variant means after the swap.
  A recipe therefore composes three or four small blocks in a documented order rather than
  including one big one.
- Variant-specific values are not parameterised — `from-file:` takes no arguments. Where a
  variant needs a different value (the CachyOS variant's `PRETTY_NAME`), it rewrites the
  field again afterwards instead of the shared file growing a knob. Two writes of one
  field, in exchange for shared files that never branch.
- `signing` stays in each recipe rather than in a shared file, so "signing is last" remains
  visible in the file that is actually built.

---

## DD-017 — Ship a CachyOS-kernel variant as a separate image, not an option

**Status:** Accepted

**Implements:** `IMG-005`

**Context.** The CachyOS kernel is a patched Linux kernel with the BORE scheduler as
default, sched_ext support, BBRv3, backports from `linux-next`, and desktop-latency
patches. CachyOS maintains an official Fedora port in COPR
`bieszczaders/kernel-cachyos` (`kernel-cachyos`, `-lts`, `-rt`, `-server`).

It is not a free upgrade. The default kernel is built for **x86-64-v3** and produces an
unbootable system on older CPUs; the COPR's own instructions say so. It is not signed by
Fedora's Secure Boot key. It is a third-party kernel, on a rolling release cadence, with
no Fedora QA behind it — which is a different risk class from a third-party terminal
emulator (DD-012). A bad kernel does not degrade the desktop; it fails to boot.

An image-based OS makes "try it, roll back if it breaks" cheap, but only if the thing you
roll back *to* still exists.

**Decision.** Publish it as a **second image**, `qubix-os-bluebuild-cachyos`, built from
the same shared modules as the standard image (DD-016) and differing only in the kernel
and in `PRETTY_NAME`. The standard image keeps Fedora's kernel and is unaffected.

The swap itself is a `containerfile` snippet, not `dnf` module fields:

```sh
dnf5 -y remove --no-autoremove kernel kernel-core kernel-modules \
                               kernel-modules-core kernel-modules-extra
rm -rf "/usr/lib/modules/${STOCK_KVER}"
dnf5 -y install kernel-cachyos kernel-cachyos-core kernel-cachyos-modules
```

followed by `depmod` and BlueBuild's `initramfs` module.

**Consequences.**
- Choosing a kernel is a rebase, and the fallback is another published image rather than a
  local deployment that may be garbage-collected. `docs/variants.md` documents switching in
  both directions.
- **The removal must precede the installation, in that order.** `kernel-cachyos-core`
  declares `Provides: kernel` and `Provides: kernel-core-uname-r`, so
  `dnf5 remove kernel` *after* the swap would take the new kernel back out. Doing it in
  the documented order removes packages that do not exist yet from consideration entirely.
- The stock kernel's directory under `/usr/lib/modules` is deleted explicitly. RPM removal
  leaves generated files behind (`initramfs.img`, `modules.dep`), and a bootc image with
  two module directories is ambiguous about which kernel it boots. The snippet asserts
  exactly one directory remains, with a `vmlinuz` in it, so the build fails at the swap
  rather than producing an image that fails to boot.
- The initramfs is regenerated by the `initramfs` module because nothing else will:
  `rpm-ostree`'s kernel handling runs on a client, not in a container build.
- **The kernel install must skip RPM scriptlets** (`--setopt=tsflags=noscripts`), and the
  build must then run `depmod` itself. Found by the first CI run, which failed:
  `kernel-cachyos-core`'s `%posttrans` calls `kernel-install`, a ublue base image hooks
  that with `05-rpmostree.install` → `dracut`, and dracut aborts with `modules.dep is
  missing. Did you run depmod?` — the CachyOS RPMs ship no `modules.dep`, and in a
  container nothing has generated one. The scriptlet failure fails the whole transaction.
  Skipping scriptlets and doing the one part that matters by hand is the same shape as
  every other Fedora Atomic kernel swap in the wild.
- Removing `kernel-core` removes **everything that depends on it**, which on Aurora DX is
  more than kernel modules: the first build lost `libguestfs`, `libguestfs-appliance`,
  `libguestfs-xfs`, `guestfs-tools`, `virt-v2v`, and `virtualbox-guest-additions` as well.
  Those declare a plain `Requires: kernel`, which `kernel-cachyos-core` *provides*, so
  they are explicitly reinstalled after the swap. A variant that quietly dropped the
  virtualisation tooling out of an image whose whole point is developer tooling (DD-002)
  would not be "the same image with a different kernel".
- `kernel-devel-matched` goes out with Fedora's kernel and `kernel-cachyos-devel-matched`
  comes in as its counterpart, so `akmods` still has headers to build against.
- The build logs the full set of packages the removal took (a `comm` of the package list
  before and after). Anything in that list that is not explicitly reinstalled is gone from
  this variant — the log is the alarm if Aurora's dependency graph changes.
- **x86-64-v3 is a hardware requirement of this variant.** Check before rebasing:
  `/lib64/ld-linux-x86-64.so.2 --help | grep 'x86-64-v3'`. `-lts` and `-server` build for
  x86-64-v2 and are the fallback if that requirement ever becomes a problem.
- **Secure Boot must be off, or the kernel signed with a key the user owns.** The COPR
  kernel is not signed *at all*: the published `vmlinuz`'s PE certificate table is empty
  and the CachyOS spec has no signing step, so there is no vendor certificate anyone could
  enrol. Under Secure Boot, shim refuses to load it. This repository's cosign key signs the
  *image* and is checked by `rpm-ostree` at rebase time, not by firmware at boot — a
  different mechanism entirely (DD-008), and one that does not help here.
  The variant therefore ships `sbsigntools` and `mokutil`, and
  [`variants.md`](variants.md) documents enrolling a Machine Owner Key and signing each
  deployment's `/boot` kernel copy. That copy is the only one a user can sign: the kernel
  inside the ostree deployment is read-only and checksummed, so the work repeats after
  every update. Signing in CI would reduce it to a single enrolment per machine, which is
  `IMG-009` — it needs a private key in a repository secret and a build stage that keeps
  that key out of every published layer, so it is a deliberate follow-up rather than part
  of this record.
- Secure Boot on this variant does **not** imply lockdown: the kernel is built with
  `CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT` and `CONFIG_MODULE_SIG_FORCE` unset. Locally built
  `akmods` modules keep loading. Worth knowing before assuming the security properties of
  a Fedora kernel carry over.
- Any prebuilt out-of-tree module (`kmod-*`) inherited from Aurora is removed with the
  stock kernel and **cannot** be restored: those RPMs depend on the exact
  `kernel-uname-r` that is going away, so reinstalling one would pull Fedora's kernel back
  in. On the first build this meant `kmod-v4l2loopback` and `kmod-xone` (with their
  userspace halves). The build log lists them before the swap, so a regression is
  traceable.
- CachyOS dropped prebuilt NVIDIA drivers in February 2026. Proprietary NVIDIA users
  should stay on the standard image or expect to build drivers themselves.
- The kernel COPR stays enabled in the shipped image, like every other COPR this project
  uses, so the daily rebuild follows CachyOS's kernel releases. The kernel version can
  therefore change from one build to the next, with no pin — the same trade already
  accepted for `wezterm` (DD-012), at higher stakes.
- The companion `kernel-cachyos-addons` COPR (`cachyos-settings`, `scx-scheds`,
  `ananicy-cpp`, `uksmd`) is **not** enabled. The kernel is one change to evaluate; system
  tuning that overlaps Aurora's own is another. Tracked as `IMG-006`.
- CI cost roughly doubles: two images, built on every push and every night.

---

## DD-018 — Track the `latest` channel, not `beta`

**Status:** Accepted — supersedes the tag half of [DD-002](#dd-002--base-on-ublue-osaurora-dx-tag-beta)

**Context.** DD-002 chose the `beta` tag of `aurora-dx`, accepting "occasional upstream
breakage in exchange for earlier fixes" on the grounds that the daily rebuild and
`rpm-ostree` rollback made the risk acceptable.

That reasoning did not survive contact with hardware. On an AMD ThinkPad T14 the standard
image reached the Plymouth spinner and then went blank, with no login screen, having booted
to a working desktop a month earlier. What the machine showed:

- The kernel and console are fine. From a text console, `systemctl start
  plasmalogin.service` blanks the screen on demand, and stopping the service does not give
  the console back. The greeter's compositor **hangs holding the DRM master** instead of
  crashing — which is why nothing is logged, `Ctrl+Alt+F2` does nothing, and
  `Ctrl+Alt+Del` still reboots.
- Nothing in this repository is implicated. It configures no display manager, no PAM stack,
  no Plymouth theme beyond a watermark image, and no graphics settings. `dms` was the one
  plausible route, because `plasmalogin` runs its greeter as a systemd *user* session and a
  globally enabled `dms.service` would start inside it — but the unit is `disabled` on the
  machine, exactly as DD-015 intends.

`beta` tracks the *next* Fedora, so the machine was running a pre-release kernel and Mesa
that most AMD users are not. An `amdgpu` hang on a compositor's first frame is precisely
the class of regression that channel carries.

The rollback argument in DD-002 also assumed the wrong failure mode. Rollback works when a
bad update is *noticed*; it does not help when the failure is a black screen with no
console, no SSH, and no journal — the failing boots died before `systemd-journal-flush`
persisted anything, so the evidence needed to diagnose them was destroyed by the failure
itself.

**Decision.** Set `image-version: latest` in both recipes.

**Consequences.**
- The image tracks the current *stable* Fedora. Upstream fixes arrive later; so do
  upstream regressions, after a wider set of machines has hit them first.
- Both variants must keep the same channel. They are meant to differ **only** in the
  kernel, so `recipe.yml` and `recipe-cachyos.yml` change together.
- The daily rebuild (DD-009) is unchanged and still picks up stable updates within a day.
- Moving *back* to `beta` remains a one-line change if this project ever wants early access
  again — ideally on a variant, so the machine that needs to boot is not the machine
  testing the pre-release stack.
- **This fix is probable, not proven.** No kernel log was recovered, for the reason above.
  If the blank screen survives the rebase, the base image is exonerated and the fault is
  the hardware or a regression already in stable; the next step is then to bisect against
  `ghcr.io/ublue-os/aurora-dx:latest` directly, with this repository out of the picture.

---

## DD-019 — Hide the Xwayland Video Bridge in Niri, rather than stopping it

**Status:** Superseded by [DD-021](#dd-021--stop-the-xwayland-video-bridge-in-niri-hiding-it-was-not-enough)
*(the window rule stays — what did not survive is the claim that hiding it is sufficient)*

**Implements:** `IMG-012`

**Context.** A fresh Niri login showed an empty desktop: no wallpaper, no
DankMaterialShell bar, and no application windows. Niri itself was healthy throughout —
keybinds worked, DMS's IPC answered, and hammering a keybind or switching workspaces
eventually brought the whole session up, correct and functional from then on.

The cause is `xwaylandvideobridge` — the "Wayland to X Recording bridge", an Aurora/KDE
component that republishes a Wayland screen capture as an X11 window so X11 applications
(Discord, Zoom, OBS) can record the screen. It ships an XDG autostart entry, and
`niri.service` pulls in `xdg-desktop-autostart.target`, so it starts under Niri as well as
under Plasma.

The bridge is **designed to be invisible** and delegates that to the compositor: KDE ships
a KWin rule that hides it. Niri has no equivalent, so the window simply opens
([niri#2367](https://github.com/niri-wm/niri/issues/2367)). It takes focus at login and
covers the session, which is why the desktop looked dead rather than merely cluttered.

Three options:

| Option | Cost |
|---|---|
| Remove the package | Breaks X11 screen sharing in **both** sessions, and violates DD-013 |
| Mask its autostart entry under Niri | Breaks X11 screen sharing in the Niri session only; a `/etc/xdg/autostart/` override that has to track the upstream file |
| Hide the window with a niri window rule | The bridge keeps working; the rule lives in a file this project already owns |

**Decision.** Add a `window-rule` to `/etc/niri/config.kdl` matching
`app-id=^xwaylandvideobridge$` that opens the window floating, unfocused, non-fullscreen,
one logical pixel across, in a corner, at zero opacity. This is niri's equivalent of the
KWin rule KDE ships, and it is what upstream's design expects a compositor to provide.

**Consequences.**
- X11 screen sharing keeps working in the Niri session. Nothing is removed or disabled, so
  DD-013 holds.
- `open-fullscreen false` is deliberate belt-and-braces: a fullscreen window in niri
  renders *above* the top layer, which would hide the DMS bar as well as other windows.
- The rule is keyed on an app-id owned by an upstream KDE component. If that app-id ever
  changes, the rule silently stops matching and the blank window returns. It is worth
  re-checking when Aurora makes a major Plasma jump.
- This is the general shape of the problem, not a one-off: anything KDE that XDG-autostarts
  and expects a KWin rule to tidy it up will misbehave under Niri. Where that recurs, the
  answer is another window rule in the same file, not pruning KDE packages.
- **Fix is reasoned, not yet verified on hardware.** There is no local build; it is
  confirmed when a Niri login on the rebased image comes up clean. `IMG-012` stays open
  until then.

---

## DD-020 — Commit messages never reference an issue or pull request

**Status:** Accepted

**Implements:** `AGT-005`

**Context.** Commits here explain themselves at length, and part of that is provenance:
the Xwayland Video Bridge fix is only understandable next to the upstream niri issue that
describes the behaviour. The obvious way to record that is to put the issue reference in
the commit message.

But GitHub treats an issue reference as an **action, not as text**. Any `#123`,
`owner/repo#123`, `GH-123`, or issue/PR URL in a pushed commit message posts a
cross-reference event into that issue's timeline, and the timeline is a notification
channel: the maintainers, and every person who commented on or subscribed to the issue,
are told that something happened on their bug. What actually happened is a commit in a
one-person image-build repository, which is of no use to any of them. It is an unsolicited
ping to strangers, delivered by a project they have nothing to do with, and repeated for
every commit that mentions the issue.

The cost is one-directional and permanent. **The event cannot be withdrawn** — not by
editing the commit, not by force-pushing, not by deleting the branch. Only a maintainer of
the *other* repository can hide it, which makes our convenience their clean-up task.
`8a2f0ac` did exactly this to `niri-wm/niri#2367` before the rule existed.

File contents behave differently. A link written in `docs/`, in this file, or in
`.agent/plan.md` is rendered as a link and notifies nobody, however often it is read. The
information is identical; only the side effect differs.

**Decision.** Never reference an issue or pull request from a commit message, in any form
— `#123`, `owner/repo#123`, `GH-123`, issue/PR URLs, or any closing keyword pointed at
them. Cite upstream issues in repository **files**, where the full link is safe, and have
the commit body name the issue in prose (`upstream niri issue 2367`) or point at the
`DD-###` that holds the link.

The mechanical test for a commit message is **no `#`, no `github.com/…` URL, no closing
keyword aimed at either**. A bare number in prose is inert — GitHub autolinks only the
`#`-forms and URLs.

**Consequences.**
- Nobody outside this project is notified by anything committed here. That is the whole
  point of the rule; every other effect is secondary.
- Provenance is not lost, and arguably improves. A link in `docs/` or this file is
  discoverable by a reader who was not present for the commit; a reference buried in
  `git log` is not. The commit says *which* issue, the record says *where*.
- The trade is one click. A reader of `git log` who wants the upstream thread has to open
  the `DD-###` first. Acceptable — that reader is almost always already in the docs.
- `Closes IMG-012.` is unaffected. `plan.md` task IDs are internal identifiers, are not
  GitHub issues, and are not autolinked.
- History is not rewritten. The reference `8a2f0ac` created upstream stands; the rule
  applies from its adoption forward.
- The same mechanism fires from PR and issue bodies, review comments, and even a
  cross-repo mention in a PR title. Those are outside this rule's scope, but the same
  restraint applies: link to another project's thread only when the people in it would
  actually want to hear from us.

---

## DD-021 — Stop the Xwayland Video Bridge in Niri; hiding it was not enough

**Status:** Accepted — supersedes [DD-019](#dd-019--hide-the-xwayland-video-bridge-in-niri-rather-than-stopping-it)

**Implements:** `IMG-012`

**Context.** DD-019 hid the bridge's window with a niri `window-rule` and rejected masking
its autostart entry, on the grounds that hiding costs nothing while masking costs X11
screen sharing. The rule works: the window is no longer drawn and no longer covers the
session.

It is not sufficient. **A hidden window is still a window.** It stays in niri's toplevel
list, so DankMaterialShell's bar keeps showing the bridge as a running application, and the
user is back to looking at something they cannot use and did not ask for.

There is no configuration that fixes this at either end:

- Niri has no `skip-taskbar` equivalent. Its window rules control how a window is *drawn*
  and placed, not whether it appears in `ext-foreign-toplevel-list`, which is where a bar
  gets its window list.
- DMS's Running Apps widget draws every toplevel `CompositorService` reports. Its settings
  offer app-id *substitutions* — renaming — and no exclusion list.

So the option DD-019 rejected is the only one left, and its cost has to be paid.

**Decision.** Ship `/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop` — upstream's
entry plus `NotShowIn=niri;` — so the bridge does not autostart in a Niri session. **Keep
DD-019's window rule**: it costs nothing and still covers the case where the bridge is
started by hand.

**Consequences.**
- X11 applications — Discord, Zoom, older OBS — cannot capture the screen in the Niri
  session. Wayland-native screen sharing through `xdg-desktop-portal` is unaffected, as is
  everything in a Plasma session. `xwaylandvideobridge` run by hand still works, and the
  window rule keeps it out of sight when it is.
- Turning it on is deliberately cheap, so the trade above is an inconvenience rather than a
  loss of function: `Mod+Shift+B`, or the launcher entry, runs `/usr/bin/qubix-video-bridge`
  and toggles it with a notification either way (`IMG-013`). The logic lives in a script
  because both entry points must launch the bridge identically — the stop half matches on
  the command line, so a keybind and a desktop entry that spelled it differently would
  start something the other could not stop.
- The overlay file **replaces** a package-owned file rather than extending it. Desktop
  entries have no drop-in mechanism, and `/etc/xdg/autostart` is the highest-priority
  autostart directory available system-wide, so there is nowhere to override from. If
  upstream ever changes its `Exec` line, this copy goes stale silently — the failure mode
  is the bridge not starting in Plasma either, which is visible.
- The copy omits upstream's localized `Name`/`Comment`/`GenericName` entries. `NoDisplay`
  is true, so the entry is never shown and there is nothing to translate.
- The `NotShowIn` value is lower-case `niri`, which is what niri sets
  `XDG_CURRENT_DESKTOP` to. Desktop-entry matching is case-sensitive, so `Niri` would
  silently not match.
- This is the second half of the pattern DD-019 named. A KDE component that autostarts and
  expects a KWin rule needs *both* answers: a window rule if it should still run, and a
  `NotShowIn=niri;` override if it should not. Reach for the window rule first — it takes
  nothing away.

---

## DD-022 — Theme the Niri session from `#56728B`, not from the logo green

**Status:** Accepted

**Implements:** `BRD-002`

**Context.** The Niri session shipped with one borrowed colour: the logo green `#47603b`
on the focus ring, paired with a neutral grey for unfocused windows. Everything else niri
can colour — border, shadow, tab indicator, insert hint, overview backdrop — kept niri's
defaults, which are its own blue. So the session was not themed; it was two colours from
two unrelated sources with niri's defaults showing through the gaps.

Two questions had to be answered together.

**Which colour.** `#47603b` is the logo mark's green. A logo colour and a UI accent are
different jobs: the logo is seen once, at high contrast, on a splash or an About page; the
focus ring is on screen permanently, in peripheral vision, next to whatever the user is
actually reading. `#47603b` is `hsl(100, 24%, 30%)` — dark enough that a 2px ring against a
dark desktop is hard to pick out, and green enough to fight with terminal output and
syntax highlighting. `#56728B` is `hsl(208, 24%, 44%)`: the same saturation, 14 points
lighter, and in a hue that almost nothing else on a developer's screen occupies.

**How to derive the rest.** Picking five more colours by eye produces a palette that drifts
in hue and reads as several colours. Holding hue and saturation and moving only lightness
produces one colour at five depths, which is what "themed from a hex" should mean.

**Decision.** Theme the Niri session from `#56728B`, deriving every other surface by
lightness alone:

| Hex | HSL | Role |
|---|---|---|
| `#1B242C` | `hsl(208, 24%, 14%)` | Overview backdrop, shadow |
| `#2B3945` | `hsl(208, 23%, 22%)` | Unfocused window |
| `#3A4E5F` | `hsl(208, 24%, 30%)` | Inactive tab |
| `#56728B` | `hsl(208, 24%, 44%)` | **Base — focused window** |
| `#7490A9` | `hsl(208, 24%, 56%)` | Active tab |
| `#C67B39` | `hsl(28, 55%, 50%)` | Urgent |

The urgent colour is the single deliberate exception. It sits at hue 28°, 180° from the
base, because a window demanding attention is the one thing in this palette that must not
blend into it.

**Consequences.**
- Every colour niri accepts is now set, so niri's own blue no longer shows through
  anywhere.
- `border` and `shadow` stay **off**, as niri ships them, but are pre-coloured. Turning
  either on is a one-word edit that still matches, rather than an edit that then needs a
  colour picked to go with it.
- **DankMaterialShell's dynamic theming still wins.** `/etc/niri/config.kdl` ends with an
  include of `~/.config/niri/dms/colors.kdl` and niri includes override what precedes them
  (DD-015). A user who enables matugen theming gets wallpaper-derived colours over the top.
  This palette is the session default, not a lock, and the ordering is not changing.
- The logo green is unaffected and stays the logo's. `docs/branding.md` now says so
  explicitly, because "primary colour in the logo mark" had started to read as "the project
  colour".
- `background-color "transparent"` is untouched, so DMS's wallpaper still shows through.
  Where no wallpaper is drawn, what fills the screen is the overview backdrop, which is now
  the palette's deepest tone rather than niri's default.
- The palette extends by lightness. Anyone adding a surface should compute the next tone
  from `hsl(208, 24%, L)` rather than choosing something that looks close.
- This themes **niri only**. DankMaterialShell has its own theming system and is not
  covered here; matching the bar to this palette is a separate piece of work.

---

## DD-023 — Ungoogled Chromium as the default browser; Firefox not shipped

**Status:** Accepted — supersedes the browser half of
[DD-006](#dd-006--firefox-as-a-flatpak-not-an-rpm)

**Implements:** `IMG-014`

**Context.** DD-006 answered one question — *packaged how?* — and its answer stands: a
browser is the most frequently patched thing on a desktop, and a layered RPM can only be
updated by rebasing the whole image, so the browser is a Flatpak. It never answered *which
browser*; Firefox was simply what Aurora already layered.

That left two gaps, and the second is the one that matters:

- **Firefox was installed, not chosen.** The image inherited it and re-installed it in
  another form.
- **Nothing made it the default.** `default-flatpaks` installs; it does not associate. With
  the Firefox RPM removed and its Flatpak seeded on first boot, whichever handler the
  desktop found first won `x-scheme-handler/https`, so "the default browser" was an
  emergent property of the base image rather than a decision this repository had made. The
  same gap would exist for any browser.

**Decision.** Ship **Ungoogled Chromium**
(`io.github.ungoogled_software.ungoogled_chromium`, Flathub) as the only browser, and make
it the default explicitly, in three places:

| File | Consumer | Why it is needed |
|---|---|---|
| `recipes/common-base.yml` | `default-flatpaks` | Installs the Flatpak (system scope) |
| `/etc/xdg/mimeapps.list` | `xdg-open`, GIO, KIO | Claims `http`, `https`, `about`, `unknown`, `text/html`, `application/xhtml+xml` |
| `/etc/xdg/kdeglobals` | KIO's `OpenUrlJob` | `BrowserApplication=` — KDE checks this key *before* the MIME associations |

Firefox is not installed in either form. The `dnf` removal of `firefox` and
`firefox-langpacks` therefore stays, and gains a second reason: not just "the RPM is the
wrong packaging" but "a second browser competing for the default is the problem being
fixed".

**Consequences.**
- The browser is a deliberate choice, and the association is declared rather than inherited.
  Clicking a link in any application, in either session, opens Ungoogled Chromium.
- Ungoogled Chromium is Chromium with Google's web services integration removed and no
  binary blobs from Google. That is the reason for choosing it and also its cost: no
  Sync, no Play/Widevine DRM by default (Netflix and Spotify Web need Widevine installed
  separately), and no built-in updater — Flathub is the update channel.
- **It is a community Flathub build, not a vendor one.** Ungoogled Chromium has no first
  party release infrastructure for Flatpak, so the packaging is maintained by
  `ungoogled-software` volunteers and lags upstream Chromium security releases more than
  Mozilla's own Firefox Flatpak does. This is the sharpest edge of the decision and the
  thing to re-examine if the lag ever grows.
- `/etc/xdg/mimeapps.list` claims **only** the web types. `application/pdf` and the image
  types stay with Okular and Loupe, even though the browser's desktop entry offers them.
- **The user's own choice still wins.** `~/.config/mimeapps.list` is searched before
  `/etc/xdg`, so *System Settings → Default Applications* keeps working, and installing
  Firefox from Flathub by hand and selecting it there needs no change here.
- **Nothing uninstalls the Firefox Flatpak on an existing machine.** The `default-flatpaks`
  v2 module installs only — it has no `remove:` — so a machine rebased from an older Qubix
  OS keeps `org.mozilla.firefox` until the user runs
  `flatpak uninstall --system org.mozilla.firefox`. `docs/usage.md` says so. A fresh
  install never gets it.
- **The Flatpak ID is validated at build time.** The v2 module checks every ID in `install:`
  against Flathub, so a typo fails the build rather than producing an image with no browser
  and a `mimeapps.list` pointing at nothing.
- Between the flatpak seeding on first boot and the association being read, the entry names
  a desktop file that does not exist yet. The association is inert until the seeding
  finishes, exactly as it was for Firefox under DD-006; the first boot needs network access
  regardless.

---

## DD-024 — Pin the built-in panel to `scale 1`

**Status:** Accepted

**Implements:** `BRD-003`

**Context.** With `scale` unset, niri derives a scale from an output's physical dimensions
and resolution. On a roughly 14-inch 1920×1200 laptop panel that derivation lands on
**1.25**, which is not what this project wants: at 1.25 the Niri session renders everything
a quarter larger than the Plasma session on the same machine, and fractional scaling costs
sharpness on a panel that does not need scaling at all.

The obvious fix — "set the default scale to 1" — does not exist. **Niri has no global scale
setting.** An `output` block matches either a connector name (`eDP-1`, `HDMI-A-1`) or a
`"manufacturer model serial"` triple. There is no wildcard and no default block, so a
shipped configuration cannot express "every output" or "whatever the built-in panel is
called". It can only name something.

**Decision.** Name `eDP-1` — the conventional connector name for a laptop's built-in panel
— and set `scale 1` on it. Nothing else is configured, so external monitors keep niri's
automatic guess.

**Consequences.**
- The Niri session matches the Plasma session's geometry on the target hardware, and the
  panel is driven at its native resolution with no fractional scaling.
- **This applies to every machine running the image.** On hardware with a genuinely HiDPI
  built-in panel, niri's guess would have been correct and a forced `scale 1` produces
  unreadably small text. The config block says so and says to delete it; that is the whole
  mitigation, and it is a real cost, not a theoretical one.
- A machine whose built-in panel is not `eDP-1` silently keeps the automatic scale. The
  failure is benign and visible — the session simply looks as it did before — and
  `niri msg outputs` gives the right name.
- This is a *system default*, so a per-user `~/.config/niri/config.kdl` overrides it like
  everything else in the shipped config (DD-014).
- Scope is deliberately narrow: one output, one property. Resolution, refresh rate,
  position, and rotation stay automatic. Pinning a mode as well would break the moment the
  hardware changed, and would buy nothing.

---

## DD-025 — Ship the theme as watched files, and seed only the pointer

**Status:** Accepted

**Extends:** [DD-022](#dd-022--theme-the-niri-session-from-56728b-not-from-the-logo-green)

**Implements:** `BRD-004`

**Context.** DD-022 defined the palette. It did not make the palette *arrive*, and each
half of the session failed to receive it for a different reason.

**niri** prefers `~/.config/niri/config.kdl` and ignores `/etc/niri/config.kdl` entirely
once that file exists. `docs/desktops.md` tells users to copy the system config in order to
customise it — so following our own documentation permanently disconnects a user from every
future system change, the theme included. That is a trap of our own making.

**DankMaterialShell** keeps its settings per user in
`~/.config/DankMaterialShell/settings.json`. It has no system-wide default, does not search
`$XDG_CONFIG_DIRS`, and its `theme` IPC target only switches light and dark. There is no
mechanism by which an image can choose a DMS theme. It can only put a theme somewhere a
user's settings point at.

The detail that makes this tractable is that **both consumers watch files**. Niri watches
every included file and live-reloads. DMS loads `customThemeFile` through a watched
`FileView`. So the palette does not have to be copied into anyone's home directory — it
only has to be *referenced* from there.

**Decision.** Split the palette into files that live in the image, and seed references
rather than contents.

| Half | File in the image | How it is referenced |
|---|---|---|
| niri | `/etc/niri/qubix-theme.kdl` | `include` from the system config; a personal config adds one line |
| DMS | `/usr/share/qubix-os/dms-theme.json` | `customThemeFile` in each user's settings, written by `qubix-dms-theme.service` |

The seeder writes three keys — `currentThemeName` and `currentThemeCategory` set to the
literal `"custom"`, and `customThemeFile` — and nothing else.

**Consequences.**
- **A rebase updates the colours with nothing to re-run.** Both files are watched; changing
  them changes a running session. The per-user state is a path, and paths do not go stale.
- The two palettes are separate files that must be changed together. They are the same
  colours expressed in two formats, and nothing enforces that — each file says so at the
  top. A drift here is invisible until someone looks at the bar next to a focus ring.
- The seeder **enforces** the pointer on every Niri session, which is what was asked for. A
  user who picks a different theme in DMS's settings gets it reverted at next login. The
  opt-out is one command — `systemctl --user mask qubix-dms-theme.service` — and is
  documented next to the behaviour, because "my theme keeps coming back" is otherwise a
  miserable thing to debug.
- The seeder never overwrites a `settings.json` it cannot parse. DMS refuses to write over
  one too, and clobbering a user's settings to fix a colour would be a bad trade. It also
  writes through a temporary file and renames, because the file is being watched and a
  half-written one reads as corrupt.
- The unit is pulled in by `niri.service`, not enabled globally — the same scoping as
  `dms.service` (DD-015), so a Plasma session is untouched.
- Text contrast in the DMS palette was checked rather than assumed: every foreground /
  background pair clears WCAG AA at 4.5:1, the tightest being `primaryText` on `primary` at
  4.59:1. That pair is the one to re-check if the base colour ever moves.
- The niri config is now two files where it was one. That is the cost of letting a personal
  config track the theme, and it is worth it: the alternative is telling users not to
  customise their compositor.

---

## DD-026 — Wire the shell from a one-line pointer in each user's rc file

**Status:** Accepted

**Status (delivery):** the pointer-seeding mechanism below is **superseded by**
[DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder). The
three-layer split, and every reason given here for what may not go in `/etc/profile.d`,
still stand.

**Amended by:** [DD-028](#dd-028--make-zsh-the-login-shell-once-per-account) *(the "zsh is
not made the default shell" consequence below only)*, itself superseded by DD-030.

**Implements:** `IMG-015`

**Context.** `starship` has been installed since DD-007 and was never initialised — no
shell in the image ever ran `starship init`, so the prompt was dead weight for as long as
it has been in the package list. Fixing that, and adding atuin, the zsh plugins, bat and
yazi around it, all reduce to one question: **where does an image put interactive shell
configuration?**

There are four hooks, and three of them are traps.

**`/etc/profile.d/*.sh`** is the obvious one, and it cannot carry the zsh half. Fedora's
`/etc/zshrc` sources those files from inside `_src_etc_profile_d()`, which runs
`emulate -L ksh`. Anything sourced from there sees `KSH_ARRAYS` and `SH_WORD_SPLIT` — zero-
based arrays and word splitting — which is not the language zsh plugin scripts are written
in. Verified against Fedora's `zshrc.rhs`, not assumed.

**Replacing `/etc/zshrc`** puts us in charge of that `profile.d` loop, and of the rest of
Fedora's file, forever. The failure mode of getting it subtly wrong is that every
`profile.d` script silently stops running under zsh, which is the kind of bug that takes a
week to find.

**Replacing `/etc/zshenv`** is safe in itself — Fedora's is comments only — but it is
ordered wrong. It runs before `~/.zshrc`, and zsh-syntax-highlighting wraps the ZLE widgets
that exist when it is sourced; upstream's `INSTALL.md` says it "must be the last plugin
sourced".

**The end of `~/.zshrc`** is where both plugin upstreams say to put this, and it is the
only hook that is after `compinit` and after a user's own `zle -N` calls. It is not a
system path, so it has to be *written* — which is the decision.

**Decision.** Split the configuration in three, and seed only the pointer.

| Layer | Where | Contains |
|---|---|---|
| Environment | `/etc/profile.d/qubix-shell-env.sh` | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`. Variables only — it is sourced under ksh emulation |
| Content | `/usr/share/qubix-os/shell/` | The prompt, the plugin loading, the aliases |
| Pointer | `~/.zshrc`, `~/.bashrc.d/50-qubix-shell.sh` | One `source` line, written once by `qubix-seed-home.service` |

Bash needs no edit to `~/.bashrc`: Fedora's skeleton copy already loops over
`~/.bashrc.d/`, so the seeder drops a file in.

`STARSHIP_CONFIG` follows the same pointer discipline by a different mechanism: it is set
to the image's config **only when `~/.config/starship.toml` does not exist**, so starship's
own documented override keeps working and the image's prompt is never copied into `$HOME`.

**Consequences.**
- **A rebase changes the shell environment with nothing re-run.** The per-user state is one
  line containing a path, and paths do not go stale. Same reasoning as DD-025.
- **Seeded once, ever, per item, stamped in `~/.local/state/qubix-os/seeded/`.** Delete
  what was seeded — including the `source` line — and it stays deleted. This is the
  opposite of `qubix-dms-theme.service`, which re-asserts its pointer every session, and
  the difference is deliberate: these are the user's own dotfiles. An image that restores a
  line somebody removed on purpose is an image its owner ends up fighting.
- **The seeder is enabled globally**, not scoped to a session like `dms.service` (DD-015).
  A shell is a shell in Plasma, in Niri, and over SSH.
- **zsh is not made the default shell.** The login shell is a per-account field in
  `/etc/passwd`, which an image cannot set for an account that already exists; changing
  `/etc/default/useradd` would only affect accounts created later, which on a personal
  machine is none. So `chsh -s /usr/bin/zsh` is one documented command, and bash is
  configured too so that not running it costs the four zsh-only tools and nothing else.
- **atuin is wired into zsh only.** Its bash integration requires `bash-preexec`, which
  Fedora does not package. Shipping a vendored copy of a second history-hooking layer for
  the non-default shell is not worth it; the asymmetry is documented in
  [`shell.md`](shell.md) instead of being left to be discovered.
- **Anything a user adds below the loader line in `~/.zshrc` is not syntax-highlighted.**
  That is inherent to "highlighting goes last" and is stated in the seeded block itself.
- `zsh-completions` needed a build step rather than a package: Fedora does not ship it, and
  the `@zsh-users/zsh-completions` COPR has no chroots for any current Fedora — checked
  against the COPR API. It is installed from a pinned tag whose commit hash is asserted, so
  a moved tag fails the build loudly instead of shipping something else quietly. Its
  functions shadow zsh's own where both exist, which is what using zsh-completions means.
- Two COPRs are added: `lihaohong/yazi` and `atim/lazygit`. Neither tool is in Fedora. The
  second is run by the maintainer of `atim/starship`, already trusted since DD-007.
- Cost: the terminal environment is now spread over six files. They are small, each names
  its consumer in a header, and [`shell.md`](shell.md) maps all of them.

---

## DD-027 — Neovim's configuration belongs to the user, seeded once

**Status:** Superseded by
[DD-029](#dd-029--seed-the-neovim-config-as-a-git-clone-so-it-can-be-updated) *(the seeding
mechanism only — the user's ownership of `~/.config/nvim` still stands)*, and in turn by
[DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder), which stops
the image seeding it at all

**Implements:** `IMG-016`

**Context.** The image ships Neovim configured with LazyVim, and the requirement attached
to it was explicit: **edits to that configuration must persist.** On an image-based system
that is not the default outcome, and the obvious placements all fail it.

Neovim does read a system-wide config — `$XDG_CONFIG_DIRS/nvim`, i.e. `/etc/xdg/nvim` —
which is how every other system-wide default in this repository works. It does not work
here. LazyVim writes into its *config* directory: `lazy-lock.json` is the pinned plugin
set, and `:Lazy update` rewrites it. A config directory in `/usr` or in a
rebase-overwritten `/etc` is therefore broken from the first update, and a user editing it
would lose their work at the next rebase regardless.

**Decision.** `~/.config/nvim` is the user's. The LazyVim starter is vendored into the
overlay at `/usr/share/qubix-os/nvim/` and copied there **once**, by
`qubix-seed-home.service`, on the first login after a rebase. Nothing in the image ever
writes to it again.

This is the one place in this repository where seeding *contents* rather than a pointer is
correct — the entire point is that the contents get edited. DD-026 covers the same seeder
and the general rule it is an exception to.

**Consequences.**
- The config survives updates, rebases, and rollbacks, because nothing in the image has any
  opinion about it after the first write.
- A user who deletes `~/.config/nvim` gets vanilla Neovim, not the starter again. The stamp
  in `~/.local/state/qubix-os/seeded/nvim` is what makes that true; deleting the stamp
  re-seeds.
- **Updating the vendored starter changes nothing for existing accounts.** That is the
  price of the guarantee and it cannot be had both ways. New accounts get the new copy.
- **First `nvim` launch needs network.** LazyVim bootstraps by cloning `lazy.nvim` and then
  installing the plugin set. Pre-baking a plugin tree into `/usr` would defeat
  `:Lazy update` and be reset by every rebase, so it is not done.
- The starter is vendored, not cloned at build time, so the build does not depend on GitHub
  being reachable and the seed is reviewable in a diff. Only `init.lua` carries a Qubix
  header; every other file is upstream verbatim, Apache-2.0, with `LICENSE` alongside.
- The tools LazyVim's default keymaps shell out to — `ripgrep`, `fd-find`, `fzf`,
  `lazygit`, `git` — are installed with it. Shipping the keymaps without them would be
  worse than not shipping the editor: the keys would exist and do nothing.
- `$EDITOR` and `$VISUAL` become `nvim`, but only when unset, so an export in a user's own
  rc file wins. `micro` stays installed (DD-007); this picks a default, it does not remove
  a choice.

---

## DD-028 — Make zsh the login shell, once per account

**Status:** Superseded by
[DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder) *(the
service is removed; zsh is still the intended login shell)*, then **reinstated** by
[DD-035](#dd-035--set-the-login-shell-from-the-image-because-chsh-does-not-exist-here)
*(the service returns, with the three rules below unchanged)*

**Amends:** [DD-026](#dd-026--wire-the-shell-from-a-one-line-pointer-in-each-users-rc-file)
*(its "zsh is not made the default shell" consequence)*

**Implements:** `IMG-017`

**Context.** DD-026 configured zsh thoroughly and then left the user in bash, on the
grounds that the login shell is a per-account field in `/etc/passwd` and an image cannot
write another machine's `/etc/passwd`. That reasoning is still correct; the conclusion
drawn from it was wrong. It made the four zsh-only tools — autosuggestions, syntax
highlighting, completions, atuin's history search — conditional on the owner reading the
documentation and running a command, which is not what "configure zsh" means.

`/etc/default/useradd` does not solve it. It sets the shell for accounts created *later*,
and the account that matters on a personal machine was created at install time.

So the change has to happen **on the machine, as root**, which means a system service —
the only one this repository adds. `chsh` run as the user would prompt for a password,
which a service does not have.

**Decision.** `qubix-default-shell.service` runs at boot and sets `/usr/bin/zsh` as the
login shell for human accounts, subject to three rules:

| Rule | Why |
|---|---|
| Ordered `Before=systemd-user-sessions.service` | That unit is the gate that permits logins, so no account is logged in when `usermod` runs, and the first login of the boot is already in zsh |
| UID 1000–60000 only | Human accounts. **`root` keeps bash**, so a broken zsh can never cost anyone their recovery shell |
| Only replaces `/bin/bash` or `/usr/bin/bash`, once, stamped in `/var/lib/qubix-os/` | Bash is the inherited default. Anything else was a choice, and a choice is not something to overrule every boot |

**Consequences.**
- **A rebase gives you zsh at the next boot**, with no per-user action, which is what was
  asked for.
- **`chsh -s /bin/bash` sticks.** The account is already stamped, so nothing reverts it.
  This is the property that makes the whole thing acceptable: the image gets one attempt at
  each account, not a standing veto.
- An account on fish, nushell, or anything else is stamped on the first boot and never
  touched. Opting out ahead of time is `sudo touch
  /var/lib/qubix-os/default-shell/<user>`.
- **Bash stays fully configured** (DD-026), so moving back costs the four zsh-only tools
  and nothing else. Nothing here removes bash or makes it second-class.
- An account created *after* boot — a second user added later — gets zsh at the next boot,
  or immediately with `sudo chsh -s /usr/bin/zsh <user>`. Shipping
  `/etc/default/useradd` to close that window would mean replacing a `%config(noreplace)`
  file owned by shadow-utils, for a case that happens approximately once.
- The stamps live in `/var`, not `/etc`: machine state that must survive a rebase, and that
  nobody should have to three-way merge.
- The build now asserts `/usr/bin/zsh` is in `/etc/shells`. `usermod` does not care, but
  `chsh` — the command in every one of these instructions — does, and a missing entry turns
  the documented escape hatch into "chsh: /usr/bin/zsh is not a valid shell".
- Cost: this repository now ships a **system** unit that modifies `/etc/passwd`. That is a
  bigger hammer than anything else here, and it is why the once-ever stamp is not optional.

---

## DD-029 — Seed the Neovim config as a git clone, so it can be updated

**Status:** Superseded by
[DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder) *(the image
no longer seeds it; the clone is now a command the user runs, and everything this record
says about why it must be a clone is why)*

**Supersedes:** [DD-027](#dd-027--neovims-configuration-belongs-to-the-user-seeded-once)
*(the seeding mechanism only)*

**Implements:** `IMG-018`

**Context.** DD-027 copied the vendored LazyVim starter into `~/.config/nvim` as plain
files. That guaranteed the config would never be overwritten — and made it impossible to
update, because the two halves of a LazyVim installation update by completely different
routes:

| Half | Lives in | Updated by |
|---|---|---|
| LazyVim itself, and every plugin | `~/.local/share/nvim/lazy/` | `:Lazy update`. Already worked |
| The starter config | `~/.config/nvim` | Nothing. It was a dead copy |

Upstream does change the starter — `lua/config/lazy.lua`, the bootstrap, is where it
happens — and a user had no way to receive that short of diffing by hand against
`/usr/share`.

**Decision.** Seed `~/.config/nvim` by **cloning `LazyVim/starter`**, so the config is a
git repository whose `origin` is upstream. `git pull` is then the answer, and the user's
own edits are commits on top of upstream's history.

Network at first login is not a new requirement. LazyVim's own bootstrap clones `lazy.nvim`
and the whole plugin set the first time `nvim` starts, so a config seeded offline could
never have worked anyway. If the clone fails, nothing is stamped and the next login retries.

**Consequences.**
- **`git -C ~/.config/nvim pull` updates the config**, and `:Lazy update` updates
  everything else. Both are documented in a `QUBIX.md` seeded alongside the config, so the
  answer is in the directory rather than only in this repository.
- **DD-027's guarantee is untouched.** The image still writes `~/.config/nvim` exactly
  once and never again; what changed is what it writes.
- The vendored copy stays as an **offline fallback**, and is now byte-identical to
  upstream — the Qubix header that was in `init.lua` moved into `QUBIX.md`, so re-vendoring
  is a straight copy and a diff against upstream is meaningful.
- **The fallback's history is unrelated to upstream's**, because these are our commits of
  the same files rather than upstream's commits. A first `git pull` there needs
  `--allow-unrelated-histories`. That is a genuine wart; `QUBIX.md` states it, and gives
  the one-line `git log` that tells you which path you got.
- A failed clone removes its partial directory before falling back. A half-written config
  is worse than none: the next login would see the directory, conclude the work was done,
  and skip seeding forever.
- `git commit` in the fallback runs with an identity passed on the command line, because a
  fresh account has no `user.name` and git refuses to commit without one. Nothing is
  written to the user's global git config to seed an editor.
- `QUBIX.md` is added to `.git/info/exclude`, so it does not sit in `git status` as an
  untracked file in a repository the user is about to start committing to.
- Cost: first login now depends on GitHub being reachable, where a copy did not. The retry
  makes it self-healing, and LazyVim already had the same dependency one step later.

---

## DD-030 — Configure the shell with system files, and no runtime seeder

**Status:** Accepted, except for two rows of its table — the login shell is superseded by
[DD-035](#dd-035--set-the-login-shell-from-the-image-because-chsh-does-not-exist-here)
*(`chsh`, the command this record traded a service for, is deleted from the image by
Aurora)* and the zsh wiring by
[DD-036](#dd-036--wire-zsh-from-the-end-of-etczshrc-not-from-etczshenv)
*(`/etc/zshenv` runs before `/etc/profile.d`, so it initialised the tools before their
environment existed)*. Its guards are amended by
[DD-037](#dd-037--guard-shell-setup-on-what-a-shell-owns-never-on-what-it-inherits)
*(each one tested an exported variable, so no nested shell was set up)*. Everything else
here stands: no runtime seeder, no writes to `$HOME`, atuin configured from the
environment, Neovim left to the user

**Supersedes:** [DD-026](#dd-026--wire-the-shell-from-a-one-line-pointer-in-each-users-rc-file)
*(its delivery mechanism only)*,
[DD-028](#dd-028--make-zsh-the-login-shell-once-per-account),
[DD-029](#dd-029--seed-the-neovim-config-as-a-git-clone-so-it-can-be-updated)

**Implements:** `IMG-019`

**Context.** DD-026 to DD-029 delivered a shell environment, a login shell and an editor
config using two Python scripts, two systemd units, two `.wants` symlinks, a stamp
directory under `/var`, another under `~/.local/state`, and a clone-with-offline-fallback.
That is a great deal of moving machinery for what is, in the end, a handful of
configuration files. Judged not worth its complexity, and removed.

The machinery grew from one true constraint and one false assumption.

**The true constraint stands:** `/etc/profile.d/*.sh` cannot carry the zsh half, because
Fedora's `/etc/zshrc` sources those files from inside a function that has run
`emulate -L ksh`. Everything DD-026 says about that is still correct.

**The false assumption** was that reaching zsh therefore meant writing into `~/.zshrc`.
DD-026 rejected `/etc/zshenv` on ordering grounds — it runs before `~/.zshrc`, so
zsh-syntax-highlighting cannot wrap a user's own widgets — and then paid for that ordering
with a seeder, a systemd unit, stamps, and a block appended to a file the image does not
own. **Fedora's `/etc/zshenv` is comments only.** Replacing it costs nothing, it is plain
zsh at top level, and it reaches every account, including ones that already exist, with no
per-user state at all.

**Decision.** Ship files. Nothing in the image writes to `$HOME` or to `/etc/passwd` at
runtime.

| Concern | Before | Now |
|---|---|---|
| zsh setup | A line seeded into `~/.zshrc` | `/etc/zshenv`, which Fedora leaves empty |
| bash setup | A file seeded into `~/.bashrc.d/` | The end of `/etc/profile.d/qubix-shell-env.sh` |
| atuin | A config file seeded into `~/.config/atuin/` | `ATUIN_*` environment variables |
| Login shell | A boot service running `usermod` | `/etc/default/useradd`, plus one documented `chsh` |
| Neovim config | A clone run by the seeder, with a vendored fallback | One documented `git clone`, which is LazyVim's own install instruction |

atuin turned out to need no file at all: it reads every setting from the environment —
`Environment::with_prefix("atuin")` with `__` as the nesting separator, so `ATUIN_AUTO_SYNC`
is the `auto_sync` key. Verified in its `settings.rs`, not assumed.

**Consequences.**
- **Six files and about four hundred lines of Python and unit definitions are gone.** What
  remains is four configuration files in the overlay, all of which are read by something
  that already exists.
- **A rebase still updates everything**, and now more simply: there is no per-user copy to
  go stale, because there is no per-user copy.
- **zsh-syntax-highlighting does not wrap widgets defined in a user's own `~/.zshrc`.**
  That is the cost DD-026 was avoiding. Anyone who defines widgets can re-source
  `/usr/share/qubix-os/shell/qubix.zsh` at the end of their `~/.zshrc`; it is documented,
  and it is one line for the few people it affects.
- **`compinit` runs twice** for an account whose `~/.zshrc` came from Fedora's skeleton —
  once here, once there. A few milliseconds, and deleting the skeleton's two lines is safe.
  The alternative was not running it at all and breaking completion for anyone without a
  `~/.zshrc`.
- **An existing account needs one `chsh -s /usr/bin/zsh`.** This is where DD-028 started,
  and where it should have stayed: `/etc/passwd` is per machine, and a boot service editing
  it is a large hammer for a command the owner runs once, on one machine, ever.
  `/etc/default/useradd` covers accounts created afterwards.
- **Neovim is not configured until the user runs one `git clone`.** Everything DD-029
  established about *why* it must be a clone — `git pull` is the only way the config gets
  upstream's changes — still holds; the difference is who runs it. The vendored starter and
  its offline fallback are gone with it.
- Two upstream files are now replaced rather than added to: `/etc/zshenv` (empty, so
  nothing is lost) and `/etc/default/useradd` (eight lines, of which one differs). Both are
  `%config(noreplace)`, both are small and stable, and both say in a header comment what
  upstream's version contains. That is the residual cost of the simpler design.
- The build-time assertion that `/usr/bin/zsh` is in `/etc/shells` (DD-028) is kept, and
  matters more now: `chsh` is the documented path for every existing account, and `usermod`
  — which ignored `/etc/shells` — is no longer involved at all.

---

## DD-031 — Ship fastfetch's config in `/etc`, with the logo pinned

**Status:** Superseded by
[DD-041](#dd-041--draw-the-full-fedora-mark-and-move-the-box-to-its-gutter) *(the logo only —
everything about **where** the config goes is correct and unchanged)*. The shipped logo is
`fedora`, not `fedora_small`; the four columns are 45/51/61/112; and the reason given below
for pinning — that detection falls back to a generic penguin — is **wrong**: it reaches
`ID_LIKE` and matches Fedora's full mark.

Also amended by
[DD-040](#dd-040--undo-auroras-fastfetch-alias-because-it-beat-the-config-search-path):
until it, the command `fastfetch` was an alias to Aurora's own wrapper, so **nothing below
was ever read**, including a user's own file

**Implements:** `IMG-020`

**Context.** fastfetch is a system-information screen, run by hand. The configuration to
ship already existed — the oxocarbon box the owner runs on macOS — so the decisions here
are *where it goes* and *what it draws*, not what it looks like.

**Where it goes.** Every other piece of shell configuration in this image lives in `/usr`
and is reached by a pointer, because `/usr` is replaced wholesale on update while `/etc` is
three-way merged (DD-030). fastfetch offers no such route. Its config search path is built
in `FFPlatform_unix.c` and is, in order:

```
$XDG_CONFIG_HOME → ~/.config → $HOME → $XDG_CONFIG_DIRS → /etc/xdg → /etc
```

`/usr/share/fastfetch/` appears only in the *data* path, which holds presets and logos —
`fastfetch -c <preset>` loads from it, but nothing there is a default. There is no
environment variable for the config path either. So `/etc/fastfetch/config.jsonc` is the
only way to set a system-wide default, and it is taken.

That costs less than the `/etc` files DD-030 apologises for: this one is a pure **addition**
— the fastfetch RPM ships nothing in `/etc` — rather than a replacement of an upstream
file. And the search order gives the intended relationship for free, with no wiring at all:
`~/.config/fastfetch/config.jsonc` is the first entry, so a user's own config replaces this
one wholesale, exactly as starship's does.

**What it draws.** The box is not built by counting characters. Nerd Font glyphs are not all
one cell wide, so the config pins four absolute columns with CHA (`ESC[<n>G`) and lets the
terminal resolve them after the glyphs are drawn. Every one of those columns is derived from
the width of the logo, which makes the logo load-bearing rather than decorative.

Auto-detection cannot supply a stable width here. fastfetch picks its logo from `ID=` in
`os-release`, and this image rewrites that to `qubix_os_bluebuild` (DD-003) — a name no
builtin logo matches — so detection falls through to the generic 23-column penguin. The
logo is therefore **pinned**, and pinning it also means a future fastfetch that adds a
`qubix` logo cannot silently move the box.

Which logo is a question of terminal width. Widths were measured from fastfetch 2.66.0's
own logo files, with `$N` colour codes stripped, and cross-checked against what the binary
emits:

| Logo | Width | Gutter (`+2` left, `+4` right) | Right spine | Terminal needed |
|---|---|---|---|---|
| `fedora` | 38 | 44 | 112 | 112 columns |
| `unknown` (the fallback) | 23 | 29 | 97 | 97 columns |
| **`fedora_small`** | **16** | **22** | **90** | **90 columns** |

The box itself is 68 columns wide in every case; the logo only decides where it starts. A
WezTerm opened into a Niri column at `proportion 0.5` on the 1920px panel is around 100
columns, so the full Fedora mark would not fit in the window this image opens by default.
`fedora_small` does, with room to spare, and the value field keeps all 48 of its columns.

**Decision.** Install `fastfetch`; ship the config at `/etc/fastfetch/config.jsonc` with
`source: fedora_small` pinned and the four columns tuned to its 22-column gutter; ship
`retune.sh` at `/usr/share/qubix-os/fastfetch/retune.sh` for anyone who changes the logo.

**Consequences.**
- **Nothing runs fastfetch.** It is not a login banner and not part of shell startup; a
  shell that starts in 30 ms does not then spend 200 ms drawing a picture. Typing
  `fastfetch` is the whole interface.
- **A user's own config wins with nothing to undo**, and starting from this one is
  `cp /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc`.
- **Editing `/etc/fastfetch/config.jsonc` in place is the wrong move**, and the file says so.
  `/etc` is three-way merged, so a locally edited copy stops receiving image changes — the
  same trap DD-030 avoids by keeping configuration out of `/etc` wherever a `/usr` path
  exists.
- **Changing the logo means re-deriving four numbers**, which is what `retune.sh` is for: it
  measures the gutter fastfetch actually emits and rewrites the columns *and* the comment
  block that documents them. It needs `perl`, which is present because Fedora's `git` —
  already installed for LazyVim — requires `/usr/bin/perl`.
- **The box needs a 90-column terminal.** Narrower than that and rows overrun the right
  spine. This is the one hard requirement the layout imposes and it is stated in the file.
- **One row leaves the machine.** The `publicip` module asks `ipinfo.io/json` for the
  address the machine appears as, on every run. It is in the config the owner asked for and
  it stays, but it is called out in the block itself and in `docs/shell.md`, because "fully
  local" is a promise this image makes elsewhere (atuin, DD-030) and this is the exception.
  Deleting the block is the opt-out.
- **The Fedora mark, not a Qubix one.** fastfetch's builtin logos are ASCII art compiled
  into the binary; adding a Qubix one means either an image logo, which needs a terminal
  graphics protocol that the console and Konsole do not share, or hand-drawn ASCII, which
  is a branding task and not this one. The lineage is Fedora Atomic, so the Fedora mark is
  not a lie.

---

## DD-032 — lazygit is a tool of its own, configured from `/usr` through `LG_CONFIG_FILE`

**Status:** Accepted. How `LG_CONFIG_FILE` is guarded is amended by
[DD-037](#dd-037--guard-shell-setup-on-what-a-shell-owns-never-on-what-it-inherits)
*(it is exported, so "resolved once per shell" was in fact once per session)*

**Implements:** `IMG-021`

**Context.** `lazygit` has been installed since DD-026, but only as one of the binaries
LazyVim's `<leader>gg` shells out to. It was in no tool table, had no configuration, and
nothing told anyone it was there. Two things the *image* knows that a bare lazygit cannot:
a Nerd Font is installed, and the project has a palette (DD-022).

**Where a system-wide config can live.** lazygit reads exactly one path of its own —
`~/.config/lazygit/config.yml` — and has no `/etc` or `/usr` location. What it does have is
`LG_CONFIG_FILE`, which takes a **comma-separated list**, with later files overriding
earlier ones key by key.

That is better than the relationship every other tool here gets. starship, fastfetch and
zellij are all-or-nothing: a user's file replaces the image's entirely, so overriding one
value means copying the rest. Naming the image's file first and the user's second gives
per-key overriding — change one colour, keep everything else, and keep receiving the rest
on the next rebase.

Three facts from `pkg/config/app_config.go` and `pkg/theme/style.go` shape the wiring:

| Fact | Consequence |
|---|---|
| A path in `LG_CONFIG_FILE` that does not exist is an **error**, not a skip (`ConfigFilePolicyErrorIfMissing`) | The user's path may only be appended **when the file exists** |
| The only writer, `SaveGlobalUserConfig`, is integration-test code and panics with more than one config file | A config file in read-only `/usr` is safe |
| A theme value is looked up in `ColorMap`, then tried as hex, and **silently ignored** if neither | Hex works; a typo dims a border rather than failing loudly |

**Decision.** Keep `lazygit` installed, name it in the recipe as a tool in its own right,
ship `/usr/share/qubix-os/lazygit/config.yml` with `gui.nerdFontsVersion: "3"` and the
`#56728B` palette, and point `LG_CONFIG_FILE` at it from
`/etc/profile.d/qubix-shell-env.sh`, appending the user's own config when that file exists.
Add `lg`, upstream's directory-following wrapper, to the shared shell file.

**Consequences.**
- **Icons appear by default.** `nerdFontsVersion` defaults to empty — *no icons* — because
  upstream cannot assume a font. This image installs one (DD-026), so it can.
- **A user's config wins per key**, and creating it takes effect in the next shell, because
  `LG_CONFIG_FILE` is resolved at shell startup. That is the one wart of this mechanism and
  it costs one `exec zsh`.
- **`LG_CONFIG_FILE` is exported for every shell**, interactive or not, which is what makes
  lazygit behave the same when launched from LazyVim as from a prompt.
- **`lg` is not `lazygit`.** It sets `LAZYGIT_NEW_DIR_FILE` so the shell follows lazygit
  between repositories on `q` (not on `Q`) — the same trade as yazi's `y`, and shipped the
  same way. Upstream's snippet writes `~/.lazygit/newdir`; this uses `mktemp`, because
  nothing in this image writes to `$HOME` (DD-030).
- **Nothing is claimed for git itself.** lazygit is a viewer over the user's own git
  configuration; no `~/.gitconfig` is written, seeded, or defaulted.

---

## DD-033 — zellij from upstream's pinned `no-web` release, not from a COPR

**Status:** Accepted

**Implements:** `IMG-022`

**Context.** A terminal multiplexer was requested. The interesting question was not *which*
one — zellij was asked for by name — but *where it comes from*, because this image has no
good answer available off the shelf:

- **Fedora does not package zellij.** No `zellij` and no `rust-zellij` in dist-git;
  repology lists no Fedora build and no Terra build either.
- **Upstream endorses no COPR.** zellij's README and installation page give Fedora users no
  instructions at all. That is the difference from yazi, whose own documentation points
  Fedora users at `lihaohong/yazi` (DD-026), and from `atim/lazygit`, whose owner already
  supplies `starship` here.
- **The COPRs that exist are thin.** `varlad/zellij` last built 0.42.2 in July 2025;
  `boobaa/zellij` has a single successful build; `frodo/zellij` has six since March 2026,
  one of them failed. Enabling any of them grants a stranger the ability to run RPM
  scriptlets in **every Qubix image**, for one tool.

**Decision.** Install zellij from upstream's own release artifact in a `containerfile`
snippet: version pinned, SHA-256 asserted, `no-web` build, `/usr/bin/zellij`, with
completions generated by the binary that ships. Configure it at `/etc/zellij/config.kdl`.

This is the pattern DD-026 already uses for zsh-completions — a pinned upstream source
whose identity is *asserted*, so a changed artifact fails the build rather than shipping.
The published `.sha256sum` is the hash of the **binary inside** the tarball, not of the
tarball, so the assertion lands on what actually ships.

**The `no-web` build, deliberately.** zellij 0.43 added a local web server (`zellij web`,
`web_sharing`). It is off by default, and upstream also publishes a build compiled without
`web_server_capability`, which makes it *unavailable* rather than merely disabled. This
image promises atuin is local (DD-030) and calls out fastfetch's one network row (DD-031);
shipping the build that cannot serve is consistent with both. It is also 4 MB smaller.

**Configuration lands in `/etc` for the same reason fastfetch's does.** zellij takes the
first directory that **exists** from `~/.config/zellij` → `$XDG_CONFIG_HOME/zellij` →
`/etc/zellij` (`SYSTEM_DEFAULT_CONFIG_DIR`, `zellij-utils/src/consts.rs`). There is no
`/usr` entry and no environment variable for the config path. Nothing auto-creates the home
directory — `try_create_home_config_dir()` has no caller on the startup path — so the
system config is used until a user makes their own.

**The theme is written the long way, and the accents are lifted.** zellij accepts two theme
forms. The eleven-colour palette form (`fg`, `bg`, `red`, …) is shorter, but
`impl From<Palette> for Styling` maps those names to **roles**, not to hues: `green` becomes
the focused pane frame and the selected ribbon's background, while `blue` gets one emphasis
slot and one player colour. Handing it `blue "#56728B"` would have hidden the project colour
in the one theme that is supposed to carry it — and six further colours the mapping reads
(`gold`, `silver`, `purple`, `brown`, `pink`, `gray`) cannot be set in that form at all, so
they would have stayed at zellij's defaults. The named form states every element instead.

The accents also move: DD-022 fixes them at `hsl(h, 55%, 50%)`, which is right for a fill —
niri's urgent border — and wrong here, because in zellij every accent is *text* on a dark
surface. At L50, magenta reaches 3.6:1 against `#1B242C` and red 3.0:1. At **L68** all six
hues clear 4.5:1 on both backgrounds this theme puts text on, and every ratio is written
beside the colour in the file. One pair does not clear AA and is documented rather than
fixed: the unfocused pane frame at 3.1:1, which is a line and a deliberately recessive
title, clears the 3:1 WCAG asks of non-text, and would otherwise compete with the focused
frame.

**Consequences.**
- **Version bumps are manual.** A COPR would have been picked up by the daily rebuild; this
  is pinned until someone edits two lines in `common-base.yml`. Given that the best-kept
  zellij COPR still lags upstream by days and the worst by a year, the automation on offer
  was not worth the trust. The recipe says where the version and the hash come from.
- **No RPM database entry.** `rpm -q zellij` finds nothing; the binary is a file in `/usr`
  like any other overlay content. `zellij --version` is the way to check what is installed,
  and the build asserts it matches the pin.
- **43 MB of static musl binary** in the image, ~14 MB compressed. An RPM would have cost
  much the same; the `no-web` build is the part that saves anything.
- **The build proves the config parses.** `zellij setup --check` reports the config file it
  resolved and whether it is well-formed, and does **not** exit non-zero when it is not —
  hence two `grep`s. A broken KDL fails CI instead of every user's first login, and the
  check also proves `/etc/zellij` is the directory zellij will actually use.
- **A user's config shadows this one wholesale.** Per-key overriding is not available here
  the way it is for lazygit (DD-032); `cp /etc/zellij/config.kdl ~/.config/zellij/` is the
  documented start.
- **Nothing starts zellij.** Upstream ships an auto-start script for exactly this purpose
  and it is not installed — the same position as fastfetch (DD-031). A multiplexer that
  wraps every shell without being asked is a surprise, and `zellij attach` is one command.
- **Copying uses OSC 52**, zellij's default, because the alternative (`copy_command
  "wl-copy"`) ties the clipboard to a local Wayland session and to a package this image does
  not install. The config says so and gives the one-line change.

---

## DD-034 — Ship WezTerm's configuration in `/etc/xdg`, and the fonts it names from upstream

**Status:** Accepted, except for the way it guarantees `$XDG_CONFIG_DIRS`, which is amended
by [DD-038](#dd-038--append-etcxdg-to-xdg_config_dirs-in-both-places-a-shell-can-come-from)
*(`environment.d` alone reaches only the systemd user manager's units, and `:-` does nothing
to a list that is already set)*. `/etc/xdg/wezterm/` as the location, and everything about
the fonts, stands

**Implements:** `IMG-023`

**Context.** DD-012 made WezTerm the default terminal in both sessions and stopped there: it
was installed and selected, and then ran with WezTerm's built-in defaults. The configuration
that was actually wanted already existed — the one the owner of this image runs on macOS —
so the question was not *what* to configure but **where a system-wide WezTerm config can
live**, and what to do about a font stack written for a machine where every family was
installed by hand.

**Where the config goes.** WezTerm resolves its configuration in this order, first file that
exists winning (`config/src/config.rs`, `load_with_overrides`):

| # | Path | Source |
|---|---|---|
| 1 | `$WEZTERM_CONFIG_FILE` | environment, inserted at the **front** |
| 2 | `~/.wezterm.lua` | `HOME_DIR` |
| 3 | `$XDG_CONFIG_HOME/wezterm/wezterm.lua`, defaulting to `~/.config/wezterm/wezterm.lua` | `xdg_config_home()` |
| 4 | `<dir>/wezterm/wezterm.lua` for each entry of `$XDG_CONFIG_DIRS` | `config_dirs()` |

Row 4 is the whole answer, and row 1 is the trap. `WEZTERM_CONFIG_FILE` is the obvious lever
— it is the one the other tools here use, in the shape `STARSHIP_CONFIG` (DD-026) and
`LG_CONFIG_FILE` (DD-032) established — and it is exactly wrong for this: it is inserted at
the **front** of the list, so the image would beat the user instead of losing to them.
`/etc/xdg/wezterm/wezterm.lua` gives the relationship fastfetch and zellij already have
(DD-031, DD-033): a user's own config shadows it wholesale, with nothing to undo and no
wiring at all.

Colour schemes are found the same way. `compute_color_scheme_dirs()` appends `colors/` to
each of those same directories, so `/etc/xdg/wezterm/colors/*.toml` is where the shipped
schemes live — and they stay available even to a user whose own `wezterm.lua` has replaced
the file above them. Each scheme registers under its `[metadata] name`, **not** its
filename, which is the string `color_scheme` has to match.

**`$XDG_CONFIG_DIRS` has to be guaranteed, not assumed.** WezTerm reads the variable
literally — `if let Some(d) = std::env::var_os("XDG_CONFIG_DIRS")` in `config/src/lib.rs` —
and does **not** apply the XDG base directory spec's `/etc/xdg` default when it is unset. So
where nothing sets it, this config simply does not exist. Plasma sets it; niri does not. It
is therefore stated in `/usr/lib/environment.d/50-qubix-terminal.conf`, as
`XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-/etc/xdg}` — the `:-` form leaves an inherited value
alone, so a session that adds directories of its own keeps them. `environment.d(5)` supports
that expansion and gives this exact shape as its own example.

**The fonts had to become real.** The config names seven families in a fallback chain, and
shipping a config that names fonts the image does not have is not shipping the config —
WezTerm drops each missing family silently and renders with something else. Availability was
checked rather than assumed:

| Family | Where it comes from | Why |
|---|---|---|
| Monaspace Krypton NF | upstream release, pinned + SHA-256 | Fedora packages no `monaspace-fonts` in any form |
| IBM Plex Math | upstream release, pinned + SHA-256 | `ibm-plex-fonts` 6.4.0 has no `math` subpackage — its co-packages are mono, sans, serif, arabic, devanagari, hebrew, thai |
| IBM Plex Mono, IBM Plex Sans | `ibm-plex-mono-fonts`, `ibm-plex-sans-fonts` | In Fedora's main repositories |
| Noto Sans CJK SC / TC / JP | `google-noto-sans-cjk-fonts` | **Substituted** for IBM Plex Sans SC/TC/JP — see below |

The two upstream fonts follow the pattern DD-026 and DD-033 already use: a pinned version
whose identity is *asserted*, so a changed artifact fails the build rather than shipping.

**The Nerd Font build, and only the normal widths.** WezTerm bundles Symbols Nerd Font Mono
as a built-in fallback (DD-012), so plain Monaspace would have drawn the same glyphs. The
patched build is taken anyway because `Monaspace Krypton NF` is the family name the config
asks for on every other machine the owner uses, and only the patched build answers to it.
Within it, the `SemiWide` and `Wide` faces are dropped: a terminal never asks for them, they
are two thirds of the archive, and leaving them installed only gives font matching a chance
to pick one.

**CJK is Noto, and that is a substitution.** IBM publishes Plex Sans SC, TC and JP only as
GitHub release archives of 523 MB, 367 MB and 317 MB, and Fedora packages no CJK Plex at all.
`google-noto-sans-cjk-fonts` covers the same three scripts in one `dnf` line. The *order* —
Simplified, then Traditional, then Japanese — is what decides which regional form a shared
Han character is drawn in, so it is preserved exactly. The **static** package is used rather
than `google-noto-sans-cjk-vf-fonts` because its `.ttc` files expose `Noto Sans CJK SC` / `TC`
/ `JP` as plain family names, which is what the config asks for by name and what the build
asserts.

**What the macOS config lost.** Three settings are macOS-only and are not carried over:
`macos_window_background_blur`, and the two `send_composed_key_when_*_alt_is_pressed` keys
(of which the left-alt one was set twice in the original, the second assignment winning).
`window_background_opacity = 0.75` **is** kept, and it behaves differently here: WezTerm
never asks for a blurred background region on Wayland, so KWin's blur effect does not apply
to it and niri has no blur at all. The window is transparent over whatever is behind it, at
full detail.

**Consequences.**
- **The build proves the whole path.** `wezterm ls-fonts` prints the family it resolved for
  each entry of the fallback chain, and — like `zellij setup --check` (DD-033) — **exits 0
  regardless**, so the greps are the assertion. Run with `HOME` pointed at an empty directory
  and `XDG_CONFIG_DIRS=/etc/xdg`, the only way `Monaspace Krypton NF` can be the primary font
  is if the config was found by the real search path, parsed, and its fonts located. A
  renamed colour scheme is caught separately, because WezTerm logs
  `scheme was not found` and then carries on with its default.
- **Version bumps are manual, for both fonts.** Two version/hash pairs in
  `common-base.yml`, and the vendored OFL text has to be re-checked against the new tag.
- **315 MB is downloaded to install 31 MB.** Monaspace publishes no per-family archive; the
  temp directory is removed in the same layer, so only the 14 faces reach the image.
- **Monaspace ships no licence file in its archive**, so the OFL text is vendored in the
  overlay at `/usr/share/licenses/monaspace-krypton-nf/LICENSE`. IBM's archive *does* carry
  one beside the font, and that copy is installed from the archive rather than vendored.
- **`unzip` is now a layered package.** Both archives are ZIPs and the build container is not
  assumed to have it, for the same reason `git` is listed explicitly (DD-026).
- **A user's config replaces this one wholesale**, exactly as with zellij and fastfetch.
  `cp /etc/xdg/wezterm/wezterm.lua ~/.config/wezterm/` is the documented start, and the
  shipped colour schemes keep working underneath it.
- **`XDG_CONFIG_DIRS` is now set for every user session.** It states the spec default, so
  nothing that already behaved correctly changes — but it is a variable many programs read,
  not only WezTerm, and it is set from this image rather than inherited.

---

## DD-035 — Set the login shell from the image, because `chsh` does not exist here

**Status:** Accepted

**Supersedes:** [DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder)
*(its login-shell row only; everything it says about system files stands)*

**Reinstates:** [DD-028](#dd-028--make-zsh-the-login-shell-once-per-account)

**Implements:** `IMG-024`

**Context.** DD-028 shipped a boot service that moved existing accounts to zsh. DD-030
removed it, on the grounds that a service editing `/etc/passwd` is "a large hammer for a
command the owner runs once":

> **An existing account needs one `chsh -s /usr/bin/zsh`.**

**That command does not exist on this image.** Aurora deletes it:

```sh
# ublue-os/aurora, build_files/base/16-override-install.sh
# Footgun, See: https://github.com/ublue-os/main/issues/598
rm -f /usr/bin/chsh /usr/bin/lchsh
```

So the trade DD-030 made was not "a service versus one command" but "a service versus
`chsh: command not found`". Every published Qubix image has told its owner to run a command
the base image removes, in `docs/shell.md`, `docs/usage.md`, `docs/overview.md`,
`docs/recipe-reference.md` and the recipe comments. The account created at install time —
the only one that matters on a personal machine — has been on bash the whole time, which
also made the entire zsh half of DD-026 unreachable: a terminal spawns the login shell, and
WezTerm sets no `default_prog`.

`usermod -s` is the replacement, not a different `chsh`. It comes from shadow-utils, which
Aurora keeps; it does not consult `/etc/shells`; and as root it needs no password — which is
what makes a service its natural home rather than something the user types.

**Decision.** `qubix-default-shell.service` returns, with DD-028's three rules unchanged:

| Rule | Why |
|---|---|
| Ordered `Before=systemd-user-sessions.service` | That unit is the gate that permits logins, so nobody is logged in when `usermod` runs, and the first login of the boot is already in zsh |
| UID 1000–60000 only | Human accounts. **`root` keeps bash**, so a broken zsh can never cost anyone their recovery shell |
| One attempt per account, stamped in `/var/lib/qubix-os/default-shell/` | Every account is stamped **on sight**, changed or not. Bash is what an account inherited; anything else was a choice, and a choice is not something to overrule every boot |

**Consequences.**
- **A rebase gives you zsh at the next boot**, on an account that already existed, with no
  per-user action and nothing to read first.
- **`sudo usermod -s /bin/bash $USER` sticks.** The account is stamped, so nothing reverts
  it. That property is what makes a service acceptable: the image gets one attempt per
  account, never a standing veto. Opting out ahead of time is
  `sudo touch /var/lib/qubix-os/default-shell/<user>`.
- **`chsh` is gone from every instruction in this repository.** Where a manual command is
  still worth giving, it is `sudo usermod -s …`, and the pages say why. A user who wants
  `chsh` back can layer `util-linux-user`; the build assertion on `/etc/shells` is kept for
  exactly that case, since `usermod` itself never reads it.
- **The build asserts `usermod` exists.** The service is useless without it, and the failure
  would otherwise appear as a silent no-op at boot on somebody's machine.
- `/etc/default/useradd` stays and is unchanged: it covers accounts created afterwards, and
  the service covers the ones that were there.
- Cost, unchanged from DD-028: this repository ships **one system unit that modifies
  `/etc/passwd`**. It is the largest hammer here, and the once-ever stamp is not optional.
- This is the second time this decision has been reversed. What was missing both times was
  not judgement about hammers but a fact about the base image — recorded now, in the recipe
  comment, in the unit, and in the script, so the next reversal has to argue with the
  evidence.

---

## DD-036 — Wire zsh from the end of `/etc/zshrc`, not from `/etc/zshenv`

**Status:** Accepted

**Supersedes:** [DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder)
*(its zsh-wiring row only)*

**Implements:** `IMG-025`

**Context.** DD-030 moved the zsh setup into `/etc/zshenv`, because Fedora's copy of that
file is comments only and replacing it therefore costs nothing. That is true, and it is the
wrong file. zsh reads, for an interactive login shell:

| # | File | What the image has there |
|---|---|---|
| 1 | `/etc/zshenv` | *was* the entire zsh setup |
| 2 | `/etc/zprofile` → `/etc/profile` → `/etc/profile.d/*.sh` | `STARSHIP_CONFIG`, `ATUIN_*`, `LG_CONFIG_FILE`, `EDITOR` |
| 3 | `/etc/zshrc` | Fedora's default `PROMPT`, and the `profile.d` loop for non-login shells |
| 4 | `~/.zshrc` | the user's own |

Row 1 runs before row 2. **Every variable the image exports for these tools was being set
after the tools had been initialised.** It works today only because starship and atuin
re-read their environment at prompt time; nothing in the design guarantees that, and the
next tool that reads its configuration at init time gets the wrong answer with no visible
cause.

Two smaller costs of the same position, checked against Fedora's own files (rawhide
dist-git, `zshrc.rhs`) rather than assumed:

- `/etc/zshrc` line 11 is `[[ "$PROMPT" = "%m%# " ]] && PROMPT='[%n@%m]%~%# '`. It runs
  *after* `/etc/zshenv`, so the only thing standing between Fedora's prompt and starship's
  is that guard being there.
- `/etc/zshenv` is read by **every** zsh, scripts included. Holding an interactive setup
  there requires an `-o interactive` guard, which is the file telling you it is the wrong
  one.

**Decision.** Source the zsh half from the **end of `/etc/zshrc`**, which zsh reads only for
interactive shells, after the `profile.d` loop and after Fedora's `PROMPT` line, and before
the user's own `~/.zshrc`. `files/system/etc/zshenv` is deleted, so Fedora's file returns on
the next rebase.

**Appended at build time, not shipped as a file.** `/etc/zshrc` carries real behaviour, so
vendoring its 50 lines into the overlay to add six of ours would mean owning Fedora's copy
forever — the objection DD-026 raised, and it was right. A `containerfile` snippet appends
only what is ours and leaves upstream's content flowing through untouched.

Three assertions make that safe, in the same spirit as the zellij and WezTerm checks:
`grep` for Fedora's `_src_etc_profile_d` before appending (a base image with a different
`/etc/zshrc` fails the build), `grep` against appending twice, and `zsh -n` over the result
so a broken shell fails in CI rather than at somebody's login.

**Consequences.**
- **The environment is in place before the tools that read it start**, which is what this
  record is for. `STARSHIP_CONFIG` in particular now exists at `starship init` time rather
  than a few files later.
- **`~/.zshrc` still runs last and still wins**, with nothing here to undo — unchanged from
  DD-030, and still the reason `compinit` may run twice for an account whose `~/.zshrc` came
  from Fedora's skeleton.
- **zsh-syntax-highlighting still cannot wrap widgets defined in a user's own `~/.zshrc`.**
  That cost is inherent to any system-wide wiring and is unchanged; the one-line fix is
  still to re-source `/usr/share/qubix-os/shell/qubix.zsh` at the end of `~/.zshrc`.
- **Non-interactive zsh no longer parses any of this.** `zsh -c` in a script reads Fedora's
  comments-only `/etc/zshenv` and stops, as it did before DD-030.
- **One upstream file is now appended to rather than replaced**, and one replacement is
  given back. `/etc/zshenv` returns to Fedora's on rebase, because the live copy matches the
  previous deployment's default and rpm-ostree therefore takes the new one. Anyone who
  edited `/etc/zshenv` by hand keeps their edit — and would then source the zsh half twice;
  the tools guard against double initialisation, the plugins do not.
- The append is not idempotent by itself, which is why the second `grep` exists. Each build
  starts from a fresh base layer, so the block is written exactly once per image.

---

## DD-037 — Guard shell setup on what a shell owns, never on what it inherits

**Status:** Accepted

**Amends:** [DD-026](#dd-026--wire-the-shell-from-a-one-line-pointer-in-each-users-rc-file),
[DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder),
[DD-032](#dd-032--lazygit-is-a-tool-of-its-own-configured-from-usr-through-lg_config_file)
*(their guards only; the delivery mechanism each chose stands)*

**Implements:** `IMG-026`

**Context.** Reported 2026-08-03: starship does not appear when zsh is started from bash, or
bash from zsh. Every guard in the terminal environment turned out to have the same defect,
and it is a defect of kind rather than of detail — each one tests an **exported** variable,
and an exported variable is inherited by every child process. So each guard answered *"has
anybody, anywhere up my process tree, done this?"* when it was written to mean *"has this
shell already done this?"*

Confirmed against the tools' own output, not inferred:

| Guard | What the variable actually is | What went wrong |
|---|---|---|
| `[[ -z ${STARSHIP_SHELL-} ]]` | `starship init zsh` ends with `export STARSHIP_SHELL="zsh"`; the bash init with `="bash"` | **No nested shell of any kind got the prompt** — zsh→bash, bash→zsh and zsh→zsh alike |
| `[[ -z ${ATUIN_SESSION-} ]]` | `atuin init zsh` runs `export ATUIN_SESSION=$(atuin uuid)` | A nested zsh got no Ctrl-R search and no widgets |
| `[ -z "${STARSHIP_CONFIG:-}" ]`, `[ -z "${LG_CONFIG_FILE:-}" ]`, the `ATUIN_*` block | exported by this image, from `/etc/profile.d` | Resolved once and inherited for the life of the session — see below |

The atuin case is the sharpest, because atuin had already solved the problem: its init opens
with `[[ -z "${ATUIN_SESSION:-}" || "${ATUIN_SHLVL:-}" != "$SHLVL" ]]`, which re-issues the
session id when the shell nests. Wrapping that in a guard on the same variable did nothing
but stop it running.

The third row costs something subtler and is the reason this record covers the environment
blocks too. **The graphical session reads `/etc/profile.d` as well** — SDDM's
`wayland-session` sources `/etc/profile` — so "does the user have a `starship.toml` of their
own?" was answered once, at login, exported, and inherited by every terminal opened
underneath. `docs/shell.md` promises that creating the file wins with nothing to undo. It
did win, after a logout.

**Decision.** One rule, applied everywhere: **guard on something the shell cannot inherit.**

- **Interactive setup guards on a function.** Functions are not passed to child processes,
  so `_atuin_precmd` and the starship entry in `precmd_functions` are true "has *this* shell
  been initialised" tests. In zsh the starship test is
  `[[ -z ${precmd_functions[(r)*starship*]} ]]`, which matches whichever function this
  starship registers rather than naming one; in bash it is `declare -F starship_precmd`.
- **Exported values are re-resolved in every shell**, and left alone whenever they hold
  anything other than the image's own literal path. That literal is the whole safety
  mechanism: `STARSHIP_CONFIG=/usr/share/qubix-os/starship.toml` can only have come from
  this image or from someone who typed it deliberately, so rewriting it is safe, and
  rewriting anything else is not.
- **Turning a block off means unsetting it**, not skipping it. A user who creates
  `~/.config/atuin/config.toml` mid-session gets the five `ATUIN_*` variables unset in the
  next shell, because leaving them set is exactly the override the guard exists to prevent.

**Rejected: a sentinel variable of our own** (`_QUBIX_STARSHIP_SET=1`) to mark what the image
exported. It is one more exported variable to leak, and it answers a question the literal
path already answers.

**Consequences.**
- **Every interactive shell gets the full environment**, however it was started — from a
  desktop launcher, from another shell, over SSH, or on a text console.
- **Double initialisation is still prevented**, which is what DD-036's last consequence
  relies on, and now for the case that actually occurs: sourcing the file twice in one
  shell. A user who runs `starship init` from `~/.zshenv` is still not given a second one.
- **A user's own config wins in the next shell, not the next login.** This is the promise
  `docs/shell.md` already made; it is now true.
- **The guards depend on function names the tools do not treat as API.** If starship or
  atuin renamed theirs, the effect is a second `eval` in one shell — `add-zsh-hook` and
  starship's own `PROMPT_COMMAND` check both deduplicate — so the failure mode is a few
  wasted milliseconds, not a broken shell. The zsh starship test uses a pattern rather than
  a name for that reason.
- **A user who exports `ATUIN_STYLE` themselves *and* keeps a `config.toml`** has it unset
  here. That combination was already overridden before this change, in the other direction;
  the config file is the documented way to set these.

---

## DD-038 — Append `/etc/xdg` to `XDG_CONFIG_DIRS`, in both places a shell can come from

**Status:** Accepted

**Amends:** [DD-034](#dd-034--ship-wezterms-configuration-in-etcxdg-and-the-fonts-it-names-from-upstream)
*(the mechanism that makes its config reachable; the location it chose stands)*

**Implements:** `IMG-027`

**Context.** Reported 2026-08-03 alongside DD-037: the WezTerm theme is not applied.
`$XDG_CONFIG_DIRS` is the only route to `/etc/xdg/wezterm/wezterm.lua` — WezTerm reads that
variable literally and does **not** fall back to the `/etc/xdg` the XDG base directory
specification calls the default (DD-034) — and DD-034 set it in exactly one file,
`/usr/lib/environment.d/50-qubix-terminal.conf`. That file has two holes, and they are
independent:

- **environment.d only reaches what the systemd *user manager* starts.** It is the manager's
  own environment, passed to the units it launches. A shell reached over SSH is a child of
  sshd; one on a text console is a child of logind's `getty`; one from `su -` is a child of
  su. None of them is the user manager, so none of them has the variable — and neither does
  anything launched from one.
- **`${XDG_CONFIG_DIRS:-/etc/xdg}` does nothing to a variable that is already set.** `:-`
  only fills in an empty value, so a session exporting a list without `/etc/xdg` in it kept
  that list and the config stayed unreachable. Plasma's list does contain `/etc/xdg`, from
  kde-settings, which is why this has not bitten in a Plasma login; that is a property of
  one session manager, not a guarantee.

**Decision.** Append rather than default, in both places a shell's environment can come from.

```
# /usr/lib/environment.d/50-qubix-terminal.conf
XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:+${XDG_CONFIG_DIRS}:}/etc/xdg
```

```sh
# /etc/profile.d/qubix-shell-env.sh
case ":${XDG_CONFIG_DIRS:-}:" in
    *:/etc/xdg:*) ;;
    *) XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:+${XDG_CONFIG_DIRS}:}/etc/xdg"; export XDG_CONFIG_DIRS ;;
esac
```

`:+` is supported in `environment.d`, and the man page's own example is this exact shape for
`LD_LIBRARY_PATH`. environment.d has no conditionals, so it cannot test membership and may
append a second `/etc/xdg` to a session that had one; that costs nothing, because every
consumer of the list merges the same file with itself. The shell copy *can* test membership,
and does, since it runs far more often.

**`/etc/xdg` goes last in both.** Earlier entries win in the XDG specification, so appending
adds a fallback without taking precedence from a directory the session chose deliberately —
`/usr/share/kde-settings/kde-profile/default/xdg` above all. Nothing is removed and nothing
is reordered.

**Consequences.**
- **The WezTerm config is reachable from every shell**, and from anything launched out of
  one, not only from units the user manager started.
- **A session that exports its own list now gets `/etc/xdg` added to it** rather than
  silently keeping a list without it.
- **Plasma is unchanged.** Its list already contains `/etc/xdg`, so the shell path matches
  and does nothing; the environment.d path may duplicate the entry, which changes no
  behaviour.
- **This affects more than WezTerm.** `XDG_CONFIG_DIRS` is the KConfig cascade
  (`/etc/xdg/kdeglobals`, DD-012 and DD-023), the MIME associations
  (`/etc/xdg/mimeapps.list`), and fastfetch's fourth search entry. All of them gain a
  guarantee they were relying on the session to provide.
- **It is still not set for a bare `sh -c` from a daemon**, which reads no profile and is not
  a user unit. Nothing in this image needs it there.

---

## DD-039 — A command that copies the image's config into `~/.config`, and nothing that runs it

**Status:** Accepted

**Amends:** [DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder)
*(it adds a route into `$HOME`; the rule that **nothing in the image takes** that route
stands, and is the reason this is a command rather than a service)*

**Implements:** `IMG-028`

**Context.** Every configuration this image ships lives in `/usr` or `/etc`, where a rebase
replaces it and a user's own file shadows it. That default is right, and DD-030 is what
bought it: no runtime seeder, no writes to `$HOME`, so anyone who has customised nothing
keeps receiving improvements with nothing to re-run.

It leaves *starting* to customise awkward, and more so than it looks. Six configurations,
six source paths in three different trees, and three different relationships with the
image:

| | Your file | Relationship |
|---|---|---|
| starship, fastfetch, zellij, wezterm, niri | replaces the image's | wholesale — you now maintain all of it |
| lazygit | merges over the image's | key by key, so copying it all throws that away |
| niri | replaces the image's | **and breaks the session if copied verbatim** |

That last row is the one that decided this. `/etc/niri/config.kdl` includes the palette with
`include "qubix-theme.kdl"` — a **relative** include, which niri resolves against the
including file's own directory. Copied into `~/.config/niri/` it names a file that is not
there. `docs/desktops.md` warned about it in prose; prose is not a good place for a step you
cannot skip.

**Decision.** Ship `/usr/bin/qubix-config`: one command that copies any of the six into
`~/.config`, lists what is available, and diffs a copy against what the image ships today.

**Nothing runs it.** Not at login, not on first boot, not ever. This is the whole reason it
is a command and not the seeder DD-030 removed: an account that never runs it has nothing in
`~/.config` and keeps tracking the image, so the convenience reaches the people who asked
for it and changes nothing for anybody else. `/etc/skel/.config/` was the other candidate
and reaches only accounts created afterwards — on a personal machine, nobody.

**It knows the three things a `cp` does not:**

- **niri's include is rewritten** to the absolute `/etc/niri/qubix-theme.kdl` — the line
  `docs/desktops.md` already asked people to keep — so a personal config still receives
  palette changes and still live-reloads (DD-022, DD-025). The rewrite is **asserted**: if
  the pattern ever stops matching, the command refuses to write rather than producing a
  session that does not load.
- **WezTerm's colour schemes are deliberately not copied.** WezTerm looks for `colors/` in
  every config directory, so leaving them in `/etc/xdg/wezterm/colors/` keeps them available
  to a personal `wezterm.lua` *and* tracking the image (DD-034). Only what you edit is
  forked.
- **lazygit says that a whole copy is usually wrong**, because its config merges key by key
  and a file holding only the changed keys keeps everything else tracking the image
  (DD-032).

**Safety, in the order it matters:** it never overwrites without `--force`, `--force` keeps
the previous file as a timestamped `.bak`, and it refuses to run as root — `sudo
qubix-config` would fill a home directory with root-owned files its owner then could not
edit. `--list`, `--diff` and `--check` write nothing and are allowed anywhere, which is what
lets the build run `--check`.

**The build asserts the command, because it hardcodes paths.** `qubix-config --check`
verifies that all six sources exist in the image and that niri's relative include still
matches, so a configuration that moves fails CI rather than turning into "not in this image"
at somebody's terminal. This is the same shape as the zellij and WezTerm assertions
(DD-033, DD-034).

**Consequences.**
- **The default is unchanged.** `/usr` and `/etc` are still where configuration lives, and
  an account that never runs this is exactly as it was.
- **A copy is a fork, and the command says so** — every run that writes something ends by
  saying it, and `--diff` is the way to see what a rebase has changed since. That is the
  honest cost of editing, and it is now visible at the moment it is incurred rather than
  buried in a page.
- **Six `cp` instructions leave `docs/`.** They are replaced by one command, which removes
  the chance of following the niri one literally.
- **Adding a configuration to the image means adding it to this table**, or it is the one
  thing users cannot easily take over. `--check` does not catch that omission — nothing can.
- **atuin and the zsh half are not in the table**, and that is correct rather than
  incomplete: atuin ships no file at all (it is configured from the environment, DD-030), and
  `/usr/share/qubix-os/shell/qubix.zsh` is *sourced* rather than shadowed — the supported
  customisation is the documented `source` line at the end of `~/.zshrc`, not a copy.

---

## DD-040 — Undo Aurora's `fastfetch` alias, because it beat the config search path

**Status:** Accepted

**Amends:** [DD-031](#dd-031--ship-fastfetchs-config-in-etc-with-the-logo-pinned)
*(its reasoning about where the config goes is correct and unchanged; what it missed is that
nothing typed `fastfetch` ever got as far as reading it)*

**Implements:** `IMG-030`

**Context.** Reported repeatedly from 2026-08-03: fastfetch shows Universal Blue's box, not
this image's, and copying the config into `~/.config` did not help either. Established on
the machine:

```
$ type -a fastfetch
fastfetch is an alias for ublue-fastfetch
fastfetch is /usr/bin/fastfetch

$ grep -rn fastfetch /etc/profile.d/
/etc/profile.d/ublue-fastfetch.sh:3:alias fastfetch='ublue-fastfetch'
```

`ublue-fastfetch` runs fastfetch against `/usr/share/ublue-os/fastfetch.jsonc`. **A shell
alias is resolved before `$PATH`, and an explicit `--config` is resolved before any config
directory**, so the alias beat the entire search path DD-031 reasoned about so carefully.
`/etc/fastfetch/config.jsonc` was correct, present, and unreachable — and so was
`~/.config/fastfetch/config.jsonc`, which is worse, because that one is the user's.

This is a good lesson about the shape of the mistake rather than the mistake itself. DD-031
verified fastfetch's search order in its source and picked the only location that works. All
of that was right. What it never checked was whether the **name** `fastfetch` still meant
the binary on this base image — three rounds of diagnosis went into config paths, `/etc`
merges and `$XDG_CONFIG_DIRS` before anybody ran `type -a`.

**Decision.** Ship `/etc/profile.d/zz-qubix-fastfetch.sh`, which removes that one alias:

```sh
case "$(alias fastfetch 2>/dev/null)" in
    *ublue-fastfetch*) unalias fastfetch 2>/dev/null || true ;;
esac
```

**A second file, named to sort last.** `/etc/profile.d` is sourced in alphabetical order and
`qubix-shell-env.sh` sorts *before* `ublue-fastfetch.sh` (q < u), so an unalias in the file
we already ship would be undone a moment later. `zz-` exists for that and nothing else.

**Aurora's file is not replaced.** It carries `neofetch` and `neowofetch` aliases that are
upstream's to define; replacing it would mean owning their copy forever to delete one line.
Undoing one alias leaves the rest flowing through — the same reasoning DD-036 used for
appending to `/etc/zshrc` rather than vendoring it.

**Guarded on the alias being ublue's**, so it is a no-op if upstream ever stops setting it,
and so an alias somebody set on purpose is not silently removed. A user's own alias is safe
regardless: `~/.bashrc` and `~/.zshrc` are both read after `/etc/profile.d`.

**The build asserts the result, not the ordering** (module 4h). It sources every file in
`/etc/profile.d` the way a shell does and then asks whether the alias survived. Depending on
`zz-` sorting last is fragile and invisible when it breaks — a vendor file named `zzz-*.sh`
would silently restore it — so the check tests the thing that matters. Verified to fail on
exactly that case before being trusted.

**Consequences.**
- **`fastfetch` means fastfetch**, and therefore reads `/etc/fastfetch/config.jsonc`, and
  therefore a user's `~/.config/fastfetch/config.jsonc` wins over it. DD-031's design works
  as written for the first time.
- **Nothing is removed.** `ublue-fastfetch` is still a command and still prints Universal
  Blue's banner; `neofetch` and `neowofetch` still point at it.
- **One more upstream file we depend on the contents of.** If Aurora renames
  `ublue-fastfetch`, the guard stops matching and the alias comes back — the build assertion
  is what turns that into a CI failure rather than a silent regression.
- **`type -a` belongs in the diagnosis of any "my config is ignored" report**, before the
  search path. A base image can rename a command out from under a config file, and this one
  does. Written into `.agent/context/files-system.md` as a gotcha for the same reason.

---

## DD-041 — Draw the full Fedora mark, and move the box to its gutter

**Status:** Accepted

**Supersedes:** the logo half of
[DD-031](#dd-031--ship-fastfetchs-config-in-etc-with-the-logo-pinned)
*(where the config goes is unchanged; which logo it draws, how wide the box is, and the
reason the logo is pinned at all are all replaced here)*

**Implements:** `IMG-031`

**Context.** Asked on 2026-08-03: the `"logo"` block could come out of
`config.jsonc` — but with it gone, fastfetch draws the **full** Fedora mark and the box is
written straight over it. The mark occupies columns 1–44; the box's left spine is pinned at
column 23. Everything from `│` leftwards lands inside the artwork.

**DD-031's reason for pinning the logo was wrong.** It said:

> fastfetch picks its logo from `ID=` in `os-release`, and this image rewrites that to
> `qubix_os_bluebuild` (DD-003) — a name no builtin logo matches — so detection falls
> through to the generic 23-column penguin.

Detection does not stop at `ID`. `logoGetBuiltinDetected` in `src/logo/logo.c` tries, in
order:

| # | Field tried | This image's value | Match? |
|---|---|---|---|
| 1 | `ID` | `qubix_os_bluebuild` (DD-003) | no |
| 2 | `NAME` | `QubixOS-BlueBuild` (DD-003) | no |
| 3 | each word of `ID_LIKE` | `fedora`, from the base image | **yes** |
| 4 | kernel name | `Linux` | — |
| 5 | fallback | `unknown` | — |

DD-003 rewrites `ID`, `NAME` and `PRETTY_NAME` and nothing else, so `ID_LIKE` survives.
Step 3 is where the match happens by elimination rather than by inspection of the base
image: the mark that appeared on the machine is Fedora's, steps 1 and 2 cannot produce it,
and step 4 is `Linux`. On a booted deployment the one-line confirmation is
`grep -E '^(ID|NAME|ID_LIKE)=' /etc/os-release`. Either way the penguin was never on the
table; what the block was actually holding back was the full 38-column mark. Neither the old reason nor the old measurement survived a
re-measure — widths taken from fastfetch 2.61.0 with this config's padding (`+2` left,
`+4` right):

| Logo | Width | Gutter | Left spine | Right spine | Terminal needed |
|---|---|---|---|---|---|
| **`fedora`** | **38** | **44** | **45** | **112** | **112 columns** |
| `fedora_small` | 16 | 22 | 23 | 90 | 90 columns |
| `unknown` (the fallback) | 30 | 36 | 37 | 104 | 104 columns |

DD-031 recorded the fallback as 23 wide with a 29-column gutter. It is 30 and 36.

**Decision.** Keep the `"logo"` block, change `"source"` to `fedora`, and re-derive all four
columns from the 44-column gutter: left spine **45**, labels **51**, separator **61**, right
spine **112**. The box itself is unchanged — still 68 columns wide, still drawn with CHA, and
because spine and right spine moved together the `─` runs in the rule lines needed no edit.

The columns were not re-derived by hand. `/usr/share/qubix-os/fastfetch/retune.sh` — shipped
by DD-031 for exactly this — was run against the config: it asks fastfetch to print the logo
with no modules, reads the `ESC[<n>C` step the binary emits, and rewrites the four numbers
*and* the comment block that documents them. That is the first use of the tool for the job it
was written for, and it worked unmodified.

**Why the logo stays pinned, when detection would now pick the same mark.** Because
"would now" is the whole problem. The four columns are load-bearing and derived from one
number, and two ordinary events change that number without touching this repository: a
fastfetch release that adds a `qubix` builtin logo (step 1 starts matching), or a base image
that drops `ID_LIKE` (step 3 stops). Either moves every column silently. Naming the logo
costs one line and makes the layout a property of the config rather than of the environment.

**Consequences.**
- **The box needs a 112-column terminal**, up from 90. That is the cost the owner accepted
  for the full mark, and it is real: a WezTerm in Niri's default half-width column is around
  100 columns on the 1920px panel, so the box overruns it there. `Mod+R` (two-thirds) or
  `Mod+F` (maximised) is the room it needs. The requirement is stated in the config header
  and in `docs/shell.md`.
- **`fedora_small` remains one edit away**, and the escape hatch is the same tool: set
  `"source": "fedora_small"` in your own copy and run `retune.sh`, which puts the spine back
  at 23 and the right edge at 90.
- **A wrong reason survived longer than a wrong result would have.** DD-031's pin produced
  the right layout for two versions of the wrong explanation, and nothing exercised it until
  someone asked what happens when the block is deleted. The general form: a claim about
  *what would happen otherwise* is never tested by the happy path, so it is worth spending a
  command on. Here it took two: `fastfetch --logo <name> --structure Break` for every width
  in the table above, and a read of `logoGetBuiltinDetected` for the order the fields are
  tried in. Both are cheap next to a claim that stood in three files.

---

## DD-042 — Measure the logo gutter two ways, because fastfetch changed how it draws one

**Status:** Accepted

**Amends:** [DD-031](#dd-031--ship-fastfetchs-config-in-etc-with-the-logo-pinned), which
shipped `retune.sh`; the tool's job is unchanged, only how it reads the gutter

**Implements:** `IMG-032`

**Context.** On the machine, immediately after
[DD-041](#dd-041--draw-the-full-fedora-mark-and-move-the-box-to-its-gutter):

```
$ /usr/share/qubix-os/fastfetch/retune.sh
retune: could not measure the logo gutter
```

The tool asks fastfetch to draw the logo with no modules and reads the gutter out of the
result. Until fastfetch 2.64.0 that meant one escape sequence: the logo was printed as a
block, then the cursor stepped back up and across with `ESC[1G ESC[<height>A
ESC[<gutter>C`, and `ESC[<n>C` was the number. 2.64.0 "reworks the built-in logo printing
logic — ASCII logos and modules are now printed line by line". There is no step to read any
more; each module line simply begins with `<gutter>` literal spaces. The image tracks
Fedora's fastfetch, which is well past 2.64, so the tool DD-031 shipped for exactly this job
could not do it on the image it ships in.

Both forms were confirmed by running the same command under two binaries — the installed
2.61.0 and an upstream 2.66.0 release tarball:

| fastfetch | First line of `--structure Break` output | Gutter is |
|---|---|---|
| 2.61.0 | `…logo art…` `ESC[1G` `ESC[20A` `ESC[44C` | the `C` parameter |
| 2.66.0 | `ESC[m` + 44 spaces | the count of spaces |

**Decision.** Read both, old form first, and take whichever answers.

The new form is only exact because the measurement run now passes
**`--logo-padding-top 1`**. Without it the first line of output carries the logo's first row
*and* the padding, so the gutter could only be recovered by counting art — which breaks on
the first logo that uses a glyph that is not one byte and one column wide, the very problem
CHA exists to avoid (DD-031). Pushing the logo down one line makes that first line the
gutter and nothing else, so the count is of spaces only.

**The failure now explains itself.** It names both forms it looked for, prints the exact
command to run by hand, echoes fastfetch's own stderr — previously sent to `/dev/null`,
which is why the first report carried no information — and states the arithmetic
(`gutter + 1 / 7 / 17 / 68`) so a human can finish the job without the tool.

**Consequences.**
- **The box itself was never affected.** CHA is absolute positioning; it does not care
  whether fastfetch reaches a column by stepping or by printing spaces. The shipped config
  renders identically under 2.61.0 and 2.66.0 — columns 45, 51, 61, 112 in both — which was
  checked before touching the tool, because "the layout is broken" and "the tool that
  measures the layout is broken" call for different fixes.
- **A tool that reads another program's output is coupled to that program's rendering**, and
  this one now carries two readings of it. That is the cost of measuring rather than
  assuming; the alternative — hardcoding widths per logo name — would have been wrong in a
  quieter way, since the numbers would drift with upstream's ASCII art and nothing would
  say so.
- **`--logo-padding-top` is now load-bearing for measurement.** If it is ever removed, the
  new-form reading loses its exactness and the error message is what will say so.
- **Version-sniffing without a version number.** Neither reading asks what fastfetch it is
  talking to, so a build that emits the old form, the new form, or a future third form is
  handled or reported, not silently mis-measured.

## DD-043 — Give a distrobox container the host's shell: link the text, install the binaries

**Status:** Accepted

**Extends:** [DD-030](#dd-030--configure-the-shell-with-system-files-and-no-runtime-seeder),
one level down — the same "point at the image, do not copy it" rule, applied inside a
container

**Implements:** `IMG-033`

**Context.** A shell inside `distrobox enter` came up bare: no starship prompt, no atuin
history search, no zsh plugins. It could not have been otherwise. A distrobox container is a
different distribution with its own `/etc`, its own `/usr` and its own package manager, and
every tool in [`shell.md`](shell.md) is a host package read from a host path.

What distrobox does bring across, established against **1.8.2.5** — the version in both f43
and f44, and the one `ublue-os/main`'s `packages.json` puts in every Universal Blue base
image, Aurora DX included:

| It brings | How | So |
|---|---|---|
| The shell | `distrobox-create` passes `--env SHELL=$(basename $SHELL)`; `distrobox-init` installs the package of that name and gives the container user that shell | A container created while the account is on zsh **has** zsh — one created before `qubix-default-shell.service` ran has bash |
| `$HOME` | Bind-mounted, same path | `~/.zshrc` is the same file in both, which is exactly why nothing here writes to it |
| The host's root filesystem | Mounted at `/run/host`, with `--security-opt label=disable` | Every file the image ships is *already there*, live |
| Most of the environment | Every `printenv` line that is not `HOME`, `PATH`, `SHELL`, `XDG_*_DIRS` … is passed with `--env` | `STARSHIP_CONFIG` and `LG_CONFIG_FILE` **arrive**, naming host paths that do not exist inside |

That last row is a bug on its own: `LG_CONFIG_FILE` naming a missing file is an error in
lazygit, not a skip.

**Decision.** Ship `/etc/distrobox/distrobox.conf` with a `container_init_hook`, and
`/usr/bin/qubix-distrobox-shell` for it to run inside the container at creation.

**Text is linked, binaries are installed.** starship and atuin are compiled against the
host's glibc and cannot be run out of `/run/host`, so they come from the container's own
repositories, along with the two plugin packages and zsh. Everything else — the shell files,
`starship.toml`, the lazygit config, the completion functions — is plain text and is read
from the host where it already is. One symlink does the whole of that half:

```
/usr/share/qubix-os -> /run/host/usr/share/qubix-os
```

With it, every absolute path in the host's own files resolves inside the container, and so
do the two environment variables that arrive from the host. **A rebase therefore changes the
container's shell too**, with nothing to re-run in it — DD-030's promise, one level down.
Copies would have been stale the first time the image changed.

**Why a hook and not `container_additional_packages`.** distrobox installs that list in one
transaction, and `distrobox-init` runs with `set -o errexit`, so a single name the guest
distribution does not have — Debian and Ubuntu package neither starship nor atuin — aborts
container creation and leaves a half-built container. The script installs the batch, and on
failure retries one package at a time and *reports* what the distribution does not have.

**The hook may never fail**, for the same reason: it is `eval`'d under that `set -e`. Every
step is best-effort and it exits 0 from inside a container whatever happened. It exits
non-zero only when it is not in a container or not root — the two cases only a human can
create.

**Two distribution differences are absorbed by the script**, not by teaching a host file
about every distribution: Arch and Alpine install the plugins to `/usr/share/zsh/plugins/`,
and Debian and Ubuntu install bat as `batcat`. Both get a symlink at the name
`shell/qubix.zsh` and `shell/common.sh` look for. The global zsh rc file is found the same
way — `/etc/zshrc` on Fedora, `/etc/zsh/zshrc` on Debian, Arch and Alpine — by identifying
the directory that already holds zsh's global startup files, since zsh will not say which it
was compiled for.

**Consequences.**
- **A container created after this comes up with the prompt, the history search and both
  plugins, with nothing typed into it.** Its zsh is wired the same way the host's is:
  appended to the end of the global `zshrc`, before `~/.zshrc`, which still wins.
- **An existing container is one command behind:**
  `distrobox enter <name> -- sudo /run/host/usr/bin/qubix-distrobox-shell`. The script is
  idempotent, and re-running it is also what moves a container user who is still on bash —
  because the container predates the login shell being zsh — over to zsh. That follows the
  host account, and replaces **only** bash, exactly as DD-035 does.
- **`/etc/distrobox/distrobox.conf` replaces nothing.** The Fedora `distrobox` RPM owns no
  file in that directory (checked against the package's file list), and `ublue-os-just`'s
  `*.ini` assemble manifests, which do live there, are untouched.
- **Command-line flags beat the config**, because distrobox parses them after sourcing it.
  So `distrobox create --init-hooks '' …` opts one container out — and a `distrobox
  assemble` manifest with its own `init_hooks=` key **replaces** this hook rather than
  adding to it, which is worth knowing before wondering why one container came up bare.
  Opting every container out is commenting one line in a file in `/etc`, which is writable
  and survives a rebase.
- **Container creation now needs the network and takes longer**, by one package transaction.
  That is the price of the tools being real binaries.
- **A guest whose repositories lack a tool gets everything else and is told.** The shell
  files skip what is not installed — silently, by design — so the script says out loud what
  it could not install and what is therefore missing.
- **`zsh-completions` is not installed in the container**; the host's
  `/run/host/usr/share/zsh/site-functions` is put on `$fpath` instead. Completion functions
  are plain zsh, so they work in any container, but they describe the *host's* tools.
- **One history database, because `$HOME` is shared.** The container's atuin writes to the
  host's `~/.local/share/atuin/history.db`, which is the useful behaviour and also the one
  risk worth stating: a container whose distribution ships a newer atuin migrates that
  database on first run, and the host's atuin then has to read the migrated schema. A Fedora
  container tracks the same package version the host does.
- **This is coupled to distrobox's internals** — the config search path, `/run/host`, and
  the hook running as root — which are implementation, not an interface anyone promised. The
  2.0 release replaces these shell scripts with a Go binary. The build asserts that
  `distrobox-create` still names `/etc/distrobox/distrobox.conf`, so that change fails CI
  with a note to re-check rather than producing containers that quietly come up bare.

---

## DD-044 — A plan section for work that is finished but unconfirmed

**Status:** Accepted

**Extends:** [DD-011](#dd-011--documentation-plan-and-context-cache-are-part-of-the-deliverable),
whose plan contract this refines

**Implements:** `AGT-006`

**Context.** There is no local build (`AGENTS.md` §6), so nearly every image task ends in a
criterion of the shape *"on the rebased image, X works"*. Nobody can tick that from a
checkout. The convention up to now was to leave the whole task `[ ]` until somebody rebased
a machine and looked — which is correct about the criterion and wrong about the task.

The cost compounded quietly. By 2026-08-04, `plan.md` held **twenty-two** tasks in **Open**
whose code, documentation, decision records and context entries had all shipped, sitting in
the same list as `MNT-001` (replace the template `CODEOWNERS`), which nobody had touched.
The two are indistinguishable at a glance, and *the list of what to work on next* is the one
question the file exists to answer. An agent reading it in a fresh session would reasonably
start re-implementing something already in the image.

**Decision.** Split the tracker three ways, and tick in the commit that earns the tick.

| Section | Holds | Leaves when |
|---|---|---|
| **Done** | Every criterion met | — |
| **Awaiting confirmation** | Shipped and documented; the only criterion left needs a built image on hardware | Somebody confirms it, and records the date in the criterion |
| **Open** | Not started, or in progress | Its implementing commit lands |

The confirmation criterion stays in the task, and stays unmet until it is met — it is not
dropped, and "shipped" is not redefined as "done". What changes is that a task waiting on a
person with a laptop no longer looks like a task waiting on a contributor.

**The tick moves in the same commit as the work.** A sweep that ticks boxes later is a
second source of truth about what is finished, maintained by hand, and it drifts between
sweeps — which is exactly what happened here.

**Consequences.**
- **Open answers "what should I pick up?"** and nothing else. Anything in it is genuinely
  unstarted or in progress.
- **Awaiting confirmation is a queue for the person with the hardware**, not for a
  contributor. It is a list of things to *look at*, in one place, instead of a criterion
  buried in the twelfth bullet of a task.
- **Confirmations are dated** — `*(confirmed YYYY-MM-DD)*` — so a later regression report can
  be placed against the build that was actually checked. `IMG-011` already did this by hand;
  it is now the form.
- **A task can be confirmed in pieces**, and when it is, it stays in Awaiting confirmation
  with the confirmed criteria dated individually. Partial confirmation is not completion.
- Cost: one more move per task, and a section that is empty whenever the machine is current
  — as it is at the time of this record. An empty section is the intended steady state, not
  a sign the layout is unused.

## DD-045 — Nothing a container hook prints may start with `Error:`

**Status:** Accepted

**Amends:** [DD-043](#dd-043--give-a-distrobox-container-the-hosts-shell-link-the-text-install-the-binaries),
whose design is unchanged; what it got wrong is what a hook may *say*, and what to do for a
container that can install none of the tools

**Implements:** `IMG-034`

**Context.** Entering a cross-compilation container on the image DD-043 shipped:

```
Executing init hooks...   Error: Unable to find a match: zsh-autosuggestions
                          zsh-syntax-highlighting starship atuin bat
```

and the enter stopped there. No shell, no `[ OK ]`, nothing further.

DD-043 was careful that the hook could never *exit* non-zero, because `distrobox-init` runs
under `set -o errexit`. That guarantee held and was beside the point. **`distrobox enter`
follows the container's log while it initialises and switches on the start of every line**
(`distrobox-enter`, the `while IFS= read -r line` loop):

| Line begins with | What the watcher does |
|---|---|
| `Error:` | prints it in red, then **`exit 1`** — the enter is abandoned |
| `Warning:` | prints it in yellow |
| `distrobox:` | becomes the name of the setup step being displayed |
| anything else | **discarded**, stdout and stderr alike |

dnf says `Error: Unable to find a match: …` for a name a distribution does not carry. So a
package this container was never going to have ended the enter from the *host* side, no
matter what the hook did afterwards. Two smaller things are in the same paste: every
`qubix-distrobox-shell: …` line was dropped for matching no prefix, so the script's own
report was invisible; and the name-by-name retry did run, printing four more fatal lines
into a log nobody was reading any more.

The container was also the case DD-043 filed under "reported and skipped": a dnf container
with **none** of the five packages. Correct in principle, useless in practice — a container
with no starship is a container with no prompt, which is the feature.

**Decision.** Three changes, all in `qubix-distrobox-shell`.

**1. Capture, then re-prefix.** Every package manager runs with stdout and stderr captured
to `/var/tmp/qubix-distrobox-shell.log`, and that log is only ever echoed back through
`warn()`, which re-prefixes each line — a diagnostic that kills the enter would be a poor
diagnostic. The rule is now in the script's header, because the next person to add a command
there needs it before they add it.

**2. Speak the watcher's language.** `distrobox: ` for progress, `Warning: ` for anything
the user must see. Prefixing with the script's own name meant invisibility.

**3. Borrow from the host what the container cannot install — after proving it runs.** Plain
text is always safe, so the plugins now fall back to the host's copies. A host *binary* is
glibc-linked: it runs in a Fedora-family container of a similar vintage, cannot run against
musl (Alpine, Wolfi) at all, and fails on a missing symbol against an older glibc (Debian
11). So `--version` is run **in the container** and the link is made only if it answers. The
binary is linked into `/usr/local/bin`, which distrobox already puts on `$PATH` — rather than
putting `/run/host/usr/bin` on `$PATH`, which would expose every host binary and make
`command -v` lie about what the distribution has.

**Consequences.**
- **A container whose repositories carry none of this still gets the whole environment**, as
  long as its libc can run the host's binaries. That is the common case: a Fedora-family
  container on a Fedora host.
- **An Alpine or Wolfi container gets the text half and says so.** The plugins, the aliases
  and the configuration work; starship and atuin do not, and the reason is printed rather
  than left as a shell that silently has no prompt.
- **The skip-unavailable flag is kept separate from the install command** (`--skip-unavailable`
  for dnf5, `--setopt=strict=0` for dnf4, `--ignore-unknown` for zypper). A manager that does
  not know the flag fails *on the flag*, and the name-by-name pass that follows runs without
  it — otherwise the fallback would fail identically to the thing it is a fallback for.
- **`compinit` no longer stops to ask.** `compaudit` cannot establish ownership through the
  `/run/host` bind mount — the host's root maps to an unknown user inside the container — so
  the host's `site-functions` on `$fpath` made every shell prompt about insecure directories.
  The guest block runs `compinit -u` itself, before the host file that would otherwise run it
  plain. `-u` rather than `-C`: the directories are used, and the dump is still rebuilt.
- **The build cannot test any of this.** The assertion in module 4i still only parses the
  script and checks the config names it; running it in the build container would be running
  it in a container, which is exactly the thing it is designed to modify.
- **This is one more coupling to distrobox's internals** — its log watcher, on top of DD-043's
  config path and `/run/host`. Worth knowing when its 2.0 rewrite lands: the prefixes are the
  first thing to re-check.

---

## DD-046 — Keep a container's `$fpath` to what the container owns, and replace the block instead of skipping it

**Status:** Accepted

**Amends:** [DD-045](#dd-045--nothing-a-container-hook-prints-may-start-with-error), whose
`compinit -u` fixed one shell out of two, and
[DD-043](#dd-043--give-a-distrobox-container-the-hosts-shell-link-the-text-install-the-binaries),
whose guest block could not be revised once written

**Implements:** `IMG-035`

**Context.** Reported from the machine on 2026-08-04, entering an ordinary Fedora container:

```
$ distrobox enter fedora-box
zsh compinit: insecure directories and files, run compaudit for list.
Ignore insecure directories and files and continue [y] or abort compinit [n]?
```

That is a question at the top of every shell in every container, and DD-045 had already
been written to stop it. Two separate things were wrong.

**1. `-u` on our own `compinit` settles nothing, because ours is not the last one.** The
guest block puts `/run/host/usr/share/zsh/site-functions` on `$fpath` — the host's
completion functions — and `compaudit` cannot establish ownership through the `/run/host`
bind mount: the host's root is an unmapped uid inside a rootless container, so the
directory is owned by neither root nor the user, which is the definition of insecure. `-u`
means *this* `compinit` uses the directory anyway and says nothing. It has no effect on the
next one, and there is reliably a next one: the skeleton `~/.zshrc` Fedora ships calls
`compinit` plainly, `$HOME` is shared with the host, and `~/.zshrc` runs **after**
`/etc/zshrc`.

And answering `y` does not even buy the completions it asks about. `compinit` drops every
insecure directory from `$fpath` before it dumps — `fpath=(${fpath:|_i_wdirs})`, right
after the prompt — so the host's functions were about to be discarded either way. The
directory could only ever be worth a prompt, never worth an answer.

Nothing can be repaired at the file's own end. A symlink does not help: `compaudit`'s glob
qualifiers use `-`, so they follow symlinks and see the host's uid. A copy would be secure,
and would be a copy — the thing DD-043 exists not to make.

**2. The hook could not deliver the fix.** It read the container's global `zshrc`, found
`qubix-os/shell/qubix.zsh` in it, said "already carries the Qubix block" and stopped. So
every container was pinned to the block that the image shipped on the day it was created,
and the documented catch-up command —
`distrobox enter <name> -- sudo /run/host/usr/bin/qubix-distrobox-shell` — could not change
a single line of it. A container is not rebuilt by a rebase; that command is the only route
a change has into one.

**Decision.**

**1. The host's completions do not go on a container's `$fpath`.** A container uses its own
distribution's completion functions, and `compinit` runs plainly — from
`shell/qubix.zsh`, as it does on the host, with no `-u` anywhere. No shell in a container
has an insecure directory to ask about, whichever `compinit` runs last.

**2. The block is delimited and replaced.** It is written between
`# ── Qubix OS ──…` and `# ── end of the Qubix OS block ──…`, and a re-run deletes that
range before appending the current one. The result is built in a candidate file beside the
real one and installed with `cat` — keeping the file's own mode, owner and SELinux label —
only after `zsh -n` parses it, so nothing on the way to a failure can leave a container with
a broken `zshrc`.

**Consequences.**
- **The prompt is gone for every `compinit`, not just ours**, including the one in a user's
  own `~/.zshrc` and the one in `oh-my-zsh`.
- **A container gets its own distribution's completions, not the host's.** For a Fedora
  container that is very nearly the same set; for a Debian one it is the right set. What is
  genuinely lost is `zsh-completions`, which the host installs from a pinned upstream tag
  (DD-026) and Fedora does not package — a container has whatever it can install. This is a
  smaller loss than it looks, because a plain `compinit` was discarding those functions
  anyway.
- **A fix now reaches containers that already exist**, with one command and no re-creation.
  Re-running the hook twice produces a byte-identical file, rehearsed before shipping.
- **The one-off migration is announced and backed up.** A block written before the end
  marker existed has no end, so it is replaced *to the end of the file*; anything a person
  appended below it in the container's `zshrc` goes with it. The hook warns, and leaves the
  file as it was at `<zshrc>.qubix-old`.
- **The end marker is now load-bearing.** Anything that edits the guest block must keep both
  markers, or the next run will append a second block instead of replacing the first.
- **Still nothing is copied.** The block is four lines of pointer; every byte of behaviour is
  read live from the host through `/usr/share/qubix-os` (DD-030, DD-043).

---

## DD-047 — Float each DMS bar component, but migrate presentation only once

**Status:** Superseded by
[DD-048](#dd-048--make-the-bar-canvas-transparent-and-keep-each-component-background-rounded)

**Implements:** `BRD-005`

**Extends:** [DD-025](#dd-025--the-image-owns-the-palette-users-own-their-shell-settings)

**Context.** DD-025 gave Niri and DankMaterialShell one palette, but left DMS's stock bar
geometry alone: a continuous strip behind tightly packed components. The approved
2026-08-05 design removes that strip and presents each visible component as a separate
Slate capsule. The launcher should carry the full-colour Qubix cube supplied with the
request. Those bytes are already the canonical 512 px PNG at
`/usr/share/pixmaps/qubixos-logo.png`, so another asset would only drift.

DMS still has no system-wide settings layer. Its current
[`SettingsSpec.js`](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Common/settings/SettingsSpec.js)
does, however, expose the needed presentation fields natively, and
[`LauncherButton.qml`](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Modules/Bar/Widgets/LauncherButton.qml)
accepts an absolute custom-logo path. A shell fork is unnecessary.

**Decision.** Apply this native DMS preset to every valid bar:

| Scope | DMS setting | Value |
|---|---|---|
| Per bar | `noBackground` | `true` |
| Per bar | `spacing` / `innerPadding` / `widgetPadding` | `8` / `4` / `8` |
| Per bar | `widgetTransparency` | `0.96` |
| Per bar | `widgetOutlineEnabled` | `true` |
| Per bar | `widgetOutlineColor` / `widgetOutlineOpacity` / `widgetOutlineThickness` | `primary` / `0.28` / `1` |
| Per bar | `borderEnabled` / `shadowIntensity` / `squareCorners` | `false` / `0` / `false` |
| Global | `widgetBackgroundColor` | `sc` (`surfaceContainer`) |
| Global | launcher mode / path / colour override / size offset | `custom` / `/usr/share/pixmaps/qubixos-logo.png` / empty / `4` |

The existing `qubix-dms-theme` seeder owns delivery, but the two kinds of setting have
different lifetimes. It continues to enforce only the three palette-pointer keys at each
Niri login. Bar presentation and launcher keys are a **versioned, one-time migration**,
recorded only after the settings rename succeeds at
`$XDG_STATE_HOME/qubix-os/dms-bar-style-v1`. The migration updates presentation keys on
every valid existing bar while preserving its `leftWidgets`, `centerWidgets`,
`rightWidgets`, and every unrelated setting. Only an absent or empty `barConfigs` gets
DMS's upstream default groups.

**Consequences.**

- New and existing accounts receive the approved design on their first Niri login after
  the image update, while later personal styling survives subsequent logins.
- A future intentional redesign increments `BAR_STYLE_VERSION`; changing values without a
  version bump changes nothing for already-migrated users.
- Invalid settings JSON remains untouched, as under DD-025. An invalid `barConfigs` value
  is not styled or stamped, although the independently owned palette pointer can still be
  repaired. A failed stamp write is safe: the merge is idempotent and retries next login.
- Removing the version stamp and starting `qubix-dms-theme.service` reapplies the preset.
  Masking the unit opts out of future migrations and palette-pointer enforcement together.
- The canonical PNG gains a consumer; no DMS source or artwork is duplicated.
- Static checks can prove the merge and failure rules, but the final layout and logo still
  need confirmation in a Niri login from a built image.

---

## DD-048 — Make the bar canvas transparent and keep each component background rounded

**Status:** Accepted

**Implements:** `BRD-005`

**Supersedes:** [DD-047](#dd-047--float-each-dms-bar-component-but-migrate-presentation-only-once)

**Context.** The version-1 preset reached real hardware and produced the inverse of the
approved design: one large coloured bar remained, while components had transparent
centres inside square outlines. The setting names had been read as descriptions rather
than traced to the rectangles that consume them.

DMS source at commit
[`2baf048`](https://github.com/AvengeMedia/DankMaterialShell/tree/2baf048293cfe4c34d9dad4fbcc2e8203ed9ba34)
makes the layering explicit:

- [`DankBarBody.qml`](https://github.com/AvengeMedia/DankMaterialShell/blob/2baf048293cfe4c34d9dad4fbcc2e8203ed9ba34/quickshell/Modules/DankBar/DankBarBody.qml)
  passes `barConfig.transparency` as the alpha of the outer `BarCanvas`; `1` is opaque and
  `0` is transparent.
- [`BasePill.qml`](https://github.com/AvengeMedia/DankMaterialShell/blob/2baf048293cfe4c34d9dad4fbcc2e8203ed9ba34/quickshell/Modules/Plugins/BasePill.qml)
  makes a component transparent **and sets its radius to zero** when `noBackground` is
  true. When false, the component uses `Theme.cornerRadius` and its configured widget
  background.
- The widget outline is a second rectangle in `BasePill`. With version 1's transparent,
  zero-radius component, that outline was the reported square.

**Decision.** Preset version 2 corrects the layer ownership:

| Scope | DMS setting | Value | Result |
|---|---|---|---|
| Per bar | `transparency` | `0.0` | Outer `BarCanvas` has no visible fill |
| Per bar | `noBackground` | `false` | Each component retains its own fill and normal rounded corners |
| Per bar | `widgetOutlineEnabled` | `false` | No second square or decorative shape around a component |
| Per bar | `spacing` / `innerPadding` / `widgetPadding` | `8` / `4` / `8` | Component surfaces are visibly separated and comfortably padded |
| Per bar | `widgetTransparency` | `0.96` | Component fill remains distinctly Slate without becoming heavy |
| Per bar | `squareCorners` / `borderEnabled` / `shadowIntensity` | `false` / `false` / `0` | No square outer corners, border, or per-bar shadow override |
| Global | `barElevationEnabled` | `false` | No global elevation shadow remains around the invisible canvas |
| Global | `widgetBackgroundColor` | `sc` (`surfaceContainer`) | Components use the intended Slate surface |

The cube launcher settings from DD-047 remain unchanged. `BAR_STYLE_VERSION` becomes `2`,
so the new `$XDG_STATE_HOME/qubix-os/dms-bar-style-v2` stamp is absent even for accounts
that already carry version 1. The correction therefore applies once on their next Niri
login and then returns ownership of presentation settings to the user.

**Consequences.**

- The outer bar window and input region still exist, as DMS requires, but paint no
  background or elevation. Only the rounded component backgrounds are visible.
- DMS's global corner radius is not overwritten. The image gets its normal 16 px default;
  a user who deliberately changes the global radius keeps that choice.
- Old version-1 outline colour and thickness keys may remain inert in a settings file;
  `widgetOutlineEnabled=false` ensures they paint nothing without deleting user data.
- Widget order, unrelated settings, malformed-input handling, and atomic writes retain the
  preservation rules from DD-047.
- The corrected appearance still requires one more real-hardware confirmation before
  `BRD-005` is done.

---

## DD-049 — Rebuild early boot and own the Plasma splash package

**Status:** Accepted

**Implements:** `IMG-007`

**Extends:** [DD-004](#dd-004--rebrand-by-overwriting-upstream-asset-paths), whose exact-path
overrides remain the compatibility mechanism, but are no longer the only Plasma mechanism

**Context.** The standard image was confirmed on hardware to show Aurora during cold boot
and inherited Aurora/KDE artwork while Plasma started. The files in the checkout looked as
though both surfaces were covered, but each had a boundary the overlay did not cross.

**Plymouth reads an archive made before Qubix exists.** Aurora runs dracut while building
its base image. Qubix then overlays
`/usr/share/plymouth/themes/spinner/watermark.png` in a later image, but Plymouth runs from
the initramfs before the real root is mounted. The correct file in `/usr` therefore sat
unused while early boot read Aurora's already-embedded copy. The CachyOS recipe happened
to rebuild its initramfs for its replacement kernel; the standard recipe never did.

**Aurora has two Plasma splash packages and the image covered one asset in one of them.**
Aurora's current
[`Containerfile`](https://github.com/get-aurora-dev/common/blob/main/Containerfile) copies
the splash into separate `dev.getaurora.aurora.desktop` and
`dev.getaurora.auroralight.desktop` packages. Its
[`Splash.qml`](https://github.com/get-aurora-dev/common/blob/main/system_files/shared/usr/share/plasma/look-and-feel/dev.getaurora.aurora.desktop/contents/splash/Splash.qml)
draws a centre distro logo and, separately, a bottom-right “Plasma made by KDE” footer and
KDE mark. Replacing only the dark package's `aurora_logo.svgz` could not affect the light
package or that second logo.

There is a third persistence layer: Plasma writes a user's splash choice to
`~/.config/ksplashrc`. That file correctly outranks the distro profile under
`/usr/share/kde-settings/`, and a rebase must not silently erase a deliberate user choice.

**Decision.** Treat early boot and Plasma login as two explicit delivery paths.

1. `recipe.yml` runs BlueBuild's `initramfs` module after the overlay and identity rewrite,
   immediately before `signing`. The CachyOS recipe keeps its own run after the kernel
   swap. The module is not shared through `common-base.yml`: that position is too early
   for the replacement kernel.
2. Ship a narrow `com.qubixos.desktop` Plasma look-and-feel package containing only a
   startup splash. Its QML draws the canonical Qubix SVG on black and contains no inherited
   Aurora/KDE footer. The distro-profile `ksplashrc` selects it for accounts without a
   personal choice.
3. Override `Splash.qml` in both Aurora dark and light package IDs with the same Qubix-only
   surface. Existing accounts which still name either Aurora ID are fixed without rewriting
   their home directory.
4. Do not override Breeze. An account which explicitly selected Breeze keeps that choice;
   `branding.md` gives the GUI path and `kwriteconfig6` command for selecting Qubix again.

**Consequences.**

- The standard and CachyOS images each perform one late dracut run. Standard pays the build
  cost for correct Plymouth branding; CachyOS's already-required kernel run does both jobs.
- Plasma has a Qubix-named selectable splash instead of relying exclusively on a path whose
  public name is Aurora. The compatibility overrides still accept the old IDs.
- The splash uses `/usr/share/pixmaps/qubixos-logo.svg` as its canonical artwork, so dark,
  light, and Qubix-native packages cannot drift to three different logo files.
- KDE remains the desktop and retains its attribution everywhere else; only the transient
  distro startup surface stops drawing the separate KDE footer.
- A personal Breeze choice can still show KDE after rebase by design. This is documented
  persistence, not a failed image override.
- There is no local image build. YAML, JSON, paths, and QML can be checked statically, but
  the initramfs contents and both visible transitions remain awaiting confirmation on a
  built image running on hardware.

---

## DD-050 — Fcitx 5 Pinyin from Fedora, with system fallbacks rather than a user seeder

**Status:** Accepted

**Implements:** `IMG-036`

**Context.** Simplified Chinese input needs three distinct pieces: an input-method
framework, a Chinese engine, and integration with both applications and the compositor.
The [Rocky Linux 10 KDE reference guide](https://www.qubik65536.top/posts/2025-12-23-InstallChineseInputOnRockyWorkstation10KDE)
had to compile Fcitx 5, `xcb-imdkit`, the Chinese addons, OpenCC, and the KDE configuration
tool because RHEL 10 and EPEL did not package the complete stack. Repeating those builds in
Qubix OS would add unowned source revisions, build dependencies, and an update path for
software Fedora already maintains.

Fedora packages the whole path: [`fcitx5`](https://packages.fedoraproject.org/pkgs/fcitx5/fcitx5/),
[`fcitx5-chinese-addons`](https://packages.fedoraproject.org/pkgs/fcitx5-chinese-addons/fcitx5-chinese-addons/),
[`fcitx5-autostart`](https://packages.fedoraproject.org/pkgs/fcitx5/fcitx5-autostart/),
the [GTK](https://packages.fedoraproject.org/pkgs/fcitx5-gtk/fcitx5-gtk/) and
[Qt](https://packages.fedoraproject.org/pkgs/fcitx5-qt/fcitx5-qt/) bridges, and KDE's
[`kcm-fcitx5`](https://packages.fedoraproject.org/pkgs/fcitx5-configtool/kcm-fcitx5/).
Fcitx itself reads `profile` and `config` through its XDG package-config search path, and
KWin reads `kwinrc` through KConfig's cascade, so all three support a system default
without copying a file into a home directory.

**Decision.** Install Fedora's Fcitx 5 stack in `common-base.yml`, for every image. Ship
three XDG fallback files in the root overlay:

1. `/etc/xdg/fcitx5/profile` defines one group containing `keyboard-us` and `pinyin`, with
   Pinyin as the non-keyboard method.
2. `/etc/xdg/fcitx5/config` replaces Fcitx's trigger list with both `Super+space` and
   `Control+space`. The former is the documented Plasma shortcut; the latter is Niri's.
3. `/etc/xdg/kwinrc` points KWin's `[Wayland] InputMethod` at Fedora's host
   `/usr/share/applications/org.fcitx.Fcitx5.desktop`, making Fcitx the Plasma Wayland
   input-method client.

Niri keeps `Mod+Space` bound to DMS's spotlight, so the compositor consumes the Super
trigger before Fcitx sees it. Deliberately leave `Ctrl+Space` absent from Niri's bindings:
the key then reaches Fcitx and activates its native `Control+space` trigger. A hardware
test established why this boundary matters: `fcitx5-remote --check -s pinyin` and the
image's explicit-switch helper both worked from a terminal, while the Niri key remained
unresponsive. The compositor was not invoking the system binding, so adding more logic to
the spawned command could not fix it. Native Fcitx handling also survives a personal Niri
configuration, provided that configuration does not claim `Ctrl+Space` itself.

Keep `fcitx5-autostart`: its XDG entry starts Fcitx in Niri, where there is no KWin to own
the input-method process, and its Fedora profile fragment provides compatibility variables
for toolkit and XWayland applications. Do not remove IBus or any KDE component; the change
is additive.

That [Fedora profile fragment](https://src.fedoraproject.org/rpms/fcitx5/raw/rawhide/f/fcitx5.sh)
deliberately chooses the broad compatibility setting
`GTK_IM_MODULE=fcitx` for every graphical session. It is too broad once a Wayland
compositor's input-method frontend is working: Fcitx diagnoses both the forced GTK module
and the native text-input path and warns that the environment variable should be unset.
Ship `/etc/profile.d/zz-qubix-fcitx-wayland.sh` after Fedora's `fcitx5.sh` to unset only
`GTK_IM_MODULE` in Wayland sessions. Also set it to `null` in Niri's compositor environment
as a local defence; the profile fragment remains necessary for applications launched by
systemd services, which do not inherit Niri's environment block.

Unsetting a global variable must not discard GTK X11/XWayland input. Follow
[Fcitx's recommended split](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland) by setting
`gtk-im-module=fcitx` in GTK 3 and GTK 4's system
`settings.ini` files. Native Wayland GTK prefers its built-in input path, while GTK on X11
can select the packaged module. Leave `XMODIFIERS` and `QT_IM_MODULE` from Fedora's profile
intact: X11 still needs the former and non-KWin Qt applications still need the latter.

**Consequences.**

- No input-method component is compiled in this repository, and no third-party repository
  gains package-script authority. Fedora updates the framework and engines with the base.
- Plasma gets KWin's native text-input path; Niri and XWayland applications retain Fcitx's
  toolkit path. Both sessions use the same Fcitx profile in the same home directory.
- The effective shortcuts differ by session: Plasma uses `Super+Space`; Niri uses
  `Ctrl+Space` for input and retains `Super+Space` for its application launcher. Both are
  native Fcitx triggers, but Niri consumes only the Super chord. `Ctrl+Space` technically
  remains valid in Plasma too; that overlap trades strict session exclusivity for a switch
  that does not depend on Niri loading or executing a compositor binding.
- Native GTK applications no longer open a second Fcitx module path alongside the working
  Wayland frontend, so the **Wayland Diagnose** notification in Niri is resolved rather
  than hidden. GTK 3/4 X11 and XWayland clients keep a settings-based module fallback.
- `~/.config/fcitx5/profile` and `~/.config/fcitx5/config` win over their `/etc/xdg`
  fallbacks, and `~/.config/kwinrc` wins over `/etc/xdg/kwinrc`. The first user change
  becomes persistent without the image ever rewriting it.
- The default physical layout inside the Fcitx group is US. Users with another layout can
  replace `keyboard-us` in KDE's Input Method page; that creates the personal profile which
  then remains theirs.
- Personal GTK 3/4 `settings.ini` files can replace the system input-module default, and a
  user remains free to export `GTK_IM_MODULE` deliberately after the image's profile
  fragment if a specific application requires it.
- A checkout can verify package names, file syntax, and cascade paths, but actual Pinyin
  entry in native Wayland and XWayland clients under both sessions needs the built image.

---

## DD-051 — NVIDIA variants inherit Aurora Open; CachyOS rebuilds that driver from source

**Status:** Accepted

**Implements:** `IMG-037`

**Extends:** [DD-016](#dd-016--one-recipe-per-variant-composed-from-shared-module-files)
and [DD-017](#dd-017--ship-a-cachyos-kernel-variant-as-a-separate-image-not-an-option)

**Context.** Qubix needs NVIDIA and NVIDIA+CachyOS images without turning the shared
recipe into a hardware switch. Aurora's current NVIDIA image is
[`aurora-dx-nvidia-open`](https://github.com/ublue-os/aurora/pkgs/container/aurora-dx-nvidia-open/):
it carries NVIDIA's open kernel modules, userspace driver, and Universal Blue integration
matched to the exact Fedora kernel in that image. Universal Blue documents the open driver
for [Turing and newer hardware](https://github.com/ublue-os/akmods#nvidia-hardware-support);
Pascal and Maxwell need the older proprietary flavour and are outside Aurora's current
image set.

That prebuilt module cannot be copied across a kernel swap. Kernel-module RPMs require one
exact `kernel-uname-r`, which is why DD-017 removes every inherited `kmod-*` with Fedora's
kernel. CachyOS also [stopped publishing prebuilt NVIDIA modules on
2026-02-23](https://github.com/CachyOS/copr-linux-cachyos), advising RPM Fusion or
Negativo17 instead. BlueBuild's
[`akmods` module](https://blue-build.org/reference/modules/akmods/) uses Universal Blue's
cached module images and explicitly does not support custom kernels, so it cannot bridge
the gap.

Negativo17 is nevertheless the same source Universal Blue consumes. Its current
`akmod-nvidia` package builds NVIDIA's open kernel modules, and Universal Blue's own
[`akmods` builder](https://github.com/ublue-os/akmods/blob/main/build_files/nvidia/build-kmod-nvidia.sh)
invokes that package with `KERNEL_MODULE_TYPE=open`. The CachyOS swap already installs
`kernel-cachyos-devel-matched`, so the headers needed for a direct source build exist.

Fedora 44 introduced a packaging contradiction in the ostree compose path. Its
[`akmods-ostree-post`](https://src.fedoraproject.org/rpms/akmods/blob/f44/f/akmods-ostree-post)
hook invokes `akmodsbuild` directly as root, while the same branch's
[`akmodsbuild`](https://src.fedoraproject.org/rpms/akmods/blob/f44/f/akmodsbuild) refuses
to run when `/var` is root-writable. Installing `akmod-nvidia` in the immutable base
therefore fails its `%post` before a later explicit build can run. The ordinary `akmods`
orchestrator has the correct privilege split: it runs as root, delegates compilation to
the dedicated `akmods` account, and installs the resulting RPM with root privileges.

That split also exposes container filesystem modes hidden by the old root build. RPM 6
creates build scripts under `/var/tmp` and its build tree under `/tmp`; both must have the
normal sticky, world-writable mode `1777`. The ostree container path can leave `/var/tmp`
inaccessible to the build account—an established Universal Blue edge case with a prior
[`/var/tmp` preservation fix](https://github.com/ublue-os/hwe/commit/48dd697ff4cab166256603db34a43ccd13884f8f).
Restoring `1777` is not a special NVIDIA permission: it reinstates standard temporary-file
semantics, where the sticky bit prevents users from deleting files owned by one another.

**Decision.** Publish two additional, independently signed recipes:

| Recipe | Published image | Base | Kernel-module path |
|---|---|---|---|
| `recipe-nvidia.yml` | `qubix-os-bluebuild-nvidia` | `aurora-dx-nvidia-open:latest` | Inherit Aurora's prebuilt NVIDIA Open module and matching Fedora kernel together |
| `recipe-nvidia-cachyos.yml` | `qubix-os-bluebuild-nvidia-cachyos` | `aurora-dx-nvidia-open:latest` | Swap to CachyOS, then build Negativo17 `akmod-nvidia` against that exact kernel |

Use `nvidia-cachyos`, not `nvidia-cachy`, so the public name composes the existing stable
`nvidia` and `cachyos` identifiers. The suffix says which image to pull; documentation and
`PRETTY_NAME` say **NVIDIA Open** so nobody mistakes it for the legacy proprietary kernel
module.

Keep the source build in `common-nvidia-cachyos.yml`, after
`common-kernel-cachyos.yml` and before identity/initramfs. It must:

1. install `akmods` first so its build account and compose hook exist;
2. back up and temporarily short-circuit `akmods-ostree-post`, enable Negativo17, and
   install `akmod-nvidia` with the rest of its package transaction unchanged;
3. restore Fedora's original hook, set `/tmp` and `/var/tmp` to `1777`, and prove the
   `akmods` account can write both before any compilation;
4. identify the sole `/usr/lib/modules/<kver>` directory left by the swap and run
   `akmods --force --kernels <kver> --kmod nvidia` with `KERNEL_MODULE_TYPE=open`, then
   `depmod`;
5. fail unless all five expected NVIDIA modules resolve through `modinfo`, the primary
   module reports its open licence, and `nvidia-smi` is installed;
6. run `initramfs` only afterwards, so the archive sees the completed module tree.

Do not silently fall back to Nouveau and do not publish a combined recipe containing only
NVIDIA userspace. A failed driver build is a failed variant build.

**Consequences.**

- Turing and newer are the supported NVIDIA boundary. Qubix publishes no Pascal/Maxwell
  legacy-driver image.
- The Fedora-kernel NVIDIA image stays on Aurora's supported path and receives its driver
  as part of the daily base update.
- NVIDIA+CachyOS is explicitly experimental. Every daily image build recompiles a module
  across two independently moving upstreams; CI can prove compilation and file presence,
  but only hardware can prove GPU initialisation and `nvidia-smi` operation.
- The Fedora 44 hook workaround exists only across the `akmod-nvidia` install transaction.
  The final image contains the original distro helper, not a Qubix fork; when Fedora fixes
  the privilege mismatch, this compatibility block can be removed without changing the
  driver-build policy.
- The scratch-directory repair remains valid beyond that Fedora fix: `1777` is the normal
  mode for `/tmp` and `/var/tmp`, and explicit preflight checks turn future ostree mode
  regressions into an immediate, readable build failure.
- The combined recipe retains `akmod-nvidia` and the CachyOS development package. That is
  intentional: the published module is built in CI, while the source package keeps the
  provenance and a diagnostic rebuild path visible instead of hiding generated files.
- Both CachyOS recipes retain DD-017's unsigned-kernel Secure Boot caveat. Rebuilding the
  NVIDIA module does not sign the kernel, and the kernel's disabled module-signature
  enforcement does not turn that into a locked-down boot chain.
- CI grows from two to four independent matrix jobs. `fail-fast: false` keeps a driver or
  CachyOS regression from cancelling the unaffected variants.

---

## DD-052 — Suspend NVIDIA+CachyOS publication but retain its recipe

**Status:** Accepted

**Implements:** `BLD-002`

**Amends:** [DD-051](#dd-051--nvidia-variants-inherit-aurora-open-cachyos-rebuilds-that-driver-from-source)

**Context.** DD-051 deliberately made the combined NVIDIA+CachyOS build fail closed when
the replacement-kernel driver could not be compiled. Repeated Fedora 44 CI attempts did
exactly that: first the `akmod-nvidia` package hook rejected a root build, then the
privilege-separated build account could not create RPM scratch files. Each workaround
revealed another compose-specific failure before any image reached hardware validation.

The Fedora-kernel NVIDIA recipe is independent of that custom build. It inherits Aurora's
kernel and NVIDIA Open driver as one matched unit and has no reason to be held back. The
standard and plain CachyOS images are independent too. Continuing to put the failing
combined experiment in every matrix wastes a runner and makes otherwise healthy workflow
runs red without producing a usable fourth release.

**Decision.** Remove `recipe-nvidia-cachyos.yml` from both automatic `all` selection and
the `workflow_dispatch` choices. Publish three active images: standard, CachyOS, and
Fedora-kernel NVIDIA. Keep `recipe-nvidia-cachyos.yml` and
`common-nvidia-cachyos.yml` in the repository as parked implementation work; do not delete
their fail-closed module assertions or silently publish a userspace-only substitute.

Documentation must call the combined image disabled and unpublished. Users with supported
NVIDIA hardware are directed to the active Fedora-kernel NVIDIA image. Re-enabling the
combined recipe requires a clean CI build first, then restoring it in both workflow
selector locations and updating the task, documentation, and this decision's successor.

**Consequences.**

- Scheduled, push, pull-request, and manual `all` runs contain three matrix jobs.
- Manual dispatch cannot accidentally build or publish the parked recipe.
- An old registry tag, if one exists from an earlier attempt, is not deleted by this
  repository change and must be treated as stale rather than as a supported release.
- There is temporarily no Qubix image combining CachyOS with NVIDIA. Supported NVIDIA
  users choose the Fedora-kernel NVIDIA image; the active CachyOS image remains for
  systems that do not need NVIDIA's out-of-tree driver.
- DD-051 continues to define the retained recipe's fail-closed design, while this record
  suspends its publication policy.

---

## DD-053 — Use GTK for Niri's file chooser, without adding Nautilus

**Status:** Accepted

**Implements:** `IMG-038`

**Context.** Zed's save-path selector and Ungoogled Chromium's download-location selector
both failed to open in Niri. The applications use different toolkits and packaging, but
both cross the same `org.freedesktop.portal.FileChooser` interface. Niri's upstream portal
profile sets `default=gnome;gtk;` without mapping that interface. Since GNOME 47,
`xdg-desktop-portal-gnome` delegates its file chooser to Nautilus. Qubix receives the GNOME
and GTK portal backends from niri's weak dependencies, but it does not install Nautilus.

Adding Nautilus would also make the chooser work, at the cost of installing and maintaining
a second graphical file manager on an Aurora/KDE image. Selecting the KDE portal globally
would couple Niri to Plasma's session services. The already-installed GTK portal implements
`FileChooser` directly and is niri upstream's documented alternative when Nautilus is not
installed.

**Decision.** Ship `/etc/xdg-desktop-portal/niri-portals.conf` with niri's complete upstream
selection plus `org.freedesktop.impl.portal.FileChooser=gtk;`. Keep GNOME first in the
default list for screencasting and other interfaces, and preserve the explicit GTK Access
and Notification plus gnome-keyring Secret mappings. Do not install Nautilus and do not
change KDE's portal profile.

Use the administrator configuration path in `/etc` so this image policy outranks the niri
RPM's `/usr/share` default. Do not ship a one-key fragment: portal profiles are selected as
whole files rather than merged across precedence levels.

**Consequences.**

- Portal-aware native and Flatpak applications use the GTK chooser in Niri.
- Niri screen capture continues through the GNOME backend; Plasma continues through its
  own KDE profile selected by `$XDG_CURRENT_DESKTOP`.
- No additional file manager is installed.
- A personal `~/.config/xdg-desktop-portal/niri-portals.conf` still wins. It must carry the
  complete desired profile; `qubix-config niri-portals` provides a safe starting copy, and
  portal services need a fresh login after it changes.
- The image change can prove the selected configuration and installed backend statically;
  opening both reported dialogs still requires a built image and a Niri login.

---

## DD-054 — Generate installer ISOs manually and retain them only as Actions artifacts

**Status:** Accepted — amended by DD-056

**Implements:** `BLD-003`

**Context.** Qubix previously pointed users at a local BlueBuild ISO procedure. That made
installation media depend on a Fedora Atomic workstation and left no reproducible record
of the generator version or inputs. The requested use case needs the file after a CI run,
but does not need a durable public release.

Generating an installer after every daily image build would create three multi-gigabyte
artifacts even when nobody needs installation media. It would also couple a successful OCI
publication to a second, unrelated Lorax build. A manual workflow can instead select an
existing tag when media is actually needed.

The upstream
[`JasonN3/build-container-installer`](https://github.com/JasonN3/build-container-installer)
action accepts the registry, image name, tag, Fedora version, and Kinoite variant, and
emits an ISO plus checksum. Its `image_signed` input configures the installed deployment's
future update reference as signed; it does not authenticate the action's own registry copy.
A mutable `latest` tag could also change between an independent verification and that copy.

**Decision.** Add a separate `iso` workflow with `workflow_dispatch` as its only trigger.
It supports the three active published images and an explicit OCI tag. It derives Fedora's
major version from the verified manifest's `org.opencontainers.image.version` label rather
than asking the dispatcher to duplicate image metadata. It builds x86_64 Kinoite media
with `build-container-installer` v1.5.0 pinned to its immutable commit.

Before invoking the generator, verify the selected tag against the repository's
`cosign.pub`, extract the signed manifest digest, and pass `docker://…@sha256:…` through
the action's `image_src` input. Retain the human-selected tag as the installed system's
signed update target. Pin every workflow action to a commit and annotate its release.

Upload the ISO and generated SHA-256 checksum together as an uncompressed GitHub Actions
artifact, fail if either is missing, and retain it for seven days. Do not create a GitHub
Release or push installation media to another store.

**Consequences.**

- ISO generation consumes no runner or artifact storage until a maintainer dispatches it.
- A successful image build does not imply a successful installer build; the ISO workflow
  has its own run, logs, 120-minute timeout, and failure triage.
- The ISO payload is tied to the digest whose Qubix signature was verified, even when the
  requested update channel is the mutable `latest` tag.
- The dispatcher cannot accidentally pair a tag with the wrong installer repositories.
  Version discovery is metadata-only and comes from the exact signed digest.
- If BlueBuild removes or reformats `org.opencontainers.image.version`, ISO generation
  fails closed until the workflow identifies another signed source of the Fedora major.
- Artifacts are temporary and require download within seven days. They are not releases;
  users verify the accompanying checksum before writing media.
- The combined NVIDIA+CachyOS recipe remains unavailable because DD-052 does not publish
  it. Re-enabling that image also requires adding it to the ISO choice and mapping.
- Local YAML and action-contract checks can validate the workflow definition; only an
  actual GitHub run can prove Lorax completes, and only booting the result can prove the
  resulting installation media on hardware.

---

## DD-055 — Rebuild weekly on Sunday at 00:00 UTC

**Status:** Accepted — supersedes DD-009

**Implements:** `BLD-004`

**Context.** DD-009 scheduled an unattended build every day so Qubix would follow Aurora
updates within roughly 24 hours. Each scheduled run now builds three active variants, and
the desired unattended cadence is once a week. Push, pull-request, and manual dispatch
already provide immediate builds when repository work or an urgent refresh requires one.

**Decision.** Schedule the image workflow with `00 00 * * 0`, which GitHub Actions
interprets in UTC and runs on Sunday at 00:00. Keep the push, pull-request, and
`workflow_dispatch` triggers unchanged.

**Consequences.**

- Without an intervening push or manual dispatch, Qubix can trail a newly published
  Aurora base, CachyOS kernel, or NVIDIA base by nearly seven days.
- Routine unattended CI usage drops from seven matrix runs per week to one.
- Maintainers can still dispatch a single active variant or all active variants after an
  urgent upstream release.
- References to the daily cadence in older decision records describe the policy in force
  when those records were accepted; this record owns the current cadence.

---

## DD-056 — Generate ISO artifacts after successful default-branch image publication

**Status:** Accepted — amends DD-054

**Implements:** `BLD-005`

**Context.** DD-054 made ISO generation manual to avoid routinely retaining three
multi-gigabyte artifacts. The desired policy is instead that newly published images have
matching installation media without another maintainer action. The image workflow builds
on pushes, pull requests, manual dispatches, and the weekly timer, but only a successful
default-branch run represents a complete current publication suitable for `latest` media.

Triggering on every image-workflow completion without guards would be wrong: a pull-request
or feature-branch completion would rebuild the unrelated public `latest` tag, and a failed
or cancelled matrix could produce installation media while the image family was only
partially refreshed.

**Decision.** Add a `workflow_run` trigger for completed `bluebuild` workflows on `main`.
Before creating a matrix, require the upstream conclusion to be `success`, reject
pull-request events, and require its head branch to equal the repository default branch.
An accepted automatic event builds Standard, CachyOS, and NVIDIA ISOs from `latest` with
`fail-fast: false`.

Retain DD-054's `workflow_dispatch` route for one active image and an explicit tag. Keep
signature verification, digest pinning, Fedora-version discovery, checksums, seven-day
retention, and the no-Release policy unchanged.

**Consequences.**

- Every successful default-branch image publication automatically produces three matching
  ISO artifacts; the weekly scheduled build therefore produces a weekly set even without
  repository changes.
- Successful default-branch pushes and manual `bluebuild` runs also produce a set. A newer
  automatic event cancels an older automatic ISO run still in progress.
- Pull-request, non-default-branch, failed, and cancelled image runs may create a skipped
  ISO workflow record, but consume no ISO build jobs or artifact storage.
- The whole upstream image matrix must succeed before automatic ISO generation starts. A
  partially successful image run produces no automatic media, even for the healthy images.
- Once ISO generation starts, one Lorax failure does not cancel the other variants.
- Actions storage now holds up to three new multi-gigabyte artifacts per successful
  default-branch image run for seven days. This cost is intentional and should be reviewed
  before increasing retention.
- Manual single-variant/tag generation remains the retry and historical-media path.

---

## DD-057 — Deliver the GRUB theme through `custom.cfg`, without regenerating the menu

**Status:** Accepted

**Implements:** `BRD-006`

**Extends:** [DD-004](#dd-004--rebrand-by-overwriting-upstream-asset-paths) and
[DD-022](#dd-022--theme-the-niri-session-from-56728b-not-from-the-logo-green)

**Context.** The approved Qubix Boot Console design is a mostly TUI interface: a quiet
near-black grid, cropped wireframe cube, square terminal frame, Qubix Slate selection row,
IBM Plex Mono text, keyboard help, and a live timeout. GRUB supports those pieces through
its [theme format](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html),
but an Atomic image cannot deliver them like normal desktop branding.

GRUB reads before the root deployment is mounted and expects readable assets on `/boot`.
That filesystem is machine-local and mutable; `/usr` belongs to the image. Putting theme
files only under `files/system/boot/` would pretend `/boot` participates in an OSTree
deployment when it does not. Pointing GRUB into `/usr` would also fail on common layouts
where `/boot` is separate and the root is encrypted.

Regenerating the menu at runtime is the wrong bridge. It rewrites boot-critical state,
duplicates work already owned by OSTree/bootupd, and can fail against an active composefs
deployment. More importantly, it is unnecessary. bootupd's static GRUB configuration
[sources `$prefix/custom.cfg`](https://github.com/coreos/bootupd/blob/main/src/grub2/configs.d/41_custom.cfg),
and Fedora's generated configuration has the same supported path in
[`41_custom.in`](https://github.com/rhboot/grub2/blob/fedora-44/util/grub.d/41_custom.in).

**Decision.** Keep canonical artwork, layout, solid UI primitives, and an installer under
`/usr/share/qubix-os/grub-theme/` and `/usr/bin/`. Enable a system oneshot which runs after
local filesystems mount and performs three bounded operations:

1. Validate the build-generated SHA-256 manifest, derive a content-addressed revision, and
   stage the complete theme before renaming it into `/boot/grub2/themes/qubix-v1-<digest>`.
2. Preserve existing `/boot/grub2/custom.cfg` lines outside one exact pair of Qubix marker
   lines, then atomically replace that file with the current managed block. Refuse symlinks
   and malformed marker pairs rather than guessing ownership.
3. Have the managed block load the three PF2 fonts and `gfxmenu`, request
   `1920x1080,auto`, override bootupd's one-second default with a visible eight-second
   menu, and set `theme` to the content-addressed `theme.txt`. Never call `grub2-mkconfig`
   and never emit a `menuentry`.

Generate the PF2 fonts during the image build from Fedora's already-selected IBM Plex Mono
package using `grub2-mkfont`; GRUB cannot read OTF. Install `grub2-tools-extra` explicitly
because that package owns the converter. The theme's `boot_menu` renders whatever BLS,
OSTree, firmware, or OS discovery supplies, so the representative labels in the approved
mockup are not baked into the image. The mockup's `UEFI · x86_64` label is omitted because
a static theme cannot truthfully query that state.

The service is an enforced image default. Masking it and running
`qubix-grub-theme --remove` is the documented opt-out; unmasking and `--install` reapplies
it. Removing the block leaves copied assets inert, which is safer and recoverable.

**Consequences.**

- Bootupd-static and Fedora-generated GRUB installations use one integration path, without
  replacing their configuration or changing their menu-entry lifecycle.
- The menu is intentionally visible for eight seconds. A shorter inherited timeout made
  the background flash and disappear before the list was usable; after the countdown or an
  explicit boot, any blank interval belongs to the kernel/Plymouth handoff, not the theme.
- A missing/read-only `/boot`, corrupt image manifest, symlinked `custom.cfg`, or malformed
  Qubix block fails the service and leaves GRUB's existing text/graphical menu in place.
- The first boot into an image that introduces the theme cannot display it: that boot occurs
  before the service has copied the assets. The following boot can. Later theme revisions
  are installed alongside older content-addressed directories, avoiding in-place assets
  while firmware may be reading them at the cost of a small amount of retained `/boot`
  space.
- `custom.cfg` remains a shared user extension point. Unrelated content survives, but the
  Qubix-marked block is image-owned and is restored on each boot unless the service is
  masked.
- The theme requests 1920×1080 first and uses percentage placement; `auto` is the firmware
  fallback. Serial and non-graphical paths remain GRUB fallbacks, not Qubix surfaces.
- Local checks can validate PNGs, shell syntax, markers, fonts, manifest integrity, and
  required theme components. Only a built image on real firmware can confirm rendering and
  every boot target; `BRD-006` waits in **Awaiting confirmation** for that check.
