# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄       ▄▀   ▄▄▄▄ ▄▄▄  ▄ ▄▄  ▄▄   ▄▀▀ ▀ █  ▄▄  
# ▀ ▀▄▀  ▄▀      ▄▀  █  █ █▀   █  █ ▀█▀  █ █ █▀▀▀ 
#       ▀     ▀ ▀▀▀▀ █▀▀  ▀     ▀▀   ▀   ▀ ▀  ▀▀▀ 
#                    ▀                                                       
# Start sway on tty1. The other TTYs stay consoles.
#
# There is no 'set -e': an error must never kill the login shell.


# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  
                                          
wm_log="$HOME/.local/state/shh/wm.log"

# Our scripts.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# The look of all fzf menus. fzf fails if this file is missing, hence
# the check.
fzfrc="$HOME/.config/fzf/fzfrc"
[ -r "$fzfrc" ] && export FZF_DEFAULT_OPTS_FILE="$fzfrc"

# The editor picked in 'shh config' (vim by default). yazi, git and
# others open it.
EDITOR=vim
grep -q '^editor=nvim' "$HOME/.config/shh/config" 2>/dev/null && EDITOR=nvim
export EDITOR

# No accessibility bus (8 MB), unless shh config > settings asks for
# screen readers.
grep -q '^a11y=yes' "$HOME/.config/shh/config" 2>/dev/null || export NO_AT_BRIDGE=1 GTK_A11Y=none

# Every PipeWire program (the daemons, wpctl) asks RTKit for realtime priority
# and prints six "RTKit error" warnings when it is missing. We never install
# rtkit (it pulls in polkit), so keep only real errors from that module.
# PipeWire and WirePlumber read separate variables.
export PIPEWIRE_DEBUG=mod.rt:E WIREPLUMBER_DEBUG=mod.rt:E

# █   █ ▀█▀ █▀▀▄ ▀▀█▀▀ █  █ ▄▀▀▄ █        █▄ ▄█ ▄▀▀▄ ▄▀▀▀ █  █ ▀█▀ █▄  █ █▀▀▀ ▄▀▀▀ 
# ▀▄ ▄▀  █  █▀█    █   █  █ █▀▀█ █        █ ▀ █ █▀▀█ █    █▀▀█  █  █ ▀▄█ █▀▀   ▀▀▄ 
#   ▀   ▀▀▀ ▀  ▀   ▀    ▀▀  ▀  ▀ ▀▀▀▀     ▀   ▀ ▀  ▀  ▀▀▀ ▀  ▀ ▀▀▀ ▀   ▀ ▀▀▀▀ ▀▀▀  

hardware=$("$HOME/.local/bin/hardware" 2>/dev/null)

case "$hardware" in
    # The hardware cursor is often invisible in a VM.
    vmware|virtualbox|qemu|hyperv|xen)
        [ -n "${WLR_NO_HARDWARE_CURSORS:-}" ] || export WLR_NO_HARDWARE_CURSORS=1 ;;
    # Hide the "not supported" bar of sway on the NVIDIA driver.
    *nvidia*)
        # nouveau: Mesa 25.1+ runs GL on Turing and newer through Zink on
        # NVK, and KISS's mesa has no Vulkan.
        export SWAY_UNSUPPORTED_GPU=true NOUVEAU_USE_ZINK=0 ;;
esac

# ▄▀▀▀ █   █ ▄▀▀▄ ▀▄ ▄▀ 
#  ▀▀▄ █▄▀▄█ █▀▀█   █   
# ▀▀▀  ▀   ▀ ▀  ▀   ▀   

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    mkdir -p "$(dirname "$wm_log")"

    # 'dbus-run-session' gives a session bus to pipewire and mako. If sway
    # fails you stay in the shell and see the end of its log.
    if dbus-run-session sway >"$wm_log" 2>&1; then
        exit
    fi

    echo "sway failed, the end of $wm_log:"
    tail -n 5 "$wm_log"
fi
