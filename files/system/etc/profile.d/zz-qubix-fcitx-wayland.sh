# Read by: graphical login sessions and interactive shells through /etc/profile.d.
#
# Fedora's fcitx5-autostart package exports toolkit modules in fcitx5.sh for graphical
# sessions. Native GTK 3/4 applications under Wayland should instead use the compositor's
# text-input protocol. KDE Plasma also gives Qt and SDL clients to KWin's native Fcitx
# frontend, while niri still needs the Qt module because it lacks that KWin-only path.
# Forcing both routes makes Fcitx display its "Wayland Diagnose" warning. DD-050, DD-067.
#
# The file name sorts after fcitx5.sh, so this narrows Fedora's broad compatibility
# default without replacing the package-owned file. XMODIFIERS always remains intact for
# XWayland; GTK's X11 path is selected separately by /etc/gtk-{3,4}.0/settings.ini.

# Use native Wayland input paths, with Qt/SDL removal scoped to Plasma only. SDDM supplies
# the desktop identity before it starts the login shell and sources this file.
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    unset GTK_IM_MODULE

    case "${XDG_CURRENT_DESKTOP:-}:${XDG_SESSION_DESKTOP:-}" in
        *KDE*|*Plasma*|*plasma*)
            unset QT_IM_MODULE SDL_IM_MODULE
            ;;
    esac
fi
