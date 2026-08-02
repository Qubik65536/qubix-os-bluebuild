# The Terminal Environment

What you get in a terminal on Qubix OS, how it is delivered, and how to change or remove
any of it.

The terminal itself — WezTerm, and how it is made the default in both sessions — is in
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
| [Neovim](https://neovim.io) + [LazyVim](https://lazyvim.org) | The editor, and `$EDITOR` | — |

**zsh is the intended login shell**, and on an account that already exists that takes one
command — see [The login shell](#the-login-shell). Bash is fully configured either way: it
gets the prompt, the aliases and `y`; the four zsh-only entries above are what it misses.

## How it is delivered

**Nothing is written into your home directory.** Every part of this ships as a file in the
image, read by something that already exists, so a rebase changes the shell environment
with nothing to re-run and nothing stale left behind (DD-030).

| File | Read by | Holds |
|---|---|---|
| `/etc/profile.d/qubix-shell-env.sh` | sh, bash and zsh | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings — and, at the end, bash's interactive setup |
| `/etc/zshenv` | zsh, on every invocation | One `source` of the file below |
| `/usr/share/qubix-os/shell/` | the two above | The prompt, the plugin loading, the aliases |

### Why zsh is wired from `/etc/zshenv`

`/etc/profile.d/*.sh` is where system-wide shell setup normally goes, and it **cannot**
hold the zsh half: Fedora's `/etc/zshrc` sources those files from inside a function that
has run `emulate -L ksh`, so `KSH_ARRAYS` and `SH_WORD_SPLIT` are in force — not the
language zsh plugin scripts are written in. So it holds the environment variables, and
bash's setup, and nothing else.

That leaves zsh's own startup files. `/etc/zshrc` carries real behaviour — including that
`profile.d` loop — so replacing it means owning Fedora's copy forever. **`/etc/zshenv` is
comments only**, so replacing it costs nothing, and it is plain zsh at top level.

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

zsh is the image's default shell, and there is exactly one thing the image cannot do for
you.

**Accounts created from now on** get `/usr/bin/zsh`, from `SHELL=` in
`/etc/default/useradd`.

**An account that already exists** has its shell in `/etc/passwd`, which is per machine —
no image can write it. One command, once:

```bash
chsh -s /usr/bin/zsh
```

Then log out and back in. Going back is the same command the other way:

```bash
chsh -s /bin/bash
```

Both are permanent: `/etc/passwd` lives in `/etc` and survives every update and rebase.
Nothing in the image re-imposes a shell at boot — an earlier version did, with a service
that ran `usermod`, and it was more machinery than a once-in-a-lifetime command deserves
(DD-030).

## The tools

### starship — the prompt

The shipped prompt is at `/usr/share/qubix-os/starship.toml`. It is **never copied into
your home directory**: `/etc/profile.d/qubix-shell-env.sh` points `STARSHIP_CONFIG` at it
only when you have no `~/.config/starship.toml` of your own.

That means starship's own documented behaviour is intact — create
`~/.config/starship.toml` and it wins, with nothing here to undo — while the image's
prompt keeps tracking rebases for everyone who has not.

To start from the shipped one rather than a blank file:

```bash
cp /usr/share/qubix-os/starship.toml ~/.config/starship.toml
```

The prompt uses Nerd Font glyphs throughout. WezTerm bundles a symbols fallback, and
`cascadia-mono-nf-fonts` is installed so fontconfig can resolve them everywhere else. A
terminal explicitly configured with a font that has neither will show boxes.

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
and the whole block switches off, exactly like starship. To pull your existing shell
history into the database, once:

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
[Why zsh is wired from `/etc/zshenv`](#why-zsh-is-wired-from-etczshenv) for the one-line
fix.

`zsh-completions` is not a Fedora package and the `@zsh-users` COPR has no builds for any
current Fedora, so it is installed at build time from a pinned upstream tag into
`/usr/share/zsh/site-functions` — already on zsh's default `$fpath`. Its functions
*shadow* zsh's own where both ship one for the same tool; that is what using
zsh-completions means.

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
| Use a different editor | `export EDITOR=…` in your rc file |
| Switch to zsh, or back | `chsh -s /usr/bin/zsh` / `chsh -s /bin/bash` |
| Update the Neovim config | `git -C ~/.config/nvim pull` |

## Files

| Path | Purpose |
|---|---|
| `/etc/profile.d/qubix-shell-env.sh` | `EDITOR`, `VISUAL`, `STARSHIP_CONFIG`, the `ATUIN_*` settings, and bash's setup |
| `/etc/zshenv` | Sources the zsh half. **Replaces** Fedora's, which is comments only |
| `/etc/default/useradd` | `SHELL=/usr/bin/zsh` for accounts created from now on |
| `/usr/share/qubix-os/shell/common.sh` | The `cat` alias and the `y` function — shared by both shells |
| `/usr/share/qubix-os/shell/qubix.zsh` | Prompt, atuin, plugins, history defaults |
| `/usr/share/qubix-os/shell/qubix.bash` | Prompt and aliases |
| `/usr/share/qubix-os/starship.toml` | The prompt configuration |
| `/usr/share/zsh/site-functions/_*` | zsh-completions, installed at build time |

Six files, no scripts, no services, and nothing under `$HOME`.

Why each of these lives where it does: [`design-decisions.md`](design-decisions.md),
DD-026 and DD-030. What the recipe installs and in which module:
[`recipe-reference.md`](recipe-reference.md).
