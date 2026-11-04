#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# ▀ ▄▄▄   ▄▄▄ ▄█▄   ▄▄▄  █ █    ▄▄▄ █▄▄  
# █ █  █ ▀▀▄▄  █   █  █  █ █   ▀▀▄▄ █  █ 
# ▀ ▀  ▀ ▀▀▀    ▀▀  ▀▀▀▀ ▀ ▀ ▀ ▀▀▀  ▀  ▀                                       
# Set up a fresh system with these dotfiles; what differs per distro is in system/DISTRO/.
# Run as your user: sh install.sh. Use --check to check package names only.
# Safe to run again. Steps are in MAIN at the bottom.

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

dots_path=$(cd "$(dirname "$0")" && pwd -P)

# temporary sudo rule (enable_nopasswd)
sudoers_tmp="/etc/sudoers.d/dotfiles-temp"

# for backup names, like link.sh
stamp=$(date +%Y%m%d-%H%M%S)

[ -f "$dots_path/lib/lib.sh" ] || { echo "lib/lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib/lib.sh"

# the lists and steps of this distro ($distro: lib.sh)
system_dir="$dots_path/system/$distro"
packages_dir="$system_dir/packages"
packages_file="$packages_dir/common.csv"
services_file="$system_dir/services.txt"
# the parts shh config can turn off
components_file="$dots_path/components/${distro}_components.txt"
# no distro.sh: check_system stops with "not supported"
[ ! -f "$system_dir/distro.sh" ] || . "$system_dir/distro.sh"

# a VM type or the graphics cards, one per line (scripts/hardware)
hardware=$(sh "$dots_path/scripts/hardware" 2>/dev/null || true)

# █  █ █▀▀▀ █    █▀▀▄ █▀▀▀ █▀▀▄ ▄▀▀▀ 
# █▀▀█ █▀▀  █    █▀▀  █▀▀  █▀█   ▀▀▄ 
# ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀    ▀▀▀▀ ▀  ▀ ▀▀▀  

# common.csv + system/packages/CARD.csv for every graphics card found
package_lines() {
    local hw
    read_list "$packages_file"
    for hw in $hardware; do
        [ ! -f "$packages_dir/$hw.csv" ] || read_list "$packages_dir/$hw.csv"
    done
}

# every list, not only this machine's: --check finds typos anywhere
all_package_lines() {
    local list
    for list in "$packages_dir"/*.csv; do
        read_list "$list"
    done
}

# write_root FILE TEXT: put TEXT into FILE as root. An old FILE with other
# text is renamed to FILE.bak-DATE first; the same text is left alone
write_root() {
    local file="$1"
    local text="$2"

    if sudo test -e "$file"; then
        [ "$(sudo cat "$file")" != "$text" ] || return 0
        sudo mv "$file" "$file.bak-$stamp" || error "cannot back up $file"
        msg "$red" "$sym_bak" "$file -> $file.bak-$stamp"
    fi

    printf '%s\n' "$text" | sudo tee "$file" >/dev/null || error "cannot write $file"
}

# ▄▀▀▀ █  █ █▀▀▀ ▄▀▀▀ █ ▄▀ ▄▀▀▀ 
# █    █▀▀█ █▀▀  █    █▀▄   ▀▀▄ 
#  ▀▀▀ ▀  ▀ ▀▀▀▀  ▀▀▀ ▀  ▀ ▀▀▀  

check_system() {
    step "checking the system"

    [ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

    [ -f "$system_dir/distro.sh" ] ||
        error "not supported: ${distro:-unknown distro} (no system/${distro:-DISTRO}/distro.sh)"

    distro_check
    command -v sudo  >/dev/null || error "sudo is not installed"
    [ -f "$packages_file" ]     || error "not found: $packages_file"
    [ -f "$services_file" ]     || error "not found: $services_file"
    [ -f "$components_file" ]   || error "not found: $components_file"

    # online_sites: distro.sh. No curl on a fresh system (Void base):
    # skipped, the first download of the package manager fails without internet
    local site online=0
    if ! command -v curl >/dev/null; then
        info "no curl yet (it comes with the packages), internet not checked"
        online=skipped
    fi
    for site in $online_sites; do
        [ "$online" = 0 ] || break
        ! curl -s -o /dev/null -m 10 "$site" || online=1
    done
    [ "$online" != 0 ] || error "no internet connection"

    if [ "$online" = 1 ]; then ok "$distro, internet, sudo"; else ok "$distro, sudo"; fi
}

# the menu on the first run; later shh config changes the choices
choose_parts() {
    step "what to install"

    if [ -f "$shh_config" ]; then
        info "choices: $shh_config (change: shh config)"
    else
        SHH_INSTALL=1 sh "$dots_path/scripts/shh" config || error "shh config failed"
    fi
    ok "done"
}

# --check: does every package exist? installs nothing
check_packages() {
    step "checking package names"

    local tag pkg desc note rc missing=0

    while IFS=, read -r tag pkg desc; do
        rc=0
        note=$(pkg_exists "$tag" "$pkg") || rc=$?
        case "$rc" in
            0) ok "$pkg${note:+ ($note)}" ;;
            2) warn "skipped ($note): $pkg" ;;
            *) warn "not found: $pkg"
               missing=$((missing + 1)) ;;
        esac
    done <<EOF
$(all_package_lines)
EOF

    [ "$missing" -eq 0 ] || error "$missing package(s) not found"
    ok "all packages exist"
}

# ▀█▀ █▄  █ ▄▀▀▀ ▀▀█▀▀ ▄▀▀▄ █    █    
#  █  █ ▀▄█  ▀▀▄   █   █▀▀█ █    █    
# ▀▀▀ ▀   ▀ ▀▀▀    ▀   ▀  ▀ ▀▀▀▀ ▀▀▀▀ 

# AUR builds would ask for the password again and again (trick from LARBS)
enable_nopasswd() {
    step "temporary passwordless sudo"
    sudo -v || error "sudo failed"

    # left over when a run was killed hard (kill -9, power off)
    if sudo test -e "$sudoers_tmp"; then
        warn "found a leftover $sudoers_tmp from an interrupted run, removing it"
        sudo rm -f "$sudoers_tmp"
    fi

    # the rule is removed on any exit, Ctrl+C too
    trap 'sudo rm -f "$sudoers_tmp"' EXIT
    trap 'exit 1' INT TERM

    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_tmp" >/dev/null
    sudo chmod 440 "$sudoers_tmp"
    ok "removed automatically when the script ends"
}

install_packages() {
    step "packages"

    local tag pkg desc off_pkgs
    off_pkgs=$(off_items "$components_file" 2)
    package_lines | while IFS=, read -r tag pkg desc; do
        if printf '%s\n' "$off_pkgs" | grep -qxF -- "$pkg"; then
            info "off: $pkg"
            continue
        fi
        if pkg_installed "$pkg"; then
            ok "$pkg"
            continue
        fi

        info "$pkg - $desc"
        pkg_install "$tag" "$pkg" || error "cannot install $pkg"
    done
}

# ▄▀▀▀ ▄▀▀▄ █▄  █ █▀▀▀ ▀█▀ ▄▀▀▀ █  █ █▀▀▄ ▄▀▀▄ ▀▀█▀▀ ▀█▀ ▄▀▀▄ █▄  █ 
# █    █  █ █ ▀▄█ █▀▀   █  █ ▀█ █  █ █▀█  █▀▀█   █    █  █  █ █ ▀▄█ 
#  ▀▀▀  ▀▀  ▀   ▀ ▀    ▀▀▀  ▀▀▀  ▀▀  ▀  ▀ ▀  ▀   ▀   ▀▀▀  ▀▀  ▀   ▀ 

# the drivers come from system/DISTRO/packages/CARD.csv; here only the settings they need
configure_gpu() {
    step "graphics"

    if [ -z "$hardware" ]; then
        warn "no graphics card found, only mesa is installed"
        return 0
    fi

    local hw
    for hw in $hardware; do
        case "$hw" in
            nvidia|nvidia-580xx)
                # sway needs kernel modesetting; the 580xx driver has it off by default
                write_root /etc/modprobe.d/nvidia-modeset.conf "options nvidia_drm modeset=1"
                info "$hw: kernel modesetting on (after reboot)" ;;
            nvidia-legacy)
                warn "this NVIDIA card is too old for the NVIDIA driver, nouveau (mesa) runs it" ;;
            *)
                info "$hw: nothing to set" ;;
        esac
    done

    ok "done"
}

# before enable_services: it starts iwd and dhcpcd right away
configure_network() {
    step "network settings"

    # iwd gets IP addresses itself, DNS goes to openresolv
    sudo mkdir -p /etc/iwd
    write_root /etc/iwd/main.conf \
        "$(printf '[General]\nEnableNetworkConfiguration=true\n\n[Network]\nNameResolvingService=resolvconf')"
    info "iwd: built-in DHCP, DNS via resolvconf"

    # dhcpcd: wired only, wifi is iwd's (wl* = wlan0, wlp1s0 ...)
    if ! grep -q '^denyinterfaces wl\*$' /etc/dhcpcd.conf 2>/dev/null; then
        echo 'denyinterfaces wl*' | sudo tee -a /etc/dhcpcd.conf >/dev/null ||
            error "cannot write /etc/dhcpcd.conf"
    fi
    # the old rule from earlier installs, wl* above covers it
    if grep -q '^denyinterfaces wlan\*$' /etc/dhcpcd.conf 2>/dev/null; then
        sudo sed -i 's/^denyinterfaces wlan\*$/#&/' /etc/dhcpcd.conf ||
            error "cannot edit /etc/dhcpcd.conf"
        info "dhcpcd: commented out the old rule denyinterfaces wlan*"
    fi
    info "dhcpcd: wired only"

    # DNS (shh config -> settings -> dns): dhcp = the stock file, the network's servers
    local dns conf
    dns=$(setting dns dhcp)
    conf='# Configuration for resolvconf(8)
# See resolvconf.conf(5) for details

resolv_conf=/etc/resolv.conf
# If you run a local name server, you should uncomment the below line and
# configure your subscribers configuration files below.
#name_servers=127.0.0.1'
    if [ "$dns" != dhcp ]; then
        # root sources this file as sh: addresses only
        case "$dns" in
            *[!0-9A-Fa-f.:,]*) error "dns: not IP addresses: $dns (shh config)" ;;
        esac
        # only these: musl asks every nameserver at once and takes the first answer
        conf="$conf

# shh config: dns
resolv_conf_passthrough=NULL
name_servers=\"$(printf '%s' "$dns" | tr ',' ' ')\""
    fi
    # rewritten only on a change, so shh update leaves resolv.conf alone
    if [ "$(cat /etc/resolvconf.conf 2>/dev/null)" != "$conf" ]; then
        write_root /etc/resolvconf.conf "$conf"
        sudo resolvconf -u || warn "resolvconf -u failed"
    fi
    info "dns: $dns"

    ok "done"
}

# services.txt: on and started, they also start at boot; a part turned off
# in shh config: its service too (svc_apply: distro.sh)
enable_services() {
    step "services from services.txt"

    local services off_svcs
    off_svcs=$(off_items "$components_file" 4)
    services=$(read_list "$services_file" | without "$off_svcs")
    svc_apply "$services" "$off_svcs"

    # sing-box (shh config: misc): our own service (vpn_setup: distro.sh); started from the vpn menu
    if part_on sing-box misc; then
        sh "$dots_path/scripts/vpn" setup || error "vpn setup failed"
    fi

    # seat_groups: distro.sh
    sudo usermod -aG "$seat_groups" "$USER"
    ok "added $USER to groups $seat_groups (relogin to apply)"
}

configure_system() {
    step "system settings"

    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
        sudo chsh -s "$(command -v zsh)" "$USER"
        info "login shell: zsh"
    fi

    session_setup

    if [ "$(setting nobeep yes)" = yes ]; then
        write_root /etc/modprobe.d/nobeep.conf "blacklist pcspkr"
        info "pc speaker disabled"
    fi

    ok "done"
}

link_dotfiles() {
    step "dotfiles"
    # no mode in shh config: link.sh keeps what is installed
    local mode
    mode=$(setting mode '')
    DOTS_NO_LOGO=1 sh "$dots_path/lib/link.sh" ${mode:+"--$mode"}
}

# what parts turned off in shh config left behind; removed only on "y"
leftovers() {
    local pkgs answer
    pkgs=$(off_items "$components_file" 2)
    # with no names pkg_leftovers prints every installed package
    [ -z "$pkgs" ] || pkgs=$(pkg_leftovers $pkgs)
    if [ -n "$pkgs" ]; then
        warn "not needed anymore: $pkg_remove $pkgs"
        # no terminal (run by a script): the hint only
        if [ -t 0 ]; then
            printf '  remove them now? [y/N] '
            read -r answer || answer=
            # the package manager lists what goes (with deps) and asks again
            case "$answer" in
                y|Y) $pkg_remove $pkgs || warn "not removed" ;;
            esac
        fi
    fi

    if [ "$(setting nobeep yes)" = no ] && [ -e /etc/modprobe.d/nobeep.conf ]; then
        warn "the pc speaker is still off: sudo rm /etc/modprobe.d/nobeep.conf"
    fi
}

# █▄ ▄█ ▄▀▀▄ ▀█▀ █▄  █ 
# █ ▀ █ █▀▀█  █  █ ▀▄█ 
# ▀   ▀ ▀  ▀ ▀▀▀ ▀   ▀ 

usage() {
    echo "usage: $0 [--check] [-h | --help]"
    echo "  --check     only check that all packages exist, install nothing"
    echo "  -h, --help  show this help"
}

check_only=0

while [ $# -gt 0 ]; do
    case "$1" in
        --check)   check_only=1 ;;
        -h|--help) usage; exit 0 ;;
        *)         usage >&2; error "unknown option: $1" ;;
    esac
    shift
done

logo

if [ "$check_only" = 1 ]; then
    check_system
    check_packages
    exit 0
fi

check_system
choose_parts
enable_nopasswd
distro_prepare
# vmware_clipboard: distro.sh
vmware_clipboard
install_packages
configure_gpu
configure_network
enable_services
configure_system
link_dotfiles
leftovers

echo
ok "all done - reboot and log in on the TTY"
