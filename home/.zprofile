# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄       ▄▀   ▄▄▄▄ ▄▄▄  ▄ ▄▄  ▄▄   ▄▀▀ ▀ █  ▄▄  
# ▀ ▀▄▀  ▄▀      ▄▀  █  █ █▀   █  █ ▀█▀  █ █ █▀▀▀ 
#       ▀     ▀ ▀▀▀▀ █▀▀  ▀     ▀▀   ▀   ▀ ▀  ▀▀▀ 
#                    ▀                                                       
# Start Sway on login.
# Other TTYs stay as normal consoles.
# no "set -e" here: an error must never kill the login shell


# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  
                                          
# sway's logs go here
wm_log="$HOME/.local/state/shh/wm.log"

# ~/.local/bin: our scripts and user-installed programs
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# █   █ ▀█▀ █▀▀▄ ▀▀█▀▀ █  █ ▄▀▀▄ █        █▄ ▄█ ▄▀▀▄ ▄▀▀▀ █  █ ▀█▀ █▄  █ █▀▀▀ ▄▀▀▀ 
# ▀▄ ▄▀  █  █▀█    █   █  █ █▀▀█ █        █ ▀ █ █▀▀█ █    █▀▀█  █  █ ▀▄█ █▀▀   ▀▀▄ 
#   ▀   ▀▀▀ ▀  ▀   ▀    ▀▀  ▀  ▀ ▀▀▀▀     ▀   ▀ ▀  ▀  ▀▀▀ ▀  ▀ ▀▀▀ ▀   ▀ ▀▀▀▀ ▀▀▀  

# in a VM the hardware cursor is often invisible: draw it in software (scripts/vm)
if [ -z "${WLR_NO_HARDWARE_CURSORS:-}" ] && "$HOME/.local/bin/vm" >/dev/null 2>&1; then
    export WLR_NO_HARDWARE_CURSORS=1
fi

# ▄▀▀▀ █   █ ▄▀▀▄ ▀▄ ▄▀ 
#  ▀▀▄ █▄▀▄█ █▀▀█   █   
# ▀▀▀  ▀   ▀ ▀  ▀   ▀   

# Sway starts here :)

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
