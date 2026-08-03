# Read by: qubix.bash and qubix.zsh, in this directory. Never sourced directly by a shell
#          startup file, and never by /etc/profile.d — see qubix-shell-env.sh for why.
#
# The interactive conveniences that are written identically in bash and zsh. Anything that
# needs shell-specific syntax belongs in qubix.bash or qubix.zsh instead.
#
# Sourced only from interactive shells, so `local`, functions and aliases are all fair
# game; strict POSIX is not required, but nothing here uses a bashism zsh lacks.
#
# See docs/shell.md and docs/design-decisions.md DD-026, DD-030.

# ── cat → bat ─────────────────────────────────────────────────────────────────
# `--style=plain --paging=never` is what keeps this a drop-in: no line numbers, no file
# header, no pager — just the file, with syntax highlighting. bat already writes plain
# bytes when stdout is not a terminal, so `cat file | grep x` is unaffected either way.
#
# For the real thing (or for `cat -n`, which bat does not accept): `command cat`.
# For bat with all its decorations: `bat`, which is still just bat.
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --style=plain --paging=never'
fi

# ── yazi, as `y` ──────────────────────────────────────────────────────────────
# Upstream's documented wrapper. Running `yazi` directly works fine; the only thing this
# adds is that quitting leaves the shell in the directory the browser was last in, which
# is the reason to use a terminal file browser at all.
#
# `command cat` is deliberate: the alias above would otherwise send the temp file through
# bat, and bat's output is not guaranteed to be the byte-exact path yazi wrote.
if command -v yazi >/dev/null 2>&1; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return 1
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || true
        fi
        rm -f -- "$tmp"
    }
fi

# ── lazygit, as `lg` ──────────────────────────────────────────────────────────
# Upstream's wrapper (README, "Changing Directory On Exit"), for the same reason as `y`:
# lazygit can switch between repositories from inside its UI, and without this the shell
# is still in the one you started from when you leave.
#
# lazygit writes the new directory to $LAZYGIT_NEW_DIR_FILE and only when you quit with
# `q`; `Q` leaves the shell where it was. Upstream's snippet points that variable at
# ~/.lazygit/newdir — a stray dot directory in $HOME — so this uses mktemp instead, and
# `command cat` for the same reason as above: the alias would send it through bat.
#
# `lazygit` itself is untouched and behaves exactly as it always has.
if command -v lazygit >/dev/null 2>&1; then
    lg() {
        local tmp dir
        tmp="$(mktemp -t lazygit-cwd.XXXXXX)" || return 1
        LAZYGIT_NEW_DIR_FILE="$tmp" lazygit "$@"
        # The file is created empty by mktemp and only filled by lazygit, so an empty one
        # means "stay where you are" — no need to remove it first and race for the name.
        if dir="$(command cat -- "$tmp")" && [ -n "$dir" ] && [ "$dir" != "$PWD" ]; then
            builtin cd -- "$dir" || true
        fi
        rm -f -- "$tmp"
    }
fi
