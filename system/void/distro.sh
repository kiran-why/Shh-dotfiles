# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄▄█ ▀  ▄▄▄ ▄█▄  ▄ ▄▄  ▄▄     ▄▄▄ █▄▄
# █  █ █ ▀▀▄▄  █   █▀   █  █   ▀▀▄▄ █  █
#  ▀▀▀ ▀ ▀▀▀    ▀▀ ▀     ▀▀  ▀ ▀▀▀  ▀  ▀
# distro.sh - what is Void (musl, runit) only: xbps, runit services, the login
# loaded after lib.sh by install.sh, link.sh and shh; every distro has the same functions

# _seatd: screen and input for sway (the group of Void's seatd);
# audio, video: the sound card and the GPU (no elogind)
seat_groups=_seatd,audio,video
# https, not ping: ICMP is often blocked; a few sites, one can be down or blocked
online_sites='https://voidlinux.org https://github.com'
pkg_remove='sudo xbps-remove -R'

# distro_check: stop when this system can't take the setup
distro_check() {
    [ -d /var/service ] && command -v sv >/dev/null || error "runit is not the init system here"

    # NVIDIA's driver is built for glibc only; on musl nouveau (mesa) runs the card
    case "$(xbps-uhelper arch 2>/dev/null)" in
        *-musl) case "$hardware" in
                    *nvidia*) warn "NVIDIA: no NVIDIA driver on musl, nouveau (mesa) runs the card" ;;
                esac ;;
        *)      warn "this setup is tested on Void musl only" ;;
    esac

    # both drive the wifi card; this setup uses iwd
    if [ -e /var/service/wpa_supplicant ]; then
        warn "wpa_supplicant is on, it fights with iwd over wifi"
        info "turn it off: sudo rm /var/service/wpa_supplicant"
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

# pkg_install TAG PKG: no tags on Void, every package comes from xbps.
# </dev/null: xbps must not read the rest of our list.
# An old xbps refuses to install anything until it updates itself:
# that happens on a fresh system, when shh config installs fzf
pkg_install() {
    sudo xbps-install -y "$2" </dev/null && return 0
    sudo xbps-install -Suy xbps </dev/null && sudo xbps-install -y "$2" </dev/null
}

# pkg_exists TAG PKG (--check): 0 found, 1 not found; prints nothing
pkg_exists() {
    xbps-query -R "$2" >/dev/null 2>&1
}

# pkg_missing NAMES: print the ones not installed
pkg_missing() {
    local pkg
    for pkg in "$@"; do
        pkg_installed "$pkg" || echo "$pkg"
    done
}

# pkg_leftovers NAMES: print the installed ones
pkg_leftovers() {
    local pkg
    for pkg in "$@"; do
        ! pkg_installed "$pkg" || printf '%s ' "$pkg"
    done
}

# distro_prepare: the package manager and repos, before any package.
# xbps first: while it is old, xbps-install -u refuses to update anything else
distro_prepare() {
    step "system update"
    sudo xbps-install -Suy xbps </dev/null || error "cannot update xbps (no internet?)"
    sudo xbps-install -uy </dev/null || error "system update failed"
    ok "system updated"
}

# vmware_clipboard: the clipway fork of open-vm-tools is not packaged for Void
vmware_clipboard() {
    [ "$hardware" != vmware ] || info "VMware clipboard: not packaged for Void, skipped"
}

# ▄▀▀▀ █▀▀▀ █▀▀▄ █   █ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀
#  ▀▀▄ █▀▀  █▀█  ▀▄ ▄▀  █  █    █▀▀   ▀▀▄
# ▀▀▀  ▀▀▀▀ ▀  ▀   ▀   ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# svc_apply ON OFF: a runit service is on while /var/service/NAME links to
# /etc/sv/NAME: runsvdir starts it within 5 s and at every boot.
# OFF (turned off in shh config): the link goes, runsvdir stops the service
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

