# Read by: graphical login sessions and interactive shells through /etc/profile.d.
#
# Fedora's fcitx5-autostart package exports GTK_IM_MODULE=fcitx in fcitx5.sh for every
# graphical session. Native GTK 3/4 applications under Wayland should instead use the
# compositor's text-input protocol when it is available; forcing both paths makes Fcitx
# display its "Wayland Diagnose" warning and can produce duplicate candidate UI. DD-050.
#
# The file name sorts after fcitx5.sh, so this narrows Fedora's broad compatibility
# default without replacing the package-owned file. XMODIFIERS and QT_IM_MODULE remain
# intact for XWayland/X11 and Qt applications. GTK's X11 path is selected separately by
# /etc/gtk-{3,4}.0/settings.ini, while user settings remain higher priority.

# Use the native GTK Wayland input path; retain Fedora's value in X11 sessions.
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    unset GTK_IM_MODULE
fi
