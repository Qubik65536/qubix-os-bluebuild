# Read by: every login shell (via /etc/profile), and every interactive bash and zsh
#          (via /etc/bashrc and /etc/zshrc, both of which loop over /etc/profile.d/*.sh).
#
# NOTHING ZSH-SPECIFIC MAY GO IN THIS FILE. zsh sources it from inside a function that has
# run `emulate -L ksh` (Fedora's /etc/zshrc), so KSH_ARRAYS and SH_WORD_SPLIT are in
# force — not the language zsh plugin scripts are written in. zsh is wired up from the end
# of /etc/zshrc instead, which is AFTER this file in both a login and a non-login shell —
# so everything exported below is in place before zsh initialises the tools that read it
# (DD-036). Bash, which has no such problem, is wired up at the end of this file.
#
# See docs/shell.md and docs/design-decisions.md DD-026, DD-030, DD-036.

# ── Editor ────────────────────────────────────────────────────────────────────
# Neovim is the configured editor; `micro` stays installed for anyone who prefers it.
# Set only when the user has not already chosen, so an override in ~/.bashrc wins.
if [ -z "${EDITOR:-}" ]; then
    EDITOR=nvim
    export EDITOR
fi
if [ -z "${VISUAL:-}" ]; then
    VISUAL=nvim
    export VISUAL
fi

# ── Starship prompt configuration ─────────────────────────────────────────────
# Point starship at the image's config ONLY when the user has none of their own.
# The effect is that ~/.config/starship.toml keeps working exactly as starship documents
# it — create the file and it wins, with nothing to undo here — while the image's copy
# stays in /usr, so a rebase changes the prompt without anything being copied into $HOME.
if [ -z "${STARSHIP_CONFIG:-}" ] &&
   [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ] &&
   [ -f /usr/share/qubix-os/starship.toml ]; then
    STARSHIP_CONFIG=/usr/share/qubix-os/starship.toml
    export STARSHIP_CONFIG
fi

# ── atuin: fully local, and configured without a config file ──────────────────
# atuin reads no system-wide config and does not search $XDG_CONFIG_DIRS, but it does
# read every setting from the environment: `Environment::with_prefix("atuin")` with `__`
# as the nesting separator, so a single underscore is part of the key name and
# ATUIN_AUTO_SYNC is the `auto_sync` setting.
#
# atuin is already local — nothing leaves the machine until an account is registered, and
# this image registers none. These say so explicitly rather than trusting a default to
# stay put, and turn off the update check, since updates arrive with the image.
#
# GUARDED ON THE USER HAVING NO CONFIG OF THEIR OWN, and that guard is load-bearing:
# atuin applies the environment AFTER the config file, so without it these would override
# a setting someone wrote in ~/.config/atuin/config.toml — the opposite of what should
# happen. With it, creating that file switches all of this off, exactly like starship.
if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/atuin/config.toml" ]; then
    ATUIN_AUTO_SYNC=false
    ATUIN_UPDATE_CHECK=false
    ATUIN_SEARCH_MODE=fuzzy
    ATUIN_FILTER_MODE=global
    ATUIN_STYLE=compact
    export ATUIN_AUTO_SYNC ATUIN_UPDATE_CHECK ATUIN_SEARCH_MODE ATUIN_FILTER_MODE
    export ATUIN_STYLE
fi

# ── lazygit: the image's config, with the user's layered on top ───────────────
# lazygit reads one config path of its own (~/.config/lazygit/config.yml) and has no
# system-wide location. LG_CONFIG_FILE replaces that path with a comma-separated LIST in
# which LATER FILES OVERRIDE EARLIER ONES KEY BY KEY — so naming the image's file first and
# the user's second gives a better relationship than starship's all-or-nothing: overriding
# one colour keeps the rest.
#
# THE USER'S PATH IS ONLY ADDED WHEN IT EXISTS. A path in LG_CONFIG_FILE that is missing is
# an error in lazygit (ConfigFilePolicyErrorIfMissing), not a skip, so naming it
# unconditionally would break lazygit for everyone who has no config of their own.
#
# Guarded on LG_CONFIG_FILE being unset, so an export in a user's own rc file wins. Note
# that this is resolved once per shell: create ~/.config/lazygit/config.yml and the next
# shell picks it up.
if [ -z "${LG_CONFIG_FILE:-}" ] && [ -f /usr/share/qubix-os/lazygit/config.yml ]; then
    LG_CONFIG_FILE=/usr/share/qubix-os/lazygit/config.yml
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml" ]; then
        LG_CONFIG_FILE="${LG_CONFIG_FILE},${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
    fi
    export LG_CONFIG_FILE
fi

# ── bash: the interactive setup ───────────────────────────────────────────────
# Last, because it is the only part that is not plain environment. zsh does NOT come
# through here — the block at the end of /etc/zshrc sources its half directly, after this
# file has been read and outside the ksh emulation described above.
if [ -n "${BASH_VERSION:-}" ] && [ -r /usr/share/qubix-os/shell/qubix.bash ]; then
    . /usr/share/qubix-os/shell/qubix.bash
fi
