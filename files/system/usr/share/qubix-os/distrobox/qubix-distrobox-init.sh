#!/bin/sh
# Read by: distrobox-init, INSIDE the guest, at the end of container creation.
#          Called from /etc/distrobox/distrobox.conf on the HOST via the path
#          /run/host/usr/share/qubix-os/distrobox/qubix-distrobox-init.sh, which
#          is the host filesystem's path made visible inside the container.
#
# PURPOSE: give every new Distrobox guest the Qubix zsh experience:
#   - Install zsh and, where not reachable from the host, the zsh plugins.
#   - Install starship and atuin if not reachable from the host.
#   - Drop in /etc/zshrc.d/90-qubix.zsh (or append to /etc/zshrc if that
#     directory is absent) so zsh in the guest sources the Qubix setup.
#   - Drop in /etc/profile.d/qubix-distrobox-env.sh to export STARSHIP_CONFIG
#     and the ATUIN_* variables — the same values the host uses.
#
# CONSTRAINTS:
#   - Must not mutate $HOME. The drop-ins go into /etc/, which is writable in
#     a container and is container-local, not shared with the host.
#   - Runs as the container user (not root). Uses `sudo` for privileged writes,
#     which Distrobox installs and configures without a password inside the guest.
#   - The script is POSIX sh, so it works in any guest distribution.
#   - Package manager auto-detection covers dnf, apt-get, pacman, zypper, and
#     apk. Any other distribution is skipped gracefully with a warning.
#   - /run/host is the host root; host binaries and files are reachable there.
#     starship and atuin are sourced from the host via /run/host/usr/bin when
#     the guest does not have them, by adding /run/host/usr/bin to PATH inside
#     the guest. zsh plugins are sourced from /run/host/usr/share/... for the
#     same reason.
#   - An idempotency guard prevents re-running the whole setup if the marker
#     file /etc/qubix-distrobox-init-done already exists.
#
# LIMITS — documented in docs/shell.md:
#   - Containers created BEFORE this hook was installed are not affected.
#   - The host's /run/host bind mount is the default Distrobox behaviour and is
#     absent in --unshare-all containers without an explicit --volume. This
#     image does not support --unshare-all for Qubix integration.
#   - Package installs depend on network access at container creation time.
#   - The zsh drop-in (qubix-distrobox.zsh) sources from /run/host. If the
#     container's /run/host is unmounted (possible after `distrobox stop`
#     and a manual re-enter without Distrobox), the Qubix setup silently
#     becomes a no-op; bash and the guest's native shell are unaffected.
#
# See docs/shell.md and docs/design-decisions.md DD-043.

set -e

# ── Idempotency guard ─────────────────────────────────────────────────────────
# The init hook runs once at container creation. Guard anyway in case someone
# re-runs this manually or distrobox is upgraded and re-inits.
if [ -f /etc/qubix-distrobox-init-done ]; then
    echo "qubix-distrobox-init: already run, skipping"
    exit 0
fi

echo "qubix-distrobox-init: setting up Qubix zsh environment in guest"

# ── Detect the guest package manager ─────────────────────────────────────────
# Covers Fedora/RHEL (dnf), Debian/Ubuntu (apt-get), Arch (pacman),
# openSUSE (zypper), and Alpine (apk). Each branch installs zsh only;
# the plugins and tools are served from the host via /run/host (below).
install_zsh() {
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y zsh
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y zsh
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm zsh
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y zsh
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add --no-cache zsh
    else
        echo "qubix-distrobox-init: WARNING: unknown package manager — cannot install zsh" >&2
        echo "qubix-distrobox-init: install zsh manually and re-run this script" >&2
        return 1
    fi
}

# Install zsh in the guest if it is not already present.
if ! command -v zsh >/dev/null 2>&1; then
    install_zsh
fi

# Verify zsh is now available; bail out cleanly if not.
if ! command -v zsh >/dev/null 2>&1; then
    echo "qubix-distrobox-init: WARNING: zsh not available after install attempt — skipping" >&2
    exit 0
fi

# ── Drop in the environment file (/etc/profile.d) ─────────────────────────────
# This file exports STARSHIP_CONFIG, ATUIN_*, and LG_CONFIG_FILE — the same
# values as the host's /etc/profile.d/qubix-shell-env.sh, adapted for the guest
# (paths prefixed with /run/host where the file lives on the host).
#
# Using /run/host/usr/share/qubix-os is safe: the file is read by every login
# and interactive shell; if /run/host is absent the sourced script is a no-op
# because its guards check for the file's existence before exporting.
sudo install -m 0644 \
    /run/host/usr/share/qubix-os/distrobox/qubix-distrobox-env.sh \
    /etc/profile.d/qubix-distrobox-env.sh

# ── Drop in the zsh integration ───────────────────────────────────────────────
# Prefer /etc/zshrc.d/ (supported by zsh 5.0+ and present on most modern
# distributions including Fedora, Debian 12, Ubuntu 22.04+, Arch).  Fall back
# to appending to /etc/zshrc for older guests (e.g. Debian 11, Alpine).
#
# The drop-in file itself is stored on the HOST at /usr/share/qubix-os/distrobox/
# and is read FROM the host at runtime via /run/host — so a rebase of the host
# image updates it with no action in the guest.
if [ -d /etc/zshrc.d ]; then
    # Guest supports drop-ins: just link/copy the file.
    sudo install -m 0644 \
        /run/host/usr/share/qubix-os/distrobox/qubix-distrobox.zsh \
        /etc/zshrc.d/90-qubix.zsh
else
    # No drop-in directory: append a source line to /etc/zshrc.
    # The guard prevents appending twice if the script is ever re-run.
    if [ -f /etc/zshrc ] && grep -q 'qubix-distrobox.zsh' /etc/zshrc; then
        echo "qubix-distrobox-init: /etc/zshrc already sources Qubix setup, skipping"
    else
        # Create /etc/zshrc if it does not exist (e.g. Alpine).
        sudo touch /etc/zshrc
        printf '\n# ── Qubix OS (Distrobox guest) ──────────────────────────────────────────\n' \
            | sudo tee -a /etc/zshrc >/dev/null
        printf '# Sourced at container creation by /usr/share/qubix-os/distrobox/qubix-distrobox-init.sh.\n' \
            | sudo tee -a /etc/zshrc >/dev/null
        printf '# The file below lives on the HOST and is served via /run/host.\n' \
            | sudo tee -a /etc/zshrc >/dev/null
        printf '[[ -r /run/host/usr/share/qubix-os/distrobox/qubix-distrobox.zsh ]] &&\n' \
            | sudo tee -a /etc/zshrc >/dev/null
        printf '    source /run/host/usr/share/qubix-os/distrobox/qubix-distrobox.zsh\n' \
            | sudo tee -a /etc/zshrc >/dev/null
    fi
fi

# ── Stamp completion ───────────────────────────────────────────────────────────
sudo touch /etc/qubix-distrobox-init-done

echo "qubix-distrobox-init: done"
