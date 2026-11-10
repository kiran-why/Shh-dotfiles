# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄▄█ ▀  ▄▄▄ ▄█▄  ▄ ▄▄  ▄▄     ▄▄▄ █▄▄
# █  █ █ ▀▀▄▄  █   █▀   █  █   ▀▀▄▄ █  █
#  ▀▀▀ ▀ ▀▀▀    ▀▀ ▀     ▀▀  ▀ ▀▀▀  ▀  ▀
# What only Void has (musl, runit): xbps, runit services, the login.
#
# Loaded after lib.sh by install.sh, link.sh and shh. Every distro.sh has
# the same functions.

# The groups of the user. _seatd: screen and input for sway (the group of
# Void's seatd). audio, video: the sound card and the GPU (no elogind).
seat_groups=_seatd,audio,video
# The sites for the internet check. https, not ping: ICMP is often
# blocked. A few of them, as one can be down or blocked.
online_sites='https://voidlinux.org https://github.com'
pkg_remove='sudo xbps-remove -R'
# The root commands of power_run, for the sudoers rule (install.sh).
# "" means no arguments.
power_cmds='/usr/bin/poweroff "", /usr/bin/reboot "", /usr/bin/zzz ""'

# Power off, reboot or suspend (scripts/power).
#
# 'sudo -n' fails instead of asking for a password. zzz prints "Zzzz...".
power_run() {
    case "$1" in
        suspend) sudo -n /usr/bin/zzz >/dev/null ;;
        *)       sudo -n "/usr/bin/$1" ;;
    esac
}

# Stop when this system can't take the setup.
distro_check() {
    [ -d /var/service ] && command -v sv >/dev/null || error "runit is not the init system here"

    # NVIDIA's driver is built for glibc only. On musl nouveau (mesa) runs
    # the card.
    case "$(xbps-uhelper arch 2>/dev/null)" in
        *-musl) case "$hardware" in
                    *nvidia*) warn "NVIDIA: no NVIDIA driver on musl, nouveau (mesa) runs the card" ;;
                esac ;;
        *)      warn "this setup is tested on Void musl only" ;;
    esac

    # Both drive the wifi card, and this setup uses iwd.
    if [ -e /var/service/wpa_supplicant ]; then
        warn "wpa_supplicant is on, it fights with iwd over wifi"
        info "turn it off: sudo rm /var/service/wpa_supplicant"
    fi
    # The handler.sh of Void's acpid suspends on a closed lid as root, with
    # no screen lock.
    if [ -e /var/service/acpid ]; then
        warn "acpid is on, it suspends on a closed lid without the screen lock"
        info "turn it off: sudo rm /var/service/acpid"
    fi
    if [ -e /var/service/elogind ]; then
        warn "elogind is on, this setup uses seatd instead"
        info "turn it off: sudo rm /var/service/elogind"
    fi
}

# █▀▀▄ ▄▀▀▄ ▄▀▀▀ █ ▄▀ ▄▀▀▄ ▄▀▀▀ █▀▀▀ ▄▀▀▀
# █▀▀  █▀▀█ █    █▀▄  █▀▀█ █ ▀█ █▀▀   ▀▀▄
# ▀    ▀  ▀  ▀▀▀ ▀  ▀ ▀  ▀  ▀▀▀ ▀▀▀▀ ▀▀▀

pkg_installed() {
    xbps-query "$1" >/dev/null 2>&1
}

# Install a package: pkg_install TAG PKG (no tags on Void).
#
# '</dev/null' keeps xbps from reading the rest of our list. An old xbps
# refuses to install anything until it updates itself. That happens on a
# fresh system, when 'shh config' installs fzf.
pkg_install() {
    sudo xbps-install -y "$2" </dev/null && return 0
    sudo xbps-install -Suy xbps </dev/null && sudo xbps-install -y "$2" </dev/null
}

# Check that a package exists ('--check'): 0 found, 1 not found.
pkg_exists() {
    xbps-query -R "$2" >/dev/null 2>&1
}

