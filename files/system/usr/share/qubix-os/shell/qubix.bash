# Read by: bash, sourced from the end of /etc/profile.d/qubix-shell-env.sh.
#
# Bash has none of zsh's problem with /etc/profile.d — those files are ordinary bash there
# — so it needs no second entry point and nothing written into anyone's home directory.
#
# zsh is the default shell here and has the full set (see qubix.zsh). This file exists so
# that an account still on bash, or a shell landed in over SSH, gets the prompt and the
# aliases rather than a bare shell.
#
# See docs/shell.md and docs/design-decisions.md DD-026, DD-030.

# Interactive shells only. /etc/profile.d is sourced for non-interactive login shells too.
case $- in
    *i*) ;;
    *) return 0 ;;
esac

# ── Aliases and functions shared with zsh ─────────────────────────────────────
[ -r /usr/share/qubix-os/shell/common.sh ] &&
    . /usr/share/qubix-os/shell/common.sh

# ── starship — the prompt ─────────────────────────────────────────────────────
# Config resolution is in /etc/profile.d/qubix-shell-env.sh: the image's prompt unless
# ~/.config/starship.toml exists. STARSHIP_SHELL is set by `starship init`, so a user who
# already initialises starship themselves does not get it twice.
if command -v starship >/dev/null 2>&1 && [ -z "${STARSHIP_SHELL:-}" ]; then
    eval "$(starship init bash)"
fi

# ── atuin is deliberately NOT initialised here ────────────────────────────────
# `atuin init bash` needs bash-preexec, which Fedora does not package, and vendoring a
# second history-hooking layer into an image for the non-default shell is not worth it.
# atuin still works as a command in bash — `atuin search`, `atuin stats` — it just does
# not take over Ctrl-R. Ctrl-R remains bash's own reverse search.
# In zsh, atuin needs no such helper and is fully wired up. See docs/shell.md.

return 0
