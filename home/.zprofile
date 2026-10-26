# ~/.zprofile - read once by zsh at login (not by every new terminal)
#
# on tty1 start sway;
# other ttys (Ctrl+Alt+F2 ...) stay plain consoles, handy for rescue.
# no "set -e" here: an error must never kill the login shell

wm_log="$HOME/.local/state/shh/wm.log"

# ~/.local/bin holds our scripts (link.sh puts them there) and user-installed
# programs like claude. Set it before the desktop starts, so the desktop and
# every terminal opened from it inherit it. Added only once, even if this
# file is read again
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# only on the first tty, and only if no desktop is running yet
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    # the log folder may not exist on a fresh system
    mkdir -p "$(dirname "$wm_log")"
    # sway's output goes to a log: the tty scrollback is lost once it starts.
    # dbus-run-session starts a session D-Bus (pipewire and mako need it,
    # without elogind nobody else starts one), runs sway inside it and
    # stops the bus when sway exits.
    # no exec: if sway fails, we stay in this shell and see why, instead
    # of being thrown back to the login over and over. A normal exit
    # from sway (status 0) still logs you out
    if dbus-run-session sway >"$wm_log" 2>&1; then
        exit
    fi
    echo "sway failed, the end of $wm_log:"
    tail -n 5 "$wm_log"
fi