# Print the packages that are not installed.
pkg_missing() {
    local pkg
    for pkg in "$@"; do
        pkg_installed "$pkg" || echo "$pkg"
    done
}

# Print the packages that are installed.
pkg_leftovers() {
    local pkg
    for pkg in "$@"; do
        ! pkg_installed "$pkg" || printf '%s ' "$pkg"
    done
}

# Update the package manager and the system, before any package.
#
# xbps goes first: while it is old, 'xbps-install -u' refuses to update
# anything else.
distro_prepare() {
    step "system update"
    sudo xbps-install -Suy xbps </dev/null || error "cannot update xbps (no internet?)"
    sudo xbps-install -uy </dev/null || error "system update failed"
    ok "system updated"
}

# Skip the VMware clipboard: the clipway fork of open-vm-tools is not
# packaged for Void.
vmware_clipboard() {
    [ "$hardware" != vmware ] || info "VMware clipboard: not packaged for Void, skipped"
}

# ▄▀▀▀ █▀▀▀ █▀▀▄ █   █ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀
#  ▀▀▄ █▀▀  █▀█  ▀▄ ▄▀  █  █    █▀▀   ▀▀▄
# ▀▀▀  ▀▀▀▀ ▀  ▀   ▀   ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# Turn services on and off: svc_apply ON OFF.
#
# A runit service is on while /var/service/NAME links to /etc/sv/NAME:
# runsvdir starts it within 5 s and at every boot. Without the link
# runsvdir stops it.
svc_apply() {
    local svc
    for svc in $1; do
        [ -d "/etc/sv/$svc" ] || error "no service $svc in /etc/sv"
        if [ ! -e "/var/service/$svc" ]; then
            sudo ln -s "/etc/sv/$svc" /var/service/ || error "cannot enable $svc"
            info "enabled $svc"
        fi
    done
    for svc in $2; do
        [ -L "/var/service/$svc" ] || continue
        sudo rm "/var/service/$svc" || error "cannot disable $svc"
        info "disabled $svc"
    done
}

# Check a service for 'shh doctor': 0 up, 1 down (prints the state), 2 not on.
#
# 'sv status' works for root only (runsv makes supervise/ 0700). A user
# looks at the processes instead: 'runsv SVC' runs the service as its
# child. Its log/ is a child too (Void gives every service one), so the
# logger does not count.
svc_check() {
    local state pid
    [ -e "/var/service/$1" ] || return 2
    if state=$(sv status "/var/service/$1" 2>/dev/null); then
        case "$state" in
            run:*) return 0 ;;
            *)     echo " ${state%%:*}"; return 1 ;;
        esac
    fi
    pid=$(pgrep -x -f "runsv $1") || { echo " runsv not running"; return 1; }
    # 'pgrep -l' prints "PID NAME" lines, 'grep -v' finds one that is not a
    # logger.
    pgrep -l -P "$pid" | grep -qvE ' (vlogger|svlogd)$' || { echo " down"; return 1; }
}

# Start or stop a service now, till the reboot (settings > Svc).
#
# runit has no dependencies: with dbus off iwd fails and restarts.
svc_ctl() {
    local cmd=up
    [ "$1" = start ] || cmd=down
    sudo sv "$cmd" "/var/service/$2" >/dev/null
}

# Print every service, one per line (settings > Svc > All).
#
# Only the ones linked in /var/service are on (svc_check gives 2 for the
# rest).
svc_list() {
    { ls /etc/sv; ls /var/service; } | sort -u
}

# The consoles nobody uses, turned off by svc_apply. tty1 runs sway, tty2
# stays for repairs.
svc_unused='agetty-tty3 agetty-tty4 agetty-tty5 agetty-tty6'

# The vpn service (scripts/vpn): our own, run as root. The sing-box
# service of the package runs as _sing_box and can't read the root-only
# config.
vpn_svc=shh-vpn

