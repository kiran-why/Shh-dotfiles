# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄▄█ ▀  ▄▄▄ ▄█▄  ▄ ▄▄  ▄▄     ▄▄▄ █▄▄
# █  █ █ ▀▀▄▄  █   █▀   █  █   ▀▀▄▄ █  █
#  ▀▀▀ ▀ ▀▀▀    ▀▀ ▀     ▀▀  ▀ ▀▀▀  ▀  ▀
# distro.sh - what is Artix (s6) only: pacman, AUR, s6 services, the login
# loaded after lib.sh by install.sh and shh; every distro has the same functions

# seat: screen and input for sway; audio: the sound card (no elogind); video: the screen brightness
seat_groups=seat,audio,video
# https, not ping: ICMP is often blocked; a few sites, one can be down or blocked
online_sites='https://artixlinux.org https://archlinux.org https://github.com'
pkg_remove='sudo pacman -Rs'
# the root commands of power_run, for the sudoers rule (install.sh); "" = no arguments.
# no zzz on Artix: suspend is "mem" written to /sys/power/state
power_cmds='/usr/bin/poweroff "", /usr/bin/reboot "", /usr/bin/tee /sys/power/state'

# power_run poweroff | reboot | suspend (scripts/power); -n: fail, don't ask for a password
power_run() {
    case "$1" in
        suspend) echo mem | sudo -n /usr/bin/tee /sys/power/state >/dev/null ;;
        *)       sudo -n "/usr/bin/$1" ;;
    esac
}

# distro_check: stop when this system can't take the setup
distro_check() {
    command -v s6-rc >/dev/null || error "s6 is not the init system here"

    # seatd-s6 and elogind-s6 conflict; pacman --noconfirm can't swap them
    if pkg_installed elogind-s6; then
        warn "elogind-s6 is installed, this setup uses seatd instead"
        info "swap it: sudo pacman -S seatd-s6  (answer y to remove elogind-s6)"
        error "replace elogind-s6 with seatd-s6, then run install.sh again"
    fi

    # an old install guide started dhcpcd from rc.local; the s6 service does it now
    if grep -q '^[[:space:]]*dhcpcd' /etc/s6/rc.local 2>/dev/null; then
        warn "/etc/s6/rc.local starts dhcpcd too, comment that line out"
    fi
}

# █▀▀▄ ▄▀▀▄ ▄▀▀▀ █ ▄▀ ▄▀▀▄ ▄▀▀▀ █▀▀▀ ▄▀▀▀
# █▀▀  █▀▀█ █    █▀▄  █▀▀█ █ ▀█ █▀▀   ▀▀▄
# ▀    ▀  ▀  ▀▀▀ ▀  ▀ ▀  ▀  ▀▀▀ ▀▀▀▀ ▀▀▀

pkg_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

# aur_install PKG: paru shows every PKGBUILD for review unless told not to.
# </dev/null: it must not read the rest of a list we loop over
aur_install() {
    local helper review=''
    helper=$(setting aur_helper yay)
    [ "$helper" != paru ] || review=--skipreview
    "$helper" -S --needed --noconfirm $review "$1" </dev/null
}

# pkg_install TAG PKG: empty tag = pacman, A = AUR
pkg_install() {
    # </dev/null: pacman must not read the rest of our list
    case "$1" in
        A) aur_install "$2" ;;
        *) sudo pacman -S --needed --noconfirm "$2" </dev/null ;;
    esac
}

# in_arch PKG: is PKG in Arch [extra]? pacman can't tell before distro_prepare
in_arch() {
    curl -s -m 10 "https://archlinux.org/packages/search/json/?name=$1&repo=Extra" |
        grep -q '"pkgname"'
}

# pkg_exists TAG PKG (--check): 0 found, 1 not found, 2 can't tell yet;
# prints a note for the message
pkg_exists() {
    local helper
    helper=$(setting aur_helper yay)
    if [ "$1" = "A" ] && ! command -v "$helper" >/dev/null; then
        echo "no $helper yet"
        return 2
    fi
    case "$1" in
        A) "$helper" -Si "$2" >/dev/null 2>&1 ;;
        *) pacman -Si "$2" >/dev/null 2>&1 ;;
    esac && return 0

    if [ "$1" != "A" ] && ! grep -q '^\[extra\]' /etc/pacman.conf && in_arch "$2"; then
        echo "arch [extra], install.sh enables it"
        return 0
    fi
    return 1
}

# pkg_missing NAMES: print the ones not installed (pacman -T knows provides)
pkg_missing() {
    pacman -T "$@" || true
}

# pkg_leftovers NAMES: print the installed ones (with no names: all of them)
pkg_leftovers() {
    pacman -Qq "$@" 2>/dev/null | tr '\n' ' ' || true
}

tweak_pacman() {
    step "pacman and makepkg settings"

    if [ "$(setting pacman yes)" = no ]; then
        info "skipped (shh config)"
        return 0
    fi

    sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
    sudo sed -Ei 's/^#?(ParallelDownloads).*/\1 = 5/' /etc/pacman.conf
    # build AUR packages on all cpu cores
    sudo sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf

    ok "Color, ParallelDownloads = 5, MAKEFLAGS = -j$(nproc)"
}

