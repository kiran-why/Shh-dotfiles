# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄▄█ ▀  ▄▄▄ ▄█▄  ▄ ▄▄  ▄▄     ▄▄▄ █▄▄
# █  █ █ ▀▀▄▄  █   █▀   █  █   ▀▀▄▄ █  █
#  ▀▀▀ ▀ ▀▀▀    ▀▀ ▀     ▀▀  ▀ ▀▀▀  ▀  ▀
# distro.sh - what is KISS (musl, busybox runit) only: kiss, runit services, the login
# loaded after lib.sh by install.sh, link.sh and shh; every distro has the same functions

# video: the group seatd gives its socket to (libseat's seatd.run), and the GPU;
# audio: the sound card; wheel: iwd lets only wheel and netdev use iwctl
seat_groups=audio,video,wheel
# https, not ping: ICMP is often blocked; a few sites, one can be down or blocked
online_sites='https://kisslinux.github.io https://codeberg.org https://github.com'
pkg_remove='kiss r'
# the root commands of power_run, for the sudoers rule (install.sh); "" = no arguments.
# no zzz here: suspend is "mem" written to /sys/power/state
power_cmds='/usr/bin/poweroff "", /usr/bin/reboot "", /usr/bin/tee /sys/power/state'

# the repos kiss builds from, cloned by kiss_repos; shh = our recipes. Ours come
# first, the first recipe found wins
kiss_dir="$HOME/.local/share/kiss"
export KISS_PATH="$kiss_dir/shh:$kiss_dir/repo/core:$kiss_dir/repo/extra:$kiss_dir/repo/wayland:$kiss_dir/community/community:$kiss_dir/kiss-dbus/dbus"
export KISS_PROMPT=0

# power_run poweroff | reboot | suspend (scripts/power); -n: fail, don't ask for a password
power_run() {
    case "$1" in
        suspend) echo mem | sudo -n /usr/bin/tee /sys/power/state >/dev/null ;;
        *)       sudo -n "/usr/bin/$1" ;;
    esac
}

# distro_check: stop when this system can't take the setup
distro_check() {
    [ -d /var/service ] && command -v sv >/dev/null || error "runit is not the init system here"

    # NVIDIA's driver is built for glibc only; on musl nouveau (mesa) runs the card
    case "$hardware" in
        *nvidia*) warn "NVIDIA: no NVIDIA driver on musl, nouveau (mesa) runs the card" ;;
    esac

    # not in base; install.sh needs it before it can build anything
    if ! command -v sudo >/dev/null; then
        info "as root: kiss b sudo (the community repo must be in KISS_PATH)"
        info "then: addgroup $USER wheel, and in visudo uncomment the line %wheel ALL=(ALL:ALL) ALL"
    fi
}

# █▀▀▄ ▄▀▀▄ ▄▀▀▀ █ ▄▀ ▄▀▀▄ ▄▀▀▀ █▀▀▀ ▄▀▀▀
# █▀▀  █▀▀█ █    █▀▄  █▀▀█ █ ▀█ █▀▀   ▀▀▄
# ▀    ▀  ▀  ▀▀▀ ▀  ▀ ▀  ▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# kiss_repos: clone the repos that are missing and copy our recipes.
# A copy: kiss u would run git pull in the dotfiles repo otherwise.
# Started from ~/.local/bin there are no recipes next to distro.sh, the copy stays
kiss_repos() {
    local url src
    mkdir -p "$kiss_dir" || error "cannot create $kiss_dir"
    for url in https://github.com/kiss-community/repo \
               https://github.com/kiss-community/community \
               https://codeberg.org/kiss-community/kiss-dbus; do
        [ -d "$kiss_dir/${url##*/}" ] ||
            git clone --depth 1 "$url" "$kiss_dir/${url##*/}" || error "cannot clone $url"
    done
    src="${system_dir:-${distro_file%/*}}/repo"
    [ ! -d "$src" ] || { rm -rf "$kiss_dir/shh" && cp -R "$src" "$kiss_dir/shh"; } ||
        error "cannot copy the recipes to $kiss_dir/shh"
}

pkg_installed() {
    kiss l "$1" >/dev/null 2>&1
}

# pkg_install TAG PKG: no tags on KISS. With KISS_PROMPT=0 kiss b installs the
# dependencies but only builds PKG itself, so kiss i after it.
# </dev/null: kiss must not read the rest of our list.
# The first call can come from shh config, before distro_prepare
pkg_install() {
    [ -d "$kiss_dir/shh" ] || kiss_repos
    kiss b "$2" </dev/null && kiss i "$2" </dev/null
}

