# ~/.zprofile - read once by zsh at login (not by every new terminal)
#
# on tty1 start the desktop chosen during install.sh;
# other ttys (Ctrl+Alt+F2 ...) stay plain consoles, handy for rescue.
# no "set -e" here: an error must never kill the login shell

wm_file="$HOME/.local/state/shh/wm"
wm_log="$HOME/.local/state/shh/wm.log"

# only on the first tty, and only if no desktop is running yet
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    wm=$(cat "$wm_file" 2>/dev/null)

    case "$wm" in
        # exec: the desktop replaces this shell, so leaving it logs you out.
        # its output goes to a log: the tty scrollback is lost once it starts
        sway)    exec sway >"$wm_log" 2>&1 ;;
        # VERIFY: binary name of driftwm not checked yet
        driftwm) exec driftwm >"$wm_log" 2>&1 ;;
        *)       echo "shh: no desktop in $wm_file, staying in the shell" ;;
    esac
fi
