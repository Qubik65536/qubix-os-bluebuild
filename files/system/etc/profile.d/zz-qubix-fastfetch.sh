# Read by: every interactive bash and zsh, from the /etc/profile.d loop.
#
# WHY THIS FILE EXISTS. Aurora ships /etc/profile.d/ublue-fastfetch.sh, which does:
#
#     alias fastfetch='ublue-fastfetch'
#
# and `ublue-fastfetch` runs fastfetch against Universal Blue's own
# /usr/share/ublue-os/fastfetch.jsonc. An alias is resolved before $PATH and long before
# fastfetch looks at any config directory, so it beats the ENTIRE search path: typing
# `fastfetch` never reached this image's /etc/fastfetch/config.jsonc, and never reached a
# user's own ~/.config/fastfetch/config.jsonc either. DD-031 shipped a config that could
# not be read, and no amount of putting the file somewhere better would have helped.
# DD-040.
#
# WHY THE NAME STARTS WITH zz-, AND WHY IT IS A SECOND FILE. /etc/profile.d is sourced in
# ALPHABETICAL ORDER, and `qubix-shell-env.sh` sorts before `ublue-fastfetch.sh` (q < u) —
# so an unalias there would be undone by the alias a moment later. This has to run after
# every other file in the directory, which is the only thing its name is for. The build
# asserts the result rather than the ordering (recipes/common-base.yml, module 4h).
#
# WHY NOT REPLACE ublue's FILE. It carries two other aliases (`neofetch`, `neowofetch`)
# that are upstream's to define, and replacing it would mean owning their copy forever for
# the sake of deleting one line. Undoing the one line leaves the rest of their file alone
# and flowing through.
#
# NOTHING IS REMOVED. `ublue-fastfetch` is still a command and still prints Universal Blue's
# banner; only the name `fastfetch` goes back to meaning fastfetch.
#
# See docs/shell.md and docs/design-decisions.md DD-031, DD-040.

# Guarded on the alias actually being ublue's, so this is a no-op the day upstream stops
# setting it, and so an alias somebody set deliberately is not silently removed. A user's
# own alias is safe regardless: ~/.bashrc and ~/.zshrc are both read after this file.
case "$(alias fastfetch 2>/dev/null)" in
    *ublue-fastfetch*) unalias fastfetch 2>/dev/null || true ;;
esac
