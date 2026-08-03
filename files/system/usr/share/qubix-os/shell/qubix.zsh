# Read by: zsh, sourced from the end of /etc/zshrc.
#
# Everything interactive that zsh gets. It lives here, in /usr, rather than in anyone's
# home directory: a rebase changes the shell environment with nothing to re-run and
# nothing stale left in $HOME (DD-030).
#
# WHY NOT /etc/profile.d, where the bash half lives: zsh sources /etc/profile.d/*.sh from
# inside a function that has run `emulate -L ksh`, so KSH_ARRAYS and SH_WORD_SPLIT are in
# force there — not the language zsh plugin scripts are written in.
#
# WHY THE END OF /etc/zshrc rather than /etc/zshenv, which is where this used to be
# sourced from: /etc/zshenv is the first file zsh reads, so everything the image exports
# in /etc/profile.d — STARSHIP_CONFIG, ATUIN_*, LG_CONFIG_FILE, EDITOR — was being set
# after the tools below had already been initialised. The end of /etc/zshrc is after that
# loop and after Fedora's default PROMPT line. The block that sources this file is
# appended at build time by recipes/common-base.yml, module 4f (DD-036).
#
# THIS STILL RUNS BEFORE ~/.zshrc. A user's own file therefore always wins, which is the
# right way round. The cost is at the bottom of this file: zsh-syntax-highlighting cannot
# wrap widgets that do not exist yet.
#
# See docs/shell.md and docs/design-decisions.md DD-026, DD-030, DD-036.

# Interactive shells only. Nothing below has any meaning in a script.
[[ -o interactive ]] || return 0

# ── Aliases and functions shared with bash ────────────────────────────────────
[[ -r /usr/share/qubix-os/shell/common.sh ]] &&
    source /usr/share/qubix-os/shell/common.sh

# ── History ───────────────────────────────────────────────────────────────────
# zsh keeps NO history at all unless these are set, and Fedora's skeleton ~/.zshrc does
# not set them. atuin has its own database, but the shell's own file still matters: it is
# what `atuin import auto` reads, and what is left if atuin is ever removed.
# `:=` assigns only when unset, and ~/.zshrc runs after this, so a user's own value wins.
: ${HISTFILE:=${ZDOTDIR:-$HOME}/.zsh_history}
: ${HISTSIZE:=10000}
: ${SAVEHIST:=10000}

# ── Completion ────────────────────────────────────────────────────────────────
# Everything below assumes completion exists, and this runs before ~/.zshrc, so it cannot
# rely on the skeleton's compinit call. compdef is defined by compinit and by nothing
# else, so it is the reliable "has this already run" test — it catches a user who runs
# compinit from their own ~/.zshenv.
#
# Fedora's skeleton ~/.zshrc calls compinit again afterwards. That is harmless, costs a
# few milliseconds, and deleting those two lines from ~/.zshrc is safe.
#
# Nothing has to be added to $fpath: zsh-completions is installed into
# /usr/share/zsh/site-functions, which is on the default $fpath already.
if ! (( $+functions[compdef] )); then
    autoload -Uz compinit && compinit
fi

# ── atuin — shell history in a local SQLite database ──────────────────────────
# Rebinds Ctrl-R and Up to a searchable history shared across every terminal.
# Fully local: no account, no sync, no update check — configured entirely from the
# environment in /etc/profile.d/qubix-shell-env.sh, so there is no per-user file to seed.
#
# GUARDED ON A FUNCTION, NOT ON ATUIN_SESSION. `atuin init zsh` runs
# `export ATUIN_SESSION=$(atuin uuid)`, and an EXPORTED variable is inherited by every
# child process — so testing it asked "has any ancestor of this shell initialised atuin",
# and a zsh started from another shell skipped atuin entirely. Functions are not
# inherited, which makes `_atuin_precmd` a true "has THIS shell been initialised" test.
#
# Nesting is atuin's own business and is left to it: its init re-issues ATUIN_SESSION
# whenever $SHLVL changes, which is the bookkeeping the guard above was destroying.
if (( $+commands[atuin] )) && (( ! $+functions[_atuin_precmd] )); then
    eval "$(atuin init zsh)"
fi

# ── starship — the prompt ─────────────────────────────────────────────────────
# Config resolution is in /etc/profile.d/qubix-shell-env.sh: the image's prompt unless
# ~/.config/starship.toml exists.
# Before the highlighter, so any widget starship defines is wrapped by it.
#
# GUARDED ON THE PRECMD HOOK, NOT ON STARSHIP_SHELL, for the reason above: `starship init`
# ends with `export STARSHIP_SHELL="zsh"`, so every child shell inherited it and went
# without a prompt. `${precmd_functions[(r)…]}` is the first element matching the pattern,
# and precmd_functions is a plain shell array — not inherited, and it names whichever
# function this starship registered (`prompt_starship_precmd` today).
if (( $+commands[starship] )) && [[ -z ${precmd_functions[(r)*starship*]} ]]; then
    eval "$(starship init zsh)"
fi

# ── zsh-autosuggestions — the greyed-out completion from history ──────────────
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# ── zsh-syntax-highlighting — MUST BE LAST ────────────────────────────────────
# It wraps the ZLE widgets that exist at the moment it is sourced. Nothing may be added
# below this line.
#
# The known limit of wiring zsh system-wide: widgets a user defines in their own
# ~/.zshrc come later still, and are not wrapped. Re-sourcing this file at the end of
# ~/.zshrc fixes that for anyone who cares — documented in docs/shell.md, and not
# something the image does on a user's behalf.
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Never let the status of the last conditional above become the status of the whole file.
return 0
