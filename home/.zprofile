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

# Auto-detect VMs and disable hardware cursors if needed (workaround for invisible cursor)
if [ -z "${WLR_NO_HARDWARE_CURSORS:-}" ]; then
    _isvm=0

    # Check DMI info
    for _f in /sys/devices/virtual/dmi/id/sys_vendor /sys/devices/virtual/dmi/id/product_name /sys/devices/virtual/dmi/id/board_name; do
        [ -r "$_f" ] || continue
        if grep -qiE '(vmware|virtualbox|innotek|oracle|qemu|kvm|hyper-v|microsoft corporation)' "$_f"; then
            _isvm=1
            break
        fi
    done

    # Check hypervisor type as fallback
    if [ "$_isvm" -eq 0 ] && [ -r /sys/hypervisor/type ]; then
        grep -qiE '(vmware|xen|kvm)' /sys/hypervisor/type && _isvm=1
    fi

    # Check for vmware kernel module as fallback
    if [ "$_isvm" -eq 0 ] && [ -r /proc/modules ]; then
        grep -q '^vmwgfx ' /proc/modules && _isvm=1
    fi

    [ "$_isvm" -eq 1 ] && export WLR_NO_HARDWARE_CURSORS=1
    unset _isvm _f
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
