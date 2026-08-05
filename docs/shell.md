# The Terminal Environment

What you get in a terminal on Qubix OS, how it is delivered, and how to change or remove
any of it.

The terminal itself — WezTerm, how it is made the default in both sessions, and the fonts
and colours it is configured with — is in
[`desktops.md`](desktops.md#the-default-terminal). This page is about what runs *inside*
it.

## What is in it

| Tool | What it does | Shells |
|---|---|---|
| [starship](https://starship.rs) | The prompt. Four rows: context, system, toolchain, prompt character | bash, zsh |
| [atuin](https://atuin.sh) | Shell history in a local SQLite database, searchable from every terminal. **Fully local** | zsh |
| zsh-autosuggestions | The greyed-out suggestion from history, accepted with `→` | zsh |
| zsh-syntax-highlighting | Commands coloured as you type; red means it will not run | zsh |
| zsh-completions | Completion functions for tools zsh does not cover itself | zsh |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting. Aliased over `cat` | bash, zsh |
| [yazi](https://yazi-rs.github.io) | Terminal file browser, run as `y` | bash, zsh |
| [lazygit](https://github.com/jesseduffield/lazygit) | Git in a terminal UI, run as `lazygit` or `lg` | bash, zsh |
| [zellij](https://zellij.dev) | Terminal multiplexer: panes, tabs, sessions you can detach from | bash, zsh |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | System information, in a box, when you ask for it | bash, zsh |
| [Neovim](https://neovim.io) + [LazyVim](https://lazyvim.org) | The editor, and `$EDITOR` | — |

**zsh is the login shell**, and the image sets it for you — see
[The login shell](#the-login-shell). Bash is fully configured either way: it gets the
prompt, the aliases and `y`; the four zsh-only entries above are what it misses.

**A distrobox container gets this too**, without being asked — see
[Inside a distrobox container](#inside-a-distrobox-container).

## How it is delivered

**Nothing is written into your home directory.** Every part of this ships as a file in the
image, read by something that already exists, so a rebase changes the shell environment
with nothing to re-run and nothing stale left behind (DD-030).

| File | Read by | Holds |
|---|---|---|
| `/etc/profile.d/qubix-shell-env.sh` | sh, bash and zsh | `XDG_CONFIG_DIRS`, `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, `LG_CONFIG_FILE` — and, at the end, bash's interactive setup |
| `/etc/zshrc`, last block | zsh, when it is interactive | One `source` of the file below, appended to Fedora's file at build time |
| `/usr/share/qubix-os/shell/` | the two above | The prompt, the plugin loading, the aliases |
| `/usr/share/qubix-os/lazygit/config.yml` | lazygit, via `LG_CONFIG_FILE` | Nerd Font icons and the project palette (DD-032) |
| `/etc/zellij/config.kdl` | zellij, when you start it | The multiplexer's theme (DD-033) |
| `/etc/fastfetch/config.jsonc` | fastfetch, when you run it | The system-information box (DD-031) |

### Making any of it your own: `qubix-config`

Every file above lives in `/usr` or `/etc`, and a file of your own shadows it. Getting that
first copy used to mean knowing which of six paths held it — so there is a command:

```bash
qubix-config --list          # what can be copied, and what you already have
qubix-config starship        # copy one
qubix-config --all           # copy all of them
qubix-config --diff          # what the image has changed since you copied
```

**Nothing runs it for you.** No login hook, no first-boot seeding. An account that never
runs it has nothing in `~/.config` and keeps receiving every change a rebase makes, which is
the default this image is built around (DD-030). The command exists so that *choosing* to
customise is one line instead of six scattered `cp`s.

It never overwrites without `--force`, `--force` keeps your previous file as a `.bak`, and it
refuses to run under `sudo` — root-owned files in your home directory help nobody.

It also knows three things a `cp` does not (DD-039):

| Name | What it does differently |
|---|---|
| `niri` | Rewrites the palette `include` to an absolute path. **A verbatim copy does not load** — niri resolves a relative include against the file's own directory |
| `wezterm` | Copies `wezterm.lua` only. The colour schemes stay in `/etc/xdg/wezterm/colors/`, where they are still found *and* still track the image |
| `lazygit` | Warns that its config **merges key by key**, so a file with only your changed keys is usually better than a whole copy |

> **A copy is a fork.** From the moment a file lands in `~/.config`, the image's version of
> it stops reaching you — new keybinds, new colours, fixes. `qubix-config --diff` shows what
> you are missing; it is worth running after a rebase.

Two things are deliberately not in the list. **atuin** ships no file at all — it is
configured from the environment, so `~/.config/atuin/config.toml` is yours to create from
scratch and switches the image's settings off. **The zsh half** is *sourced* rather than
shadowed; customising it is the `source` line below, not a copy.

### Every shell, not just the first one

A shell started **from another shell** — `zsh` typed into bash, `bash` typed into zsh, or
either one nested in itself — gets exactly the same setup as a shell started by a terminal.
That is worth stating because it was not true until 2026-08-03: every guard in these files
tested a variable the tools **export**, and an exported variable is inherited, so each guard
read "has anybody up my process tree done this?" instead of "has this shell done this?".
Nested shells got no prompt and no atuin (DD-037).

The rule now is that a guard may only test something a child cannot inherit — a shell
function, or the image's own literal path in a variable it is about to rewrite. The
practical effect beyond nested shells: **a config file you create wins in your next shell,
not after your next login.** The graphical session reads
`/etc/profile.d/qubix-shell-env.sh` too, so anything decided once and exported would
otherwise have been fixed for the life of that session.

### Why zsh is wired from the end of `/etc/zshrc`

`/etc/profile.d/*.sh` is where system-wide shell setup normally goes, and it **cannot**
hold the zsh half: Fedora's `/etc/zshrc` sources those files from inside a function that
has run `emulate -L ksh`, so `KSH_ARRAYS` and `SH_WORD_SPLIT` are in force — not the
language zsh plugin scripts are written in. So it holds the environment variables, and
bash's setup, and nothing else.

That leaves zsh's own startup files, and the order they run in is the whole argument:

| # | File | What is there |
|---|---|---|
| 1 | `/etc/zshenv` | Fedora's, comments only. Read by **every** zsh, scripts included |
| 2 | `/etc/zprofile` → `/etc/profile` → `/etc/profile.d/*.sh` | the image's environment: `STARSHIP_CONFIG`, `ATUIN_*`, `LG_CONFIG_FILE`, `EDITOR` |
| 3 | `/etc/zshrc` | Fedora's default prompt, the `profile.d` loop for non-login shells — **and the image's block, appended at the end** |
| 4 | `~/.zshrc` | yours, and it still wins |

Row 3 is where the setup has to be, because row 2 is where its environment comes from.
Until 2026-08-03 this was wired from row 1, which meant starship and atuin were initialised
*before* the variables that configure them were exported — it worked only because both
re-read their environment at every prompt (DD-036).

`/etc/zshrc` is not replaced. The block is appended to Fedora's file at build time, so
upstream's content — including that `profile.d` loop — stays exactly as Fedora ships it.
The build fails if the base image ever ships an `/etc/zshrc` that is not Fedora's, and
again if the result does not parse.

It has one known cost. It runs *before* `~/.zshrc`, and zsh-syntax-highlighting only wraps
the ZLE widgets that exist when it is sourced — so widgets you define in your own
`~/.zshrc` are not highlighted. If you define any, re-source the file at the end of your
`~/.zshrc`:

```zsh
source /usr/share/qubix-os/shell/qubix.zsh
```

The same ordering is why `compinit` runs twice if your `~/.zshrc` came from Fedora's
skeleton — once here, once there. It costs a few milliseconds; deleting the skeleton's two
`compinit` lines is safe.

## The login shell

zsh is the login shell, and **you do not have to do anything to get it.**

**Accounts created from now on** get `/usr/bin/zsh`, from `SHELL=` in
`/etc/default/useradd`.

**An account that already exists** has its shell in `/etc/passwd`, which is per machine —
no image can write it, so `qubix-default-shell.service` does it on the machine instead. It
runs at boot, before logins are permitted, and moves human accounts that are still on bash
to zsh. Your first login after a rebase is already in zsh.

It gets **one attempt per account, ever**:

- Every account it looks at is stamped in `/var/lib/qubix-os/default-shell/`, whether or not
  it changed anything.
- It only ever replaces **bash**, which is what an account inherited. An account on fish, or
  nushell, or anything else, is stamped and left alone.
- `root` is never touched, so a broken zsh cannot cost you your recovery shell.

### Going back, or opting out

```bash
sudo usermod -s /bin/bash $USER      # back to bash. Permanent — you are already stamped
sudo usermod -s /usr/bin/zsh $USER   # and forward again, if you change your mind
```

To decline before the first boot on a rebased image:

```bash
sudo touch /var/lib/qubix-os/default-shell/$USER
```

**Not `chsh`.** Aurora deletes `/usr/bin/chsh` from the image — deliberately, as a footgun —
so every instruction that used to say `chsh` here was impossible to follow. That is the bug
this service exists to fix (DD-035). `usermod` is shadow-utils and is always present; it
does the same thing, and as root it does not prompt for a password. If you want `chsh`
back, `rpm-ostree install util-linux-user` layers it, and `/usr/bin/zsh` is already listed
in `/etc/shells` for it.

## Inside a distrobox container

**A container gets the same shell**, and you do not have to do anything to get it either.
Create one and it comes up with the prompt, the history search and both plugins:

```bash
distrobox create --name dev
distrobox enter dev
```

That is not free the way it looks. A container is a *different distribution* — its own
`/etc`, its own `/usr`, its own package manager — and every tool on this page is a host
package read from a host path, so a container's shell used to come up bare. What makes it
work is one hook: `/etc/distrobox/distrobox.conf` names
`/usr/bin/qubix-distrobox-shell`, and distrobox runs it inside the container, as root, when
the container is created (DD-043).

The rule it follows is **install it, or borrow it from the host, in that order**:

| | Where it comes from | Why |
|---|---|---|
| zsh, the two plugin packages, starship, atuin, bat | The container's **own** repositories, first choice | A package built for that distribution always fits it better |
| Whatever those repositories do not have | The **host**, through `/run/host` | Plain text always works; a host *binary* is linked only after `--version` proves the container can run it (DD-045) |
| `shell/qubix.zsh`, `shell/common.sh`, `starship.toml`, the lazygit config | The **host**, always | They are plain text, and distrobox mounts the host's root filesystem inside every container |
| Completion functions | The **container**, always | The host's cannot be trusted through `/run/host` — see [What it cannot do](#what-it-cannot-do) |

The link is one symlink — `/usr/share/qubix-os` → `/run/host/usr/share/qubix-os` — which is
what makes every absolute path in the host's files resolve inside the container. **So a
rebase changes your containers' shells too**, with nothing to re-run in them. Copies would
have gone stale the first time the image changed.

### A container you already have

The hook runs at creation, so containers made before this shipped never saw it. One command
catches one up, and it is safe to run again on any container:

```bash
distrobox enter <name> -- sudo /run/host/usr/bin/qubix-distrobox-shell
```

**This is also how a container receives a change to the shell wiring itself.** A container
is not rebuilt by a rebase, so the block the hook writes into its global `zshrc` would
otherwise stay as it was on the day the container was created. The block is delimited by

```
# ── Qubix OS ──────────────────────────────────────────────────────────────────
...
# ── end of the Qubix OS block ─────────────────────────────────────────────────
```

and a re-run **replaces everything between those two lines** with the current image's
version. Running it twice in a row changes nothing the second time. Edit inside the block
and your edit is what the next run overwrites — put anything of your own in `~/.zshrc`,
which runs afterwards and wins (DD-046).

One migration happens once, on a container created before the end marker existed: that block
has no end, so it is replaced *to the end of the file*, and anything you appended below it in
the container's `zshrc` goes with it. The hook says so in yellow and leaves the file as it was
next to it, as `<zshrc>.qubix-old`.

It is also the fix if a container is *in bash* — distrobox gives the container user the
shell your account had when the container was created, so anything made before
`qubix-default-shell.service` moved you to zsh has a bash user inside. Re-running it moves
that user to zsh, follows your host account, and — like the host service — only ever
replaces bash.

### What it cannot do

**A container with a different libc gets the text half only.** Alpine and Wolfi are musl;
the host's starship and atuin are glibc binaries and will not run there at all, so they are
left out and the reason is printed. Everything that is plain text still arrives — both
plugins, the aliases, the configuration. Debian and Ubuntu package neither tool either, but
their libc is glibc, so the host's binaries are borrowed and the prompt works.

**Completions are the container's own.** The host's are *not* put on `$fpath`, and cannot
usefully be: `compaudit` cannot establish ownership through the `/run/host` bind mount — the
host's root is an unmapped uid inside a rootless container — so it calls that directory
insecure, and every `compinit` that is not given `-u` stops to ask

```
zsh compinit: insecure directories and files, run compaudit for list.
Ignore insecure directories and files and continue [y] or abort compinit [n]?
```

at the top of every shell. `-u` on the image's own `compinit` did not settle that, because a
later one asks again — Fedora's skeleton `~/.zshrc` calls `compinit` plainly, and `~/.zshrc`
runs after `/etc/zshrc` — and answering `y` makes `compinit` drop the insecure directory from
`$fpath` before it dumps, so those completions were being discarded anyway. What a container
loses by this is `zsh-completions`, which Fedora does not package and the host installs from
upstream; what it keeps is a shell that never asks a question (DD-046).

**The history is one database, not two.** `$HOME` is shared, so the container's atuin reads
and writes the same `~/.local/share/atuin/history.db` as the host's — which is usually what
you want, and is worth knowing if a container's distribution ships a *newer* atuin than the
host: the first run migrates the shared database, and the host's older atuin then has to
live with it. A Fedora container tracks the same atuin the host does.

**Container creation now needs the network** and takes a package transaction longer.

**Where to look when something is missing.** The hook reports itself through the two line
prefixes `distrobox create` and `distrobox enter` actually display — a `distrobox:` step
while it works, and a yellow `Warning:` for anything it could not do. Everything the package
manager said goes to `/var/tmp/qubix-distrobox-shell.log` **inside the container**, and the
last few lines of it are printed when a tool is missing. Nothing it runs is allowed to write
a line starting with `Error:`: distrobox's log watcher treats one as fatal and abandons the
enter, which is exactly how a container that simply did not carry `starship` used to leave
you with no shell at all (DD-045).

### Turning it off

| For | Do |
|---|---|
| One container | `distrobox create --init-hooks '' --name <name>` — flags beat the config file |
| Every container | Comment the `container_init_hook` line in `/etc/distrobox/distrobox.conf`. `/etc` is writable and your edit survives a rebase |

One thing to know rather than to do: a `distrobox assemble` manifest with its own
`init_hooks=` key **replaces** this hook instead of adding to it, so a container built from
one comes up bare. `ublue-os-just`'s `/etc/distrobox/apps.ini` has such an entry.

## The tools

### starship — the prompt

The shipped prompt is at `/usr/share/qubix-os/starship.toml`. It is **never copied into
your home directory**: `/etc/profile.d/qubix-shell-env.sh` points `STARSHIP_CONFIG` at it
only when you have no `~/.config/starship.toml` of your own.

That means starship's own documented behaviour is intact — create
`~/.config/starship.toml` and it wins in your **next shell**, with nothing here to undo —
while the image's prompt keeps tracking rebases for everyone who has not. Exporting a
`STARSHIP_CONFIG` of your own also wins, and is left alone; only the image's own path is
ever rewritten (DD-037).

To start from the shipped one rather than a blank file:

```bash
qubix-config starship
```

The prompt uses Nerd Font glyphs throughout. WezTerm bundles a symbols fallback — and its
shipped font stack leads with a Nerd Font anyway ([`desktops.md`](desktops.md#the-default-terminal))
— while `cascadia-mono-nf-fonts` is installed so fontconfig can resolve the glyphs
everywhere else. A terminal explicitly configured with a font that has neither will show
boxes.

### atuin — history, fully local

atuin replaces `Ctrl-R` and `↑` with a searchable history stored in SQLite under
`~/.local/share/atuin`, shared across every terminal and every session.

**Nothing leaves the machine.** atuin is local until an account is registered, and this
image registers none. `/etc/profile.d/qubix-shell-env.sh` says so explicitly rather than
relying on a default, and does it without any per-user file: atuin reads every setting from
the environment, so `ATUIN_AUTO_SYNC=false` *is* `auto_sync = false`.

Also set there: `ATUIN_UPDATE_CHECK=false`, and `fuzzy` / `global` / `compact` for search
mode, filter mode and style.

**Your own config still wins.** atuin applies the environment *after* the config file, so
those variables are set only when `~/.config/atuin/config.toml` does not exist — create it
and the whole block switches off in your next shell, exactly like starship. Switching off
means those five variables are **unset**, not merely left alone, because leaving them set
is the override the guard exists to prevent (DD-037). To pull your existing shell history
into the database, once:

```bash
atuin import auto
```

**atuin is not wired into bash.** `atuin init bash` needs `bash-preexec`, which Fedora
does not package, and vendoring a second history-hooking layer into the image for the
non-default shell is not a trade worth making. atuin still works as a command in bash
(`atuin search`, `atuin stats`); it just does not take over `Ctrl-R`, which stays bash's
own reverse search.

### The zsh plugins

Loaded from `/usr/share/qubix-os/shell/qubix.zsh`, in this order, which is not arbitrary:

```
common aliases → compinit → atuin → starship → autosuggestions → syntax-highlighting
```

zsh-syntax-highlighting wraps the ZLE widgets that exist when it is sourced, so it goes
last — after atuin and starship have defined theirs. Because all of this runs before
`~/.zshrc`, **widgets you define there are not highlighted**; see
[Why zsh is wired from the end of `/etc/zshrc`](#why-zsh-is-wired-from-the-end-of-etczshrc)
for the one-line fix.

**`#` starts a comment**, which zsh does not do on an interactive command line unless it is
told to (`INTERACTIVE_COMMENTS`, off by default — bash, sh and every zsh *script* all
comment with `#`, so the omission only bites when you paste something). The image sets it,
so a command copied out of these pages with a trailing `# note` runs as written. `unsetopt
interactive_comments` in your `~/.zshrc` puts it back.

`zsh-completions` is not a Fedora package and the `@zsh-users` COPR has no builds for any
current Fedora, so it is installed at build time from a pinned upstream tag into
`/usr/share/zsh/site-functions` — already on zsh's default `$fpath`. Its functions
*shadow* zsh's own where both ship one for the same tool; that is what using
zsh-completions means. This is the one part of the environment a distrobox container does
**not** get from the host — see [What it cannot do](#what-it-cannot-do).

### bat, as `cat`

```
alias cat='bat --style=plain --paging=never'
```

`--style=plain --paging=never` is what keeps it a drop-in: no line numbers, no file
header, no pager. bat already writes plain bytes when its output is not a terminal, so
`cat file | grep x` behaves exactly as before.

- `command cat` — the real `cat`, for `cat -n` and anything else bat does not accept.
- `bat` — bat with all its decorations, unchanged.

### yazi, as `y`

`yazi` works as itself. `y` is upstream's wrapper: it does the same thing, and quitting
with `q` leaves the shell in the directory the browser was last in.

### lazygit, as `lg`

`lazygit` is a terminal UI over git: stage hunks, rewrite history, resolve conflicts,
without leaving the terminal. It is also what LazyVim's `<leader>gg` opens, and it is the
same binary either way.

`lg` is upstream's wrapper. It runs lazygit and, if you switched repositories inside it and
quit with `q`, leaves your shell in the repository you ended up in. Quitting with `Q` leaves
the shell where it was — that is upstream's opt-out, not an extra.

**The config is layered, not replaced.** lazygit reads one config path of its own and has no
system-wide location, so `LG_CONFIG_FILE` names two files: the image's, then yours.

```
LG_CONFIG_FILE=/usr/share/qubix-os/lazygit/config.yml,$HOME/.config/lazygit/config.yml
```

Later files override earlier ones **key by key**, which makes this the one place in the
terminal environment where your own file does not have to repeat everything. To change one
colour, change one colour:

```bash
mkdir -p ~/.config/lazygit
printf 'gui:\n  theme:\n    activeBorderColor: ["#C67B39", bold]\n' > ~/.config/lazygit/config.yml
```

`qubix-config lazygit` copies the whole thing if you would rather start from it, and says
why that is usually not the better choice.

Your half of the pair is added **only when the file exists** — lazygit treats a missing path
in `LG_CONFIG_FILE` as an error rather than skipping it — so the file takes effect in the
next shell you open, not the one you created it from.

What the image sets, and nothing else: `gui.nerdFontsVersion: "3"`, which turns on the file
and branch icons lazygit hides by default when it cannot assume a font, and the `#56728B`
palette (DD-022). Everything else is lazygit's default.

### zellij — panes, tabs, and sessions

`zellij` is a terminal multiplexer: split panes, tabs, and sessions that keep running when
you detach or when the terminal window closes.

```bash
zellij                 # start, or pick from existing sessions
zellij attach          # back into the last session
zellij list-sessions
```

**Nothing starts it for you.** There is no shell hook and no autostart script — zellij ships
one and this image deliberately does not install it, for the same reason nothing runs
fastfetch at login. `Ctrl-o d` detaches; `Ctrl-q` quits.

The keybindings are zellij's own defaults, shown along the bottom of the screen.
`zellij setup --dump-config` prints every option with its documentation.

The shipped configuration is `/etc/zellij/config.kdl`, and it holds one thing: the Qubix
theme, from the same `#56728B` palette as the Niri session (DD-022, DD-033) — every element
named explicitly, with each text pair's contrast ratio written next to it. zellij takes the
**first config directory that exists**, in this order:

```
~/.config/zellij → $XDG_CONFIG_HOME/zellij → /etc/zellij
```

so yours replaces this one **wholesale** rather than merging with it — unlike lazygit above.
Nothing creates `~/.config/zellij` for you, so start from the image's copy:

```bash
qubix-config zellij
```

**Edit the copy, not the original**, for the same reason as fastfetch: `/etc` is three-way
merged on update, so a file edited there stops receiving image changes.

**Copying uses OSC 52**, zellij's default, which the terminal itself executes — WezTerm
supports it, and it still works when zellij is running at the far end of an SSH connection.
A terminal without OSC 52 needs `copy_command "wl-copy"` in your copy of the config, plus
`wl-clipboard`, which this image does not install.

#### Where zellij comes from, and what that costs

zellij is **not** an RPM. Fedora does not package it, and — unlike yazi — upstream endorses
no COPR, so the image installs upstream's own `no-web` musl release: version pinned, SHA-256
of the binary asserted at build time (DD-033).

| Consequence | What it means for you |
|---|---|
| `rpm -q zellij` finds nothing | Check the version with `zellij --version` |
| The web server is not merely off, it is **absent** | `zellij web` and browser session sharing do not exist in this build |
| The version is pinned | New zellij releases arrive when this repository bumps two lines, not with the daily rebuild |

### fastfetch — system information

`fastfetch` prints the machine in a rounded box: system, hardware, network, toolchain,
session, and a colour ramp. **Nothing runs it for you** — not at login, not from your shell
startup. It costs nothing until you type it.

The shipped configuration is `/etc/fastfetch/config.jsonc`, which is where the *system-wide*
default lives, because fastfetch has no `/usr` config path — its search order is
`~/.config` → `$HOME` → `$XDG_CONFIG_DIRS` → `/etc/xdg` → `/etc`, and `/usr/share/fastfetch`
holds presets and logos rather than defaults (DD-031). Your own file is the first entry in
that list, so it replaces this one wholesale:

```bash
qubix-config fastfetch
```

**`fastfetch` has to mean fastfetch, and on this base image it did not.** Aurora ships
`/etc/profile.d/ublue-fastfetch.sh`, which aliases `fastfetch` to `ublue-fastfetch` — a
wrapper that passes Universal Blue's own config explicitly. An alias is resolved before
`$PATH` and an explicit `--config` before any config directory, so that alias beat this
page's entire search order, including your own `~/.config` file.
`/etc/profile.d/zz-qubix-fastfetch.sh` removes that one alias, and the build asserts the
result (DD-040). Universal Blue's box is still one command away:

```bash
ublue-fastfetch      # also still `neofetch` and `neowofetch`
```

**Edit the copy, not the original.** `/etc` is three-way merged on update, so a file you
have edited there stops receiving image changes — and an edited `/etc/fastfetch/config.jsonc`
is also the one way to end up with a box that a later rebase has stopped improving.

If the box does not look like the one described here, ask fastfetch which file it used
rather than guessing:

```bash
fastfetch --list-config-paths   # /etc/fastfetch/ is the last entry; (*) marks what exists
ls -l /etc/fastfetch/config.jsonc
```

Nothing in the shell environment affects this: fastfetch finds `/etc/fastfetch/` on its own,
with no variable set and no wiring. If the file is not there, the running deployment predates
it — `rpm-ostree status` shows which image is booted.

#### It needs a 112-column terminal

The box is drawn with absolute cursor columns rather than by counting characters, because
Nerd Font glyphs are not all one cell wide. Four columns are pinned — left spine 45, labels
51, separator 61, right spine 112 — and all four are derived from the width of the logo,
Fedora's full mark, which takes columns 1 to 44. Below 112 columns, rows overrun the right
edge.

That is wider than Niri's default half column gives a WezTerm — around 100 columns on a
1920px panel — so the box wants `Mod+R` (two-thirds) or `Mod+F` (maximised). If you would
rather have a box that fits the half column, `fedora_small` is the same mark at 16 columns
and puts the right spine back at 90; it is a one-line change plus `retune.sh`, below.

The logo is **pinned**, not detected, even though detection would choose the same mark
today. fastfetch tries `ID`, then `NAME`, then each word of `ID_LIKE`, then the kernel name;
this image rewrites `ID` and `NAME`, and the base image's `ID_LIKE=fedora` is what matches.
Pinning it means a fastfetch that one day ships a `qubix` logo, or a base image without
`ID_LIKE`, cannot move all four columns without telling you (DD-041).

To use a different logo, change `"source"` in your copy and then re-derive the four columns:

```bash
/usr/share/qubix-os/fastfetch/retune.sh          # tunes ~/.config/fastfetch/config.jsonc
/usr/share/qubix-os/fastfetch/retune.sh -n       # show what it would change
```

It measures the gutter fastfetch actually emits for your logo, rewrites the columns, and
updates the comment block that documents them. `fastfetch --list-logos` shows the choices.

It reads that gutter two ways, because fastfetch 2.64.0 changed how it draws one: up to
2.63 the logo was a block followed by a cursor step (`ESC[<n>C`), and from 2.64 the logo and
the modules share a line, so the gutter is that many literal spaces (DD-042). If it ever
prints `could not measure the logo gutter`, the message names the command it ran and what it
looked for — and the columns are `gutter + 1` (spine), `+ 7` (labels), `+ 17` (separator),
`+ 68` (right spine) if you would rather set them by hand.

#### The one row that leaves the machine

The `wan` row uses fastfetch's `publicip` module, which asks `ipinfo.io/json` for the
address you appear as — **every time fastfetch runs**. Nothing else in the box touches the
network. If you would rather it stayed entirely local, delete the `publicip` block from your
copy of the config; the box closes up with no other change.

### Neovim and LazyVim

`nvim` is `$EDITOR` and `$VISUAL`, and the tools LazyVim's default keymaps shell out to are
installed with it: `ripgrep` and `fd-find` behind the pickers, `fzf`, `lazygit` on
`<leader>gg`, and `git`.

**The configuration is not shipped.** `~/.config/nvim` is yours from the moment you create
it, and creating it is LazyVim's own one-line install:

```bash
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git   # only if you would rather not track upstream — see below
```

An earlier version of this image seeded that clone for you, from a systemd user service
with a vendored offline fallback. It was a lot of machinery to save one command, and it is
gone (DD-030).

Run `nvim` afterwards and LazyVim bootstraps itself: it clones `lazy.nvim` and installs the
plugin set, so the first launch needs network. Subsequent launches are offline.

#### Keeping it updated

Two halves, two mechanisms — which is why the config is worth keeping as a git clone.

| What | Where it lives | How to update it |
|---|---|---|
| LazyVim and every plugin | `~/.local/share/nvim/lazy/` | `:Lazy update` — also rewrites `lazy-lock.json` |
| LazyVim's optional modules | same | `:LazyExtras` |
| Mason's tools (LSP servers, formatters) | `~/.local/share/nvim/mason/` | `:Mason` |
| **The starter config** | `~/.config/nvim` | `git -C ~/.config/nvim pull` |

Keep the `.git` directory from that clone and `origin` points at upstream's starter: your
own edits become commits on top, and a pull merges them the way any repository does.
Upstream changes it rarely, and almost always in `lua/config/lazy.lua` — the bootstrap.

**After a rebase that brings a new Neovim**, run `:Lazy update`. The plugin versions pinned
in `lazy-lock.json` were resolved against the old one, and nothing updates them
automatically.

`micro` is still installed for anyone who wants it; `$EDITOR` is set only when it is not
already set, so an export in your own rc file wins.

## Changing or removing any of it

Everything here is a default, and every default is overridden by a file in your home
directory — which the image never writes to.

| To | Do |
|---|---|
| Use your own prompt | Create `~/.config/starship.toml` |
| Configure atuin yourself | Create `~/.config/atuin/config.toml` — the `ATUIN_*` variables step aside |
| Change anything zsh does | Put it in `~/.zshrc`, which runs after all of this |
| Change anything bash does | Put it in `~/.bashrc` |
| Keep `cat` as `cat` | `unalias cat` in your rc file |
| Change one thing about lazygit | Put just that key in `~/.config/lazygit/config.yml` — it merges over the image's |
| Take lazygit's defaults back | `export LG_CONFIG_FILE=$HOME/.config/lazygit/config.yml` in your rc file |
| Change the zellij theme or keys | `cp /etc/zellij/config.kdl ~/.config/zellij/config.kdl` and edit that |
| Change the fastfetch box | `cp /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc` and edit that |
| Keep fastfetch offline | Delete the `publicip` block from your copy of the config |
| Use a different editor | `export EDITOR=…` in your rc file |
| Switch to zsh, or back | `sudo usermod -s /usr/bin/zsh $USER` / `sudo usermod -s /bin/bash $USER` — not `chsh`, which this image does not have |
| Update the Neovim config | `git -C ~/.config/nvim pull` |
| Get all of this in a distrobox you already have | `distrobox enter <name> -- sudo /run/host/usr/bin/qubix-distrobox-shell` |
| Leave containers as their own distribution built them | Comment `container_init_hook` in `/etc/distrobox/distrobox.conf`, or `distrobox create --init-hooks ''` for one |

## Files

| Path | Purpose |
|---|---|
| `/etc/profile.d/qubix-shell-env.sh` | `XDG_CONFIG_DIRS`, `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, `LG_CONFIG_FILE`, and bash's setup |
| `/etc/zshrc`, last block | Sources the zsh half. **Appended to** Fedora's file at build time, never replacing it (DD-036) |
| `/etc/default/useradd` | `SHELL=/usr/bin/zsh` for accounts created from now on |
| `/usr/bin/qubix-default-shell` | Moves existing accounts to zsh, once each (DD-035) |
| `/usr/lib/systemd/system/qubix-default-shell.service` | Runs it at boot, before logins are permitted |
| `/var/lib/qubix-os/default-shell/` | One stamp per account the service has looked at. Machine state, not config |
| `/usr/share/qubix-os/shell/common.sh` | The `cat` alias and the `y` function — shared by both shells |
| `/usr/share/qubix-os/shell/qubix.zsh` | Prompt, atuin, plugins, history defaults |
| `/usr/share/qubix-os/shell/qubix.bash` | Prompt and aliases |
| `/usr/share/qubix-os/starship.toml` | The prompt configuration |
| `/usr/share/qubix-os/lazygit/config.yml` | lazygit's icons and palette. Merged *under* your own config, not replaced by it (DD-032) |
| `/etc/zellij/config.kdl` | The zellij theme. The only system-wide path zellij reads (DD-033) |
| `/etc/fastfetch/config.jsonc` | The fastfetch box. The only system-wide path fastfetch reads (DD-031) |
| `/etc/profile.d/zz-qubix-fastfetch.sh` | Undoes Aurora's `fastfetch` alias, so the config above is reachable. Named to sort last (DD-040) |
| `/usr/bin/qubix-config` | Copies any of these into `~/.config` on request. Nothing runs it (DD-039) |
| `/etc/distrobox/distrobox.conf` | Names the hook below as `container_init_hook`, so every container distrobox creates runs it (DD-043) |
| `/usr/bin/qubix-distrobox-shell` | Runs **inside** a container: installs the binaries from its own repositories, links everything else from `/run/host`, and writes a delimited block into the container's global `zshrc` that a re-run replaces (DD-043, DD-046) |
| `/usr/share/qubix-os/fastfetch/retune.sh` | Re-derives the box's four columns after a logo change. Run by hand, never automatically |
| `/usr/share/zsh/site-functions/_*` | zsh-completions and zellij's completions, installed at build time |
| `/usr/share/bash-completion/completions/zellij` | zellij's bash completions, generated by the binary that ships |

Configuration files, one hand-run tool, one boot service that touches `/etc/passwd` once
per account, one script that runs inside containers, and nothing under `$HOME`.

Why each of these lives where it does: [`design-decisions.md`](design-decisions.md),
DD-026, DD-030, DD-031, DD-032, DD-033, DD-035, DD-036, DD-037, DD-038, DD-039, DD-040, DD-041, DD-042 and DD-043. What the recipe installs and in
which module:
[`recipe-reference.md`](recipe-reference.md).