# Make the service that runs the command '$1'.
#
# runit knows it after this, but a "down" file keeps it from starting at
# boot (vpn > Start at boot removes the file). The log/ is like the one
# of Void's own services (vlogger to syslog). Without it sing-box writes
# over the login prompt.
vpn_setup() {
    sudo sh -s -- "$1" <<'EOF' || error "cannot make the runit service shh-vpn"
set -e
mkdir -p /etc/sv/shh-vpn/log
printf '%s\n' '#!/bin/sh' 'exec 2>&1' "exec $1" >/etc/sv/shh-vpn/run
printf '%s\n' '#!/bin/sh' 'exec vlogger -t shh-vpn -p daemon' >/etc/sv/shh-vpn/log/run
chmod 755 /etc/sv/shh-vpn/run /etc/sv/shh-vpn/log/run
if [ ! -e /var/service/shh-vpn ]; then
    touch /etc/sv/shh-vpn/down
    ln -s /etc/sv/shh-vpn /var/service/
fi
EOF
}

# Start, stop or restart the vpn ('sv up', 'down', 'restart').
vpn_ctl() {
    local cmd="$1"
    case "$1" in start) cmd=up ;; stop) cmd=down ;; esac
    sudo sv "$cmd" /var/service/shh-vpn >/dev/null
}

# Check if the vpn starts at boot.
vpn_boot() {
    [ -e /var/service/shh-vpn ] && [ ! -e /etc/sv/shh-vpn/down ]
}

# Make the vpn start at boot, or not: vpn_boot_set yes | no.
vpn_boot_set() {
    if [ "$1" = yes ]; then sudo rm -f /etc/sv/shh-vpn/down; else sudo touch /etc/sv/shh-vpn/down; fi
}

# ▄▀▀▀ █▀▀▀ ▄▀▀▀ ▄▀▀▀ ▀█▀ ▄▀▀▄ █▄  █
#  ▀▀▄ █▀▀   ▀▀▄  ▀▀▄  █  █  █ █ ▀▄█
# ▀▀▀  ▀▀▀▀ ▀▀▀  ▀▀▀  ▀▀▀  ▀▀  ▀   ▀

# Set up the login session: XDG_RUNTIME_DIR at login (sway won't start
# without it) and ALSA through PipeWire.
session_setup() {
    # Void's system-login already has the line, and dumb_runtime_dir brings
    # the module.
    if grep -q pam_dumb_runtime_dir /etc/pam.d/system-login; then
        info "dumb_runtime_dir: XDG_RUNTIME_DIR at login"
    else
        warn "no pam_dumb_runtime_dir in /etc/pam.d/system-login, sway needs XDG_RUNTIME_DIR"
    fi

    # ALSA programs play through pipewire (Void handbook: PipeWire).
    local conf
    sudo mkdir -p /etc/alsa/conf.d
    for conf in 50-pipewire.conf 99-pipewire-default.conf; do
        [ -e "/etc/alsa/conf.d/$conf" ] ||
            sudo ln -s "/usr/share/alsa/alsa.conf.d/$conf" /etc/alsa/conf.d/ || error "cannot link $conf"
    done
    info "alsa: through pipewire"
}

# Add the user to GROUPS (comma-separated).
user_groups() {
    sudo usermod -aG "$1" "$USER"
}

# Set the login shell of the user.
user_shell() {
    sudo chsh -s "$1" "$USER"
}

# Print what install.sh changed in the system ('link.sh --uninstall').
distro_undo() {
    echo "  packages   packages/*.csv        sudo xbps-remove -R NAME"
    echo "  services   services.txt          sudo rm /var/service/NAME"
    echo "  shell      zsh                   chsh -s /bin/bash"
    echo "  groups     _seatd, audio, video  sudo gpasswd -d $(id -un) GROUP"
    echo "  /etc       dhcpcd.conf (denyinterfaces wl*), iwd/main.conf, modprobe.d/nobeep.conf,"
    echo "             alsa/conf.d (pipewire links), sudoers.d/shh-power (poweroff, reboot, zzz):"
    echo "             sudo rm /etc/sudoers.d/shh-power; older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or dumb_runtime_dir sway will not start"
}
