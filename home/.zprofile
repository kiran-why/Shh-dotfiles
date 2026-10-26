# ~/.zprofile - read once at login: PATH, and sway on tty1
# other ttys (Ctrl+Alt+F2 ...) stay plain consoles for rescue.
# no "set -e" here: an error must never kill the login shell

# sway's output goes here
wm_log="$HOME/.local/state/shh/wm.log"

# ~/.local/bin: our scripts and user-installed programs
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    mkdir -p "$(dirname "$wm_log")"
    # dbus-run-session: a session D-Bus for pipewire and mako.
    # a normal exit from sway logs you out; if sway fails you stay here
    # and see the end of its log
    if dbus-run-session sway >"$wm_log" 2>&1; then
        exit
    fi
    echo "sway failed, the end of $wm_log:"
    tail -n 5 "$wm_log"
fi
