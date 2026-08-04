# Read by: every login shell and every interactive bash/zsh inside a Distrobox
#          guest, via /etc/profile.d (on both login and non-login interactive
#          paths). Installed by qubix-distrobox-init.sh at container creation.
#
# PURPOSE: export the same shell environment variables the Qubix host sets in
#   /etc/profile.d/qubix-shell-env.sh, adapted for the guest:
#   - STARSHIP_CONFIG points at the Qubix starship.toml via /run/host, unless
#     the user has their own ~/.config/starship.toml (which is the same file
#     as on the host, since $HOME is shared).
#   - ATUIN_* variables keep atuin local and in no-sync mode (same as the host).
#     Because $HOME is shared, atuin's database is the same on host and guest.
#   - LG_CONFIG_FILE includes the host's lazygit config and the user's overlay.
#   - EDITOR/VISUAL are set to nvim only if the user has not set them already.
#     nvim is reached via /run/host/usr/bin/nvim if the guest lacks its own.
#
# ALL VALUES ARE RE-RESOLVED IN EVERY SHELL, for the same reason as the host:
#   these variables are exported and would otherwise arrive from the session that
#   launched the terminal — re-resolving makes creating ~/.config/starship.toml
#   take effect in the next shell, not the next login.
#
# POSIX sh only. This file is sourced in a ksh-emulating context by zsh (the
# Fedora /etc/zshrc loop), just as on the host.
#
# See docs/shell.md and docs/design-decisions.md DD-043.

# Guard: if /run/host is absent, this script is a no-op. That happens inside a
# --unshare-all container or when the guest is entered outside Distrobox.
[ -d /run/host/usr ] || return 0

# ── Starship prompt configuration ─────────────────────────────────────────────
# Same logic as the host: point starship at the Qubix config unless the user
# has their own. Because $HOME is shared, the same ~/.config/starship.toml
# applies on both host and guest.
_qubix_starship=/run/host/usr/share/qubix-os/starship.toml
if [ -z "${STARSHIP_CONFIG:-}" ] || [ "${STARSHIP_CONFIG:-}" = "$_qubix_starship" ]; then
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ]; then
        unset STARSHIP_CONFIG
    elif [ -f "$_qubix_starship" ]; then
        STARSHIP_CONFIG="$_qubix_starship"
        export STARSHIP_CONFIG
    fi
fi
unset _qubix_starship

# ── atuin: fully local ────────────────────────────────────────────────────────
# Same variables as the host (DD-037). Because $HOME is shared, the atuin
# database is the same on both host and guest.
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

# ── lazygit config ────────────────────────────────────────────────────────────
# Same merge logic as the host (DD-032).
_qubix_lazygit=/run/host/usr/share/qubix-os/lazygit/config.yml
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

# ── Editor ────────────────────────────────────────────────────────────────────
# Prefer nvim from the guest; fall back to the host's binary.
if [ -z "${EDITOR:-}" ]; then
    if command -v nvim >/dev/null 2>&1; then
        EDITOR=nvim
    elif [ -x /run/host/usr/bin/nvim ]; then
        EDITOR=/run/host/usr/bin/nvim
    fi
    [ -n "${EDITOR:-}" ] && export EDITOR
fi
if [ -z "${VISUAL:-}" ]; then
    VISUAL="${EDITOR:-}"
    [ -n "${VISUAL:-}" ] && export VISUAL
fi
