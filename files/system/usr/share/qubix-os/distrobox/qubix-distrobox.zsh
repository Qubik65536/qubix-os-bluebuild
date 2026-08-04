# Read by: zsh inside a Distrobox guest, sourced from /etc/zshrc.d/90-qubix.zsh
#          (or appended to /etc/zshrc on guests that lack that directory).
#          This file lives on the HOST at /usr/share/qubix-os/distrobox/ and is
#          read at runtime via /run/host, so a host rebase updates it with no
#          action inside the guest.
#
# PURPOSE: give the guest zsh the same interactive experience as the host shell
#   (Starship prompt, Atuin history, zsh-autosuggestions, zsh-syntax-highlighting,
#   completions, and the shared helpers), subject to what is available either
#   natively in the guest or via the host's /run/host bind mount.
#
# DESIGN:
#   - Plugins and tools are sourced from the host (/run/host/usr/share/…) first
#     and from the guest's own paths as a fallback. This means:
#       a) A guest with NO plugins of its own still gets the Qubix experience.
#       b) A guest that has its own copy of a plugin uses the host copy so the
#          version is the same; a user who wants the guest's copy can unset the
#          relevant paths in ~/.zshrc.
#   - starship and atuin are looked up from the host's /run/host/usr/bin if the
#     guest does not have them. Environment variables (STARSHIP_CONFIG, ATUIN_*)
#     are set by /etc/profile.d/qubix-distrobox-env.sh, which the init hook
#     installs at container creation time.
#   - common.sh (cat, y, lg helpers) is sourced from the host.
#   - Nothing in this file touches $HOME.
#   - If /run/host is absent (--unshare-all container, or entered outside
#     Distrobox), every block is silently skipped; bash and the guest's native
#     shell are unaffected.
#
# See docs/shell.md and docs/design-decisions.md DD-043.

# Interactive shells only. Nothing below has any meaning in a script.
[[ -o interactive ]] || return 0

# Detect /run/host mount — all sourcing below depends on it.
# If absent, skip silently: the user is in an environment where the host FS
# is not available (e.g. --unshare-all or a non-Distrobox podman exec).
_qubix_host=/run/host
if [[ ! -d $_qubix_host/usr ]]; then
    unset _qubix_host
    return 0
fi

# ── `#` starts a comment, as it does everywhere else ──────────────────────────
setopt interactive_comments

# ── Aliases and functions shared with bash ────────────────────────────────────
# Use the HOST's copy so the versions match exactly.
[[ -r $_qubix_host/usr/share/qubix-os/shell/common.sh ]] &&
    source "$_qubix_host/usr/share/qubix-os/shell/common.sh"

# ── History ───────────────────────────────────────────────────────────────────
# Same defaults as the host. ~/.zshrc in the guest runs after this and wins.
: ${HISTFILE:=${ZDOTDIR:-$HOME}/.zsh_history}
: ${HISTSIZE:=10000}
: ${SAVEHIST:=10000}

# ── Completion ────────────────────────────────────────────────────────────────
# Same guard as the host's qubix.zsh: run compinit only if it has not been done
# yet. Add the host's site-functions directory to $fpath so host-installed
# completions (zsh-completions, zellij, etc.) are available in the guest.
#
# The guest's own /usr/share/zsh/site-functions is already on the default $fpath
# and is not removed here; both are available.
#
# compaudit cannot establish ownership through Distrobox's /run/host bind mount and
# therefore marks this host-owned directory insecure. Skip that redundant audit after
# this system drop-in has constructed $fpath, before a user's ~/.zshrc can add paths.
fpath=("$_qubix_host/usr/share/zsh/site-functions" $fpath)
if ! (( $+functions[compdef] )); then
    autoload -Uz compinit && compinit -C
fi

# ── atuin ─────────────────────────────────────────────────────────────────────
# Use the host's binary if the guest does not have its own. Because $HOME is
# shared, atuin's history database is the same on host and guest — so the guest
# gets the full host history automatically.
#
# The ATUIN_* variables are set by /etc/profile.d/qubix-distrobox-env.sh
# (installed by the init hook), so the same no-sync / local-only settings apply.
#
# Same init-guard as the host: test for the function, not the exported variable.
if ! (( $+commands[atuin] )) && [[ -x $_qubix_host/usr/bin/atuin ]]; then
    # Make the host binary visible without polluting the guest's PATH permanently;
    # atuin's init will call `atuin` which needs to find the binary.
    path=("$_qubix_host/usr/bin" $path)
fi
if (( $+commands[atuin] )) && (( ! $+functions[_atuin_precmd] )); then
    eval "$(atuin init zsh)"
fi

# ── starship ──────────────────────────────────────────────────────────────────
# Use the host's binary if the guest does not have its own.
# STARSHIP_CONFIG is set by /etc/profile.d/qubix-distrobox-env.sh.
#
# Same precmd guard as the host.
if ! (( $+commands[starship] )) && [[ -x $_qubix_host/usr/bin/starship ]]; then
    path=("$_qubix_host/usr/bin" $path)
fi
if (( $+commands[starship] )) && [[ -z ${precmd_functions[(r)*starship*]} ]]; then
    eval "$(starship init zsh)"
fi

# ── zsh-autosuggestions ───────────────────────────────────────────────────────
# Prefer the host's copy; fall back to the guest's own if present.
_qubix_autosug=$_qubix_host/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r $_qubix_autosug ]] || _qubix_autosug=/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r $_qubix_autosug ]] && source "$_qubix_autosug"
unset _qubix_autosug

# ── zsh-syntax-highlighting — MUST BE LAST ────────────────────────────────────
# Prefer the host's copy; fall back to the guest's own if present.
_qubix_synhi=$_qubix_host/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -r $_qubix_synhi ]] || _qubix_synhi=/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -r $_qubix_synhi ]] && source "$_qubix_synhi"
unset _qubix_synhi

unset _qubix_host

# Never let the status of the last conditional above become the status of the whole file.
return 0