# svc_check SVC (shh doctor): 0 up, 1 down (prints the state), 2 not on.
# sv status works for root only (runsv makes supervise/ 0700), so a user
# looks at the processes: runsv SVC runs the service as its child, and its
# log/ too (Void gives every service one: vlogger), so the logger doesn't count
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
    # pgrep -l: "PID NAME" lines; grep -v: any line that is not a logger
    pgrep -l -P "$pid" | grep -qvE ' (vlogger|svlogd)$' || { echo " down"; return 1; }
}

# the vpn service (scripts/vpn): our own, as root. The package's sing-box
# service runs as _sing_box and can't read the root-only config
vpn_svc=shh-vpn

# vpn_setup RUN: make the service that runs RUN. Known to runit after this,
# but not started at boot: a "down" file in it (vpn > start at boot removes it)
vpn_setup() {
    sudo sh -s -- "$1" <<'EOF' || error "cannot make the runit service shh-vpn"
set -e
mkdir -p /etc/sv/shh-vpn
printf '%s\n' '#!/bin/sh' 'exec 2>&1' "exec $1" >/etc/sv/shh-vpn/run
chmod 755 /etc/sv/shh-vpn/run
if [ ! -e /var/service/shh-vpn ]; then
    touch /etc/sv/shh-vpn/down
    ln -s /etc/sv/shh-vpn /var/service/
fi
EOF
}

# vpn_ctl start | stop | restart (sv: up, down, restart)
vpn_ctl() {
    local cmd="$1"
    case "$1" in start) cmd=up ;; stop) cmd=down ;; esac
    sudo sv "$cmd" /var/service/shh-vpn >/dev/null
}

# vpn_boot: is it started at boot?
vpn_boot() {
    [ -e /var/service/shh-vpn ] && [ ! -e /etc/sv/shh-vpn/down ]
}

# vpn_boot_set yes | no
vpn_boot_set() {
    if [ "$1" = yes ]; then sudo rm -f /etc/sv/shh-vpn/down; else sudo touch /etc/sv/shh-vpn/down; fi
}

# ▄▀▀▀ █▀▀▀ ▄▀▀▀ ▄▀▀▀ ▀█▀ ▄▀▀▄ █▄  █
#  ▀▀▄ █▀▀   ▀▀▄  ▀▀▄  █  █  █ █ ▀▄█
# ▀▀▀  ▀▀▀▀ ▀▀▀  ▀▀▀  ▀▀▀  ▀▀  ▀   ▀

# session_setup: XDG_RUNTIME_DIR at login (sway won't start without it) and ALSA through PipeWire
session_setup() {
    # Void's system-login already has the line; dumb_runtime_dir brings the module
    if grep -q pam_dumb_runtime_dir /etc/pam.d/system-login; then
        info "dumb_runtime_dir: XDG_RUNTIME_DIR at login"
    else
        warn "no pam_dumb_runtime_dir in /etc/pam.d/system-login, sway needs XDG_RUNTIME_DIR"
    fi

    # ALSA programs play through pipewire (Void handbook: PipeWire)
    local conf
    sudo mkdir -p /etc/alsa/conf.d
    for conf in 50-pipewire.conf 99-pipewire-default.conf; do
        [ -e "/etc/alsa/conf.d/$conf" ] ||
            sudo ln -s "/usr/share/alsa/alsa.conf.d/$conf" /etc/alsa/conf.d/ || error "cannot link $conf"
    done
    info "alsa: through pipewire"
}

# distro_undo: what install.sh changed in the system (link.sh --uninstall)
distro_undo() {
    echo "  packages   packages/*.csv        sudo xbps-remove -R NAME"
    echo "  services   services.txt          sudo rm /var/service/NAME"
    echo "  shell      zsh                   chsh -s /bin/bash"
    echo "  groups     _seatd, audio, video  sudo gpasswd -d $(id -un) GROUP"
    echo "  /etc       dhcpcd.conf (denyinterfaces wl*), iwd/main.conf, modprobe.d/nobeep.conf,"
    echo "             alsa/conf.d (pipewire links); older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or dumb_runtime_dir sway will not start"
}
