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
