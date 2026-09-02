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
# EVERY EXPORTED VALUE BELOW IS RE-RESOLVED IN EVERY SHELL, and that is deliberate. This
# file is read by the graphical session too — SDDM's wayland-session sources /etc/profile —
# so anything decided once and exported is inherited by every terminal opened under that
# session. Resolving "does the user have a config of their own?" only in the first shell
# would have made the answer good until logout, when the promise these blocks make is that
# creating the file wins in the next shell (DD-037).
#
# See docs/shell.md and docs/design-decisions.md DD-026, DD-030, DD-036, DD-037, DD-038.

# ── The system configuration search path ──────────────────────────────────────
# $XDG_CONFIG_DIRS is the only route to /etc/xdg/wezterm/wezterm.lua: WezTerm reads the
# variable literally and does NOT fall back to the /etc/xdg the XDG base directory
# specification calls the default, so an unset variable means no system config (DD-034).
#
# /usr/lib/environment.d/50-qubix-terminal.conf sets it as well, and cannot do this job
# alone: systemd's user manager applies environment.d to the units IT starts, so a shell
# reached over SSH, on a text console, or through `su -` never sees it — and neither does
# anything launched from one. This is that guarantee for every shell (DD-038).
#
# APPENDED, AND ONLY WHEN MISSING. /etc/xdg goes last, so a session that put its own
# directories first keeps its precedence, and a session that already lists /etc/xdg — every
# Plasma login does, from kde-settings — is left exactly as it was. The `:`-wrapped test is
# what keeps a first or last entry from matching by accident.
case ":${XDG_CONFIG_DIRS:-}:" in
    *:/etc/xdg:*) ;;
    *)
        XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:+${XDG_CONFIG_DIRS}:}/etc/xdg"
        export XDG_CONFIG_DIRS
        ;;
esac

# ── Homebrew application data search path ────────────────────────────────────
# Homebrew's Linux prefix can contain desktop files and icons, but `brew shellenv`
# deliberately does not add its share directory to XDG_DATA_DIRS. The graphical
# session gets the same entry from environment.d; this half covers shells reached
# through SSH, a text console, or `su -`. Prepend once, retain Flatpak/system paths,
# and spell out the XDG defaults when no earlier component supplied the variable.
_qubix_homebrew_share=/home/linuxbrew/.linuxbrew/share
case ":${XDG_DATA_DIRS:-}:" in
    *:"$_qubix_homebrew_share":*) ;;
    *)
        XDG_DATA_DIRS="$_qubix_homebrew_share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        export XDG_DATA_DIRS
        ;;
esac
unset _qubix_homebrew_share

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
#
# THE VALUE IS RE-RESOLVED, not skipped when already set, because STARSHIP_CONFIG is
# exported and would otherwise arrive from the session's own read of this file. Testing it
# against the image's own literal path is what keeps that safe: a shell whose
# STARSHIP_CONFIG is anything else was pointed there by its owner, and is left alone.
_qubix_starship=/usr/share/qubix-os/starship.toml
if [ -z "${STARSHIP_CONFIG:-}" ] || [ "${STARSHIP_CONFIG:-}" = "$_qubix_starship" ]; then
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ]; then
        # Hand starship back to its own default search, which finds the user's file.
        unset STARSHIP_CONFIG
    elif [ -f "$_qubix_starship" ]; then
        STARSHIP_CONFIG="$_qubix_starship"
        export STARSHIP_CONFIG
    fi
fi
unset _qubix_starship

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
#
# THE `unset` BRANCH IS WHAT MAKES "switches off" TRUE IN THE SHELL YOU ARE IN. These are
# exported, so a config.toml written after login would otherwise stay overridden by the
# copy the session exported, until the next login. Only these five names are unset, and
# they are only ever set here.
if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/atuin/config.toml" ]; then
    unset ATUIN_AUTO_SYNC ATUIN_UPDATE_CHECK ATUIN_SEARCH_MODE ATUIN_FILTER_MODE
    unset ATUIN_STYLE
else
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
# RE-RESOLVED IN EVERY SHELL, so that creating ~/.config/lazygit/config.yml is picked up by
# the next shell rather than the next login — LG_CONFIG_FILE is exported, and the session
# reads this file too. The `case` is what keeps a user's own export winning: only an empty
# value, or one that starts with the image's own path, is ours to rewrite.
_qubix_lazygit=/usr/share/qubix-os/lazygit/config.yml
case "${LG_CONFIG_FILE:-}" in
    "" | "$_qubix_lazygit" | "$_qubix_lazygit",*)
        if [ -f "$_qubix_lazygit" ]; then
            LG_CONFIG_FILE="$_qubix_lazygit"
            if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml" ]; then
                LG_CONFIG_FILE="${LG_CONFIG_FILE},${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"
            fi
            export LG_CONFIG_FILE
        fi
        ;;
esac
unset _qubix_lazygit

# ── bash: the interactive setup ───────────────────────────────────────────────
# Last, because it is the only part that is not plain environment. zsh does NOT come
# through here — the block at the end of /etc/zshrc sources its half directly, after this
# file has been read and outside the ksh emulation described above.
if [ -n "${BASH_VERSION:-}" ] && [ -r /usr/share/qubix-os/shell/qubix.bash ]; then
    . /usr/share/qubix-os/shell/qubix.bash
fi
