# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄       ▄▀   ▄▄▄▄ ▄▄▄  ▄ ▄▄  ▄▄   ▄▀▀ ▀ █  ▄▄  
# ▀ ▀▄▀  ▄▀      ▄▀  █  █ █▀   █  █ ▀█▀  █ █ █▀▀▀ 
#       ▀     ▀ ▀▀▀▀ █▀▀  ▀     ▀▀   ▀   ▀ ▀  ▀▀▀ 
#                    ▀                                                       
# starts sway on tty1, other TTYs stay consoles.
# no "set -e": an error must never kill the login shell


# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  
                                          
wm_log="$HOME/.local/state/shh/wm.log"

# our scripts
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# the look of all fzf menus; fzf fails if this file is missing, hence the check
fzfrc="$HOME/.config/fzf/fzfrc"
[ -r "$fzfrc" ] && export FZF_DEFAULT_OPTS_FILE="$fzfrc"

# █   █ ▀█▀ █▀▀▄ ▀▀█▀▀ █  █ ▄▀▀▄ █        █▄ ▄█ ▄▀▀▄ ▄▀▀▀ █  █ ▀█▀ █▄  █ █▀▀▀ ▄▀▀▀ 
# ▀▄ ▄▀  █  █▀█    █   █  █ █▀▀█ █        █ ▀ █ █▀▀█ █    █▀▀█  █  █ ▀▄█ █▀▀   ▀▀▄ 
#   ▀   ▀▀▀ ▀  ▀   ▀    ▀▀  ▀  ▀ ▀▀▀▀     ▀   ▀ ▀  ▀  ▀▀▀ ▀  ▀ ▀▀▀ ▀   ▀ ▀▀▀▀ ▀▀▀  

hardware=$("$HOME/.local/bin/hardware" 2>/dev/null)

case "$hardware" in
    # the hardware cursor is often invisible in a VM
    vmware|virtualbox|qemu|hyperv|xen)
        [ -n "${WLR_NO_HARDWARE_CURSORS:-}" ] || export WLR_NO_HARDWARE_CURSORS=1 ;;
    # hides sway's "not supported" bar on the NVIDIA driver
    *nvidia*)
        export SWAY_UNSUPPORTED_GPU=true ;;
esac

# ▄▀▀▀ █   █ ▄▀▀▄ ▀▄ ▄▀ 
#  ▀▀▄ █▄▀▄█ █▀▀█   █   
# ▀▀▀  ▀   ▀ ▀  ▀   ▀   

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    mkdir -p "$(dirname "$wm_log")"

    # dbus-run-session: a session bus for pipewire and mako.
    # if sway fails you stay in the shell and see the end of its log
    if dbus-run-session sway >"$wm_log" 2>&1; then
        exit
    fi

    echo "sway failed, the end of $wm_log:"
    tail -n 5 "$wm_log"
fi