enable_arch_repos() {
    step "arch repositories"

    sudo pacman -S --needed --noconfirm artix-archlinux-support </dev/null ||
        error "cannot install artix-archlinux-support"

    # arch [extra] goes after the artix repos
    if ! grep -q '^\[extra\]' /etc/pacman.conf; then
        printf '\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n' |
            sudo tee -a /etc/pacman.conf >/dev/null
        info "added [extra] to /etc/pacman.conf"
    fi

    sudo pacman-key --populate archlinux
    sudo pacman -Syu --noconfirm </dev/null || error "system update failed"
    ok "arch [extra] enabled, system updated"
}

install_aur_helper() {
    local helper
    helper=$(setting aur_helper yay)
    step "AUR helper: $helper"

    # the other one, after a switch in shh config
    local other
    for other in yay paru; do
        [ "$other" = "$helper" ] || ! pkg_installed "$other-bin" ||
            info "$other-bin is not needed anymore: sudo pacman -Rs $other-bin"
    done

    if command -v "$helper" >/dev/null; then
        ok "already installed"
        return
    fi

    sudo pacman -S --needed --noconfirm git base-devel </dev/null ||
        error "cannot install git and base-devel"

    # -bin: prebuilt, no need to compile Go (yay) or Rust (paru)
    local build_dir
    build_dir=$(mktemp -d)
    git clone --depth 1 "https://aur.archlinux.org/$helper-bin.git" "$build_dir" ||
        error "cannot download $helper"
    (cd "$build_dir" && makepkg -si --noconfirm </dev/null) ||
        error "cannot build $helper"
    rm -rf "$build_dir"

    ok "$helper installed"
}

# distro_prepare: the package manager and repos, before any package
distro_prepare() {
    tweak_pacman
    enable_arch_repos
    install_aur_helper
}

# vmware_clipboard: the clipboard between VMware and the VM ($hardware: install.sh)
# https://github.com/krisztianfekete/clipway
vmware_clipboard() {
    step "VMware clipboard support"

    if [ "$hardware" != vmware ]; then
        info "not running in VMware, skipping"
        return 0
    fi

    if command -v vmtoolsd >/dev/null 2>&1 && pkg_installed open-vm-tools-clipway; then
        ok "already present"
        return 0
    fi

    local log="$HOME/.local/state/shh/aur-open-vm-tools-clipway.log"
    mkdir -p "$(dirname "$log")"

    info "VMware detected, installing open-vm-tools-clipway (building from AUR)..."
    info "This might take some time so don't panic!"
    if aur_install open-vm-tools-clipway >"$log" 2>&1; then
        ok "open-vm-tools-clipway installed"
    else
        warn "failed to install open-vm-tools-clipway (optional) - see $log"
    fi
}

# ▄▀▀▀ █▀▀▀ █▀▀▄ █   █ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀
#  ▀▀▄ █▀▀  █▀█  ▀▄ ▄▀  █  █    █▀▀   ▀▀▄
# ▀▀▀  ▀▀▀▀ ▀  ▀   ▀   ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# svc_apply ON OFF: enable -> commit -> live install -> start, they also start
# at boot; OFF (turned off in shh config) is disabled and stopped if it is on.
# a one-time "unable to chdir to <svc>-srv" after it is harmless
svc_apply() {
    local svc disabled=''
    for svc in $1; do
        sudo s6 set enable "$svc" || error "cannot enable $svc"
        info "enabled $svc"
    done
    for svc in $2; do
        s6 set status 2>/dev/null | grep -qx "$svc-srv/active" || continue
        sudo s6 set disable "$svc" || error "cannot disable $svc"
        info "disabled $svc"
        disabled="$disabled $svc"
    done

    # -f: after the clock went back (chrony steps it) commit thought the db up to date
    sudo s6 set commit -f || error "s6 set commit failed"
    sudo s6 live install || error "s6 live install failed"
    # live install only swaps the db: services new to it stay down until reboot
    sudo s6 live start $1 || error "cannot start the services"
    [ -z "$disabled" ] || sudo s6 live stop $disabled || warn "cannot stop$disabled"
}

# svc_check SVC (shh doctor): 0 up, 1 down (prints the parts down),
# 2 unknown to s6, 3 can't read the state. Every part must be up (iwd = iwd-srv + iwd-log)
svc_check() {
    local active parts part down=''
    active=$(s6-rc -a list 2>/dev/null) || return 3
    parts=$(s6-rc list "$1" 2>/dev/null) || return 2
    for part in $parts; do
        printf '%s\n' "$active" | grep -qxF "$part" || down="$down $part"
    done
    [ -z "$down" ] || { echo "$down"; return 1; }
}