# pkg_exists TAG PKG (--check): 0 found, 1 not found; prints nothing
pkg_exists() {
    [ -d "$kiss_dir/shh" ] || kiss_repos >/dev/null
    kiss s "$2" >/dev/null 2>&1
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

# distro_prepare: the repos and the whole system, before any package;
# everything is built from source, the first run takes hours
distro_prepare() {
    step "system update"
    kiss_repos
    kiss u </dev/null || error "cannot update the repos (no internet?)"
    kiss U </dev/null || error "system update failed"
    ok "system updated"
}

# vmware_clipboard: the clipway fork of open-vm-tools is not packaged for KISS
vmware_clipboard() {
    [ "$hardware" != vmware ] || info "VMware clipboard: not packaged for KISS, skipped"
}

# ▄▀▀▀ █▀▀▀ █▀▀▄ █   █ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀
#  ▀▀▄ █▀▀  █▀█  ▀▄ ▄▀  █  █    █▀▀   ▀▀▄
# ▀▀▀  ▀▀▀▀ ▀  ▀   ▀   ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# svc_apply ON OFF: a runit service is on while /var/service/NAME links to
# /etc/sv/NAME: runsvdir starts it within 5 s and at every boot.
# OFF (turned off in shh config): the link goes, runsvdir stops the service.
# kiss-dbus's iwd comes without a service, so it gets ours
svc_apply() {
    local svc
    write_root /etc/sv/iwd/run "$(printf '#!/bin/sh\nexec iwd 2>&1')"
    sudo chmod 755 /etc/sv/iwd/run || error "cannot chmod /etc/sv/iwd/run"

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
# log/ too, so the logger doesn't count
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
    # pgrep -l: "PID NAME" lines; grep -v: any line that is not the logger
    pgrep -l -P "$pid" | grep -qv ' svlogd$' || { echo " down"; return 1; }
}

# svc_ctl start | stop SVC (settings > Services): now, till the reboot
# (sv up / down; runit has no dependencies: with dbus off iwd fails and restarts)
svc_ctl() {
    local cmd=up
    [ "$1" = start ] || cmd=down
    sudo sv "$cmd" "/var/service/$2" >/dev/null
}

# svc_list (settings > Svc > All): every service, one per line; only the ones
# linked in /var/service are enabled (svc_check 2 for the rest)
svc_list() {
    { ls /etc/sv; ls /var/service; } | sort -u
}

# none: the gettys are in /etc/inittab, not services (tty1 and tty2 by default)
svc_unused=''

# the vpn service (scripts/vpn): our own, as root
vpn_svc=shh-vpn

# vpn_setup RUN: make the service that runs RUN. Known to runit after this,
# but not started at boot: a "down" file in it (vpn > start at boot removes it).
# log/: without it sing-box writes over the login prompt on the console;
# svlogd, as KISS has no syslog running by default
vpn_setup() {
    sudo sh -s -- "$1" <<'EOF' || error "cannot make the runit service shh-vpn"
set -e
mkdir -p /etc/sv/shh-vpn/log /var/log/shh-vpn
printf '%s\n' '#!/bin/sh' 'exec 2>&1' "exec $1" >/etc/sv/shh-vpn/run
printf '%s\n' '#!/bin/sh' 'exec svlogd -tt /var/log/shh-vpn' >/etc/sv/shh-vpn/log/run
chmod 755 /etc/sv/shh-vpn/run /etc/sv/shh-vpn/log/run
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

# session_setup: no PAM and no udev here. rc.boot sources /etc/rc.d/*.boot at
# every boot (/run is empty then); login shells read /etc/profile.d (zsh too:
# KISS's /etc/zprofile loads /etc/profile). ALSA through PipeWire: firefox has
# only the ALSA backend on KISS.
# shortcut: brightness is set once at boot, a backlight that appears later needs an mdev.conf rule
session_setup() {
    local uid
    uid=$(id -u)
    write_root /etc/rc.d/shh.boot "mkdir -p -m 700 /run/user/$uid
chown $USER /run/user/$uid
for light in /sys/class/backlight/*/brightness; do
    [ -e \"\$light\" ] && chgrp video \"\$light\" && chmod g+w \"\$light\"
done"
    write_root /etc/profile.d/shh.sh "export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export KISS_PATH=$KISS_PATH"
    info "XDG_RUNTIME_DIR at login, brightness: group video"

    [ -e /etc/asound.conf ] || [ -L /etc/asound.conf ] ||
        sudo ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/asound.conf ||
        error "cannot link /etc/asound.conf"
    info "alsa: through pipewire"

    # KISS's patch makes pipewire start wireplumber, and scripts/sound starts it too
    write_root /etc/pipewire/pipewire.conf.d/shh.conf 'context.properties = { exec.session-manager = false }'
}

# user_groups GROUPS: add the user to GROUPS (comma-separated); busybox has
# no usermod, addgroup USER GROUP takes one group
user_groups() {
    local group
    for group in $(printf %s "$1" | tr , ' '); do
        sudo addgroup "$USER" "$group" || error "cannot add $USER to $group"
    done
}

# user_shell SHELL: the login shell of the user; busybox has no chsh
user_shell() {
    sudo sed -i "/^$USER:/s|[^:]*\$|$1|" /etc/passwd || error "cannot edit /etc/passwd"
}

# distro_undo: what install.sh changed in the system (link.sh --uninstall)
distro_undo() {
    echo "  packages   packages/*.csv        kiss r NAME"
    echo "  repos      $kiss_dir             rm -r it"
    echo "  services   services.txt          sudo rm /var/service/NAME"
    echo "  shell      zsh                   the last field of your line in /etc/passwd"
    echo "  groups     audio, video, wheel   sudo delgroup $(id -un) GROUP"
    echo "  /etc       rc.d/shh.boot, profile.d/shh.sh (XDG_RUNTIME_DIR, brightness, KISS_PATH), sv/iwd,"
    echo "             dhcpcd.conf (denyinterfaces wl*), iwd/main.conf, modprobe.d/nobeep.conf, asound.conf, pipewire/pipewire.conf.d/shh.conf,"
    echo "             sudoers.d/shh-power (poweroff, reboot, sleep): sudo rm /etc/sudoers.d/shh-power;"
    echo "             older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or rc.d/shh.boot sway will not start"
}