# svc_ctl start | stop SVC (settings > Services): now, till the reboot.
# s6-rc stops what needs SVC too (dbus: iwd, bluetoothd) and starts what SVC needs
svc_ctl() {
    sudo s6 live "$1" "$2" >/dev/null
}

# svc_list (settings > Svc > All): every service, one per line, "NAME boot" for
# a one-time boot step (stopping one takes down all that needs it).
# NAME-srv + NAME-log are one service; s6rc-*: s6-rc's own
svc_list() {
    s6-rc-db list longruns | sed '/^s6rc-/d; /-log$/d; s/-srv$//' | sort
    s6-rc-db list oneshots | sort | sed 's/$/ boot/'
}

# the vpn service (scripts/vpn): our own s6 service sing-box
vpn_svc=sing-box

# vpn_setup RUN: make the service that runs RUN. Our own services go in
# /etc/s6/adminsv (storelist in /etc/s6-frontend.conf); the log part is like
# the one of dhcpcd-s6. Known to s6 after this, but not started at boot
vpn_setup() {
    sudo sh -s -- "$1" <<'EOF' || error "cannot make the s6 service sing-box"
set -e
srv=/etc/s6/adminsv/sing-box-srv log=/etc/s6/adminsv/sing-box-log
mkdir -p "$srv" "$log"
echo longrun >"$srv/type"
echo sing-box-log >"$srv/producer-for"
printf '%s\n' '#!/bin/execlineb -P' 'fdmove -c 2 1' "exec $1" >"$srv/run"
echo longrun >"$log/type"
echo sing-box-srv >"$log/consumer-for"
echo sing-box >"$log/pipeline-name"
echo 3 >"$log/notification-fd"
cat >"$log/run" <<'LOG'
#!/bin/execlineb -P
ifelse { test -w /var/log } {
	foreground { install -d -o s6log -g s6log /var/log/sing-box }
	s6-setuidgid s6log exec -c s6-log -d3 -b -- n3 s2000000 T /var/log/sing-box
}
foreground { install -d -o s6log -g s6log /run/log/sing-box }
s6-setuidgid s6log exec -c s6-log -d3 -b -- n3 s2000000 T /run/log/sing-box
LOG
chmod 755 "$srv/run" "$log/run"
s6 repository sync
s6 set commit -f
s6 live install
EOF
}

# vpn_ctl start | stop | restart
vpn_ctl() {
    sudo s6 live "$1" sing-box >/dev/null
}

# vpn_boot: is it started at boot?
vpn_boot() {
    s6 set status 2>/dev/null | grep -qx 'sing-box-srv/active'
}

# vpn_boot_set yes | no
vpn_boot_set() {
    local how=disable
    [ "$1" != yes ] || how=enable
    sudo sh -c "s6 set $how sing-box && s6 set commit -f && s6 live install" >/dev/null
}

# ▄▀▀▀ █▀▀▀ ▄▀▀▀ ▄▀▀▀ ▀█▀ ▄▀▀▄ █▄  █
#  ▀▀▄ █▀▀   ▀▀▄  ▀▀▄  █  █  █ █ ▀▄█
# ▀▀▀  ▀▀▀▀ ▀▀▀  ▀▀▀  ▀▀▀  ▀▀  ▀   ▀

# session_setup: XDG_RUNTIME_DIR at login, sway won't start without it (elogind did it before)
session_setup() {
    if ! grep -q pam_rundir /etc/pam.d/system-login; then
        echo 'session    optional   pam_rundir.so' |
            sudo tee -a /etc/pam.d/system-login >/dev/null
    fi
    info "pam_rundir: XDG_RUNTIME_DIR at login"
}

# distro_settings: this distro's lines in shh config -> settings (line, yes_no: shh)
distro_settings() {
    line aur_helper '' 'aur helper' "$(setting aur_helper yay) >"
    yes_no pacman 'Pacman colors and parallel downloads, AUR builds on all cpu cores'
}

# distro_act KEY (shh config): the value picked on this distro's line KEY
# (choose: shh); 1 = not a line of ours
distro_act() {
    case "$1" in
        aur_helper) choose 'aur helper' "yay${tab}yay
paru${tab}paru" ;;
        *)          return 1 ;;
    esac
}

# distro_undo: what install.sh changed in the system (link.sh --uninstall)
distro_undo() {
    echo "  packages   packages/*.csv        sudo pacman -Rs NAME"
    echo "  services   services.txt          sudo s6 set disable NAME, sudo s6 set commit -f, sudo s6 live install"
    echo "  shell      zsh                   chsh -s /bin/bash"
    echo "  groups     seat, audio           sudo gpasswd -d $(id -un) GROUP"
    echo "  /etc       pam.d/system-login (pam_rundir), dhcpcd.conf (denyinterfaces wl*),"
    echo "             iwd/main.conf, modprobe.d/nobeep.conf, pacman.conf, makepkg.conf;"
    echo "             sudoers.d/shh-power (poweroff, reboot, sleep): sudo rm /etc/sudoers.d/shh-power;"
    echo "             older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or pam_rundir sway will not start"
}
