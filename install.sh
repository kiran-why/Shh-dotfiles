#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# ▀ ▄▄▄   ▄▄▄ ▄█▄   ▄▄▄  █ █    ▄▄▄ █▄▄  
# █ █  █ ▀▀▄▄  █   █  █  █ █   ▀▀▄▄ █  █ 
# ▀ ▀  ▀ ▀▀▀    ▀▀  ▀▀▀▀ ▀ ▀ ▀ ▀▀▀  ▀  ▀                                       
# Set up a fresh Artix (s6) system with these dotfiles.
# Run as your user: sh install.sh. Use --check to check package names only.
# Safe to run again. Steps are in MAIN at the bottom.

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

dots_path=$(cd "$(dirname "$0")" && pwd -P)

packages_dir="$dots_path/packages"
packages_file="$packages_dir/common.csv"
services_file="$dots_path/services.txt"
# the parts shh config can turn off
components_file="$dots_path/components.txt"

# temporary sudo rule (enable_nopasswd)
sudoers_tmp="/etc/sudoers.d/dotfiles-temp"

# for backup names, like link.sh
stamp=$(date +%Y%m%d-%H%M%S)

[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

# yay or paru (shh config)
aur_helper=$(setting aur_helper yay)

# a VM type or the graphics cards, one per line (scripts/hardware)
hardware=$(sh "$dots_path/scripts/hardware" 2>/dev/null || true)

# █  █ █▀▀▀ █    █▀▀▄ █▀▀▀ █▀▀▄ ▄▀▀▀ 
# █▀▀█ █▀▀  █    █▀▀  █▀▀  █▀█   ▀▀▄ 
# ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀    ▀▀▀▀ ▀  ▀ ▀▀▀  

# common.csv + packages/CARD.csv for every graphics card found
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

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

# aur_install PKG: paru shows every PKGBUILD for review unless told not to.
# </dev/null: it must not read the rest of a list we loop over
aur_install() {
    local review=''
    [ "$aur_helper" != paru ] || review=--skipreview
    "$aur_helper" -S --needed --noconfirm $review "$1" </dev/null
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

    grep -q '^ID=artix' /etc/os-release 2>/dev/null ||
        error "this is not Artix Linux"

    command -v s6-rc >/dev/null || error "s6 is not the init system here"
    command -v sudo  >/dev/null || error "sudo is not installed"
    [ -f "$packages_file" ]     || error "not found: $packages_file"
    [ -f "$services_file" ]     || error "not found: $services_file"

    # seatd-s6 and elogind-s6 conflict; pacman --noconfirm can't swap them
    if is_installed elogind-s6; then
        warn "elogind-s6 is installed, this setup uses seatd instead"
        info "swap it: sudo pacman -S seatd-s6  (answer y to remove elogind-s6)"
        error "replace elogind-s6 with seatd-s6, then run install.sh again"
    fi

    # https, not ping: ICMP is often blocked
    curl -s -o /dev/null -m 20 https://artixlinux.org ||
        error "no internet connection"

    ok "artix + s6, internet, sudo"
}

# the menu on the first run; later shh config changes the choices
choose_parts() {
    step "what to install"

    if [ -f "$shh_config" ]; then
        info "choices: $shh_config (change: shh config)"
    else
        SHH_INSTALL=1 sh "$dots_path/scripts/shh" config || error "shh config failed"
    fi
    aur_helper=$(setting aur_helper yay)
    ok "done"
}

# in_arch PKG: is PKG in Arch [extra]? pacman can't tell before enable_arch_repos
in_arch() {
    curl -s -m 10 "https://archlinux.org/packages/search/json/?name=$1&repo=Extra" |
        grep -q '"pkgname"'
}

# --check: does every package exist? installs nothing
check_packages() {
    step "checking package names"

    local tag pkg desc missing=0 arch_on=1
    grep -q '^\[extra\]' /etc/pacman.conf || arch_on=0

    while IFS=, read -r tag pkg desc; do
        if [ "$tag" = "A" ] && ! command -v "$aur_helper" >/dev/null; then
            warn "skipped (no $aur_helper yet): $pkg"
            continue
        fi
        case "$tag" in
            A) "$aur_helper" -Si "$pkg" >/dev/null 2>&1 ;;
            *) pacman -Si "$pkg" >/dev/null 2>&1 ;;
        esac && { ok "$pkg"; continue; }

        if [ "$tag" != "A" ] && [ "$arch_on" = 0 ] && in_arch "$pkg"; then
            ok "$pkg (arch [extra], install.sh enables it)"
        else
            warn "not found: $pkg"
            missing=$((missing + 1))
        fi
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
    step "AUR helper: $aur_helper"

    # the other one, after a switch in shh config
    local other
    for other in yay paru; do
        [ "$other" = "$aur_helper" ] || ! is_installed "$other-bin" ||
            info "$other-bin is not needed anymore: sudo pacman -Rs $other-bin"
    done

    if command -v "$aur_helper" >/dev/null; then
        ok "already installed"
        return
    fi

    sudo pacman -S --needed --noconfirm git base-devel </dev/null ||
        error "cannot install git and base-devel"

    # -bin: prebuilt, no need to compile Go (yay) or Rust (paru)
    local build_dir
    build_dir=$(mktemp -d)
    git clone --depth 1 "https://aur.archlinux.org/$aur_helper-bin.git" "$build_dir" ||
        error "cannot download $aur_helper"
    (cd "$build_dir" && makepkg -si --noconfirm </dev/null) ||
        error "cannot build $aur_helper"
    rm -rf "$build_dir"

    ok "$aur_helper installed"
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
        if is_installed "$pkg"; then
            ok "$pkg"
            continue
        fi

        info "$pkg - $desc"
        # </dev/null: pacman must not read the rest of our list
        case "$tag" in
            A) aur_install "$pkg" ;;
            *) sudo pacman -S --needed --noconfirm "$pkg" </dev/null ;;
        esac || error "cannot install $pkg"
    done
}

# █   █ ▀█▀ █▀▀▄ ▀▀█▀▀ █  █ ▄▀▀▄ █        █▄ ▄█ ▄▀▀▄ ▄▀▀▀ █  █ ▀█▀ █▄  █ █▀▀▀ ▄▀▀▀ 
# ▀▄ ▄▀  █  █▀█    █   █  █ █▀▀█ █        █ ▀ █ █▀▀█ █    █▀▀█  █  █ ▀▄█ █▀▀   ▀▀▄ 
#   ▀   ▀▀▀ ▀  ▀   ▀    ▀▀  ▀  ▀ ▀▀▀▀     ▀   ▀ ▀  ▀  ▀▀▀ ▀  ▀ ▀▀▀ ▀   ▀ ▀▀▀▀ ▀▀▀  

# auto-install vmware clipboard tools if in vmware (VM check: scripts/hardware)
# https://github.com/krisztianfekete/clipway
vmware_clipboard() {
    step "VMware clipboard support"

    if [ "$hardware" != vmware ]; then
        info "not running in VMware, skipping"
        return 0
    fi

    if command -v vmtoolsd >/dev/null 2>&1 && is_installed open-vm-tools-clipway; then
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

# ▄▀▀▀ ▄▀▀▄ █▄  █ █▀▀▀ ▀█▀ ▄▀▀▀ █  █ █▀▀▄ ▄▀▀▄ ▀▀█▀▀ ▀█▀ ▄▀▀▄ █▄  █ 
# █    █  █ █ ▀▄█ █▀▀   █  █ ▀█ █  █ █▀█  █▀▀█   █    █  █  █ █ ▀▄█ 
#  ▀▀▀  ▀▀  ▀   ▀ ▀    ▀▀▀  ▀▀▀  ▀▀  ▀  ▀ ▀  ▀   ▀   ▀▀▀  ▀▀  ▀   ▀ 

# the drivers come from packages/CARD.csv; here only the settings they need
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

    # an old install guide started dhcpcd from rc.local; the s6 service does it now
    if grep -q '^[[:space:]]*dhcpcd' /etc/s6/rc.local 2>/dev/null; then
        warn "/etc/s6/rc.local starts dhcpcd too, comment that line out"
    fi

    ok "done"
}

# services.txt: enable -> commit -> live install -> start, they also start at boot.
# a one-time "unable to chdir to <svc>-srv" after it is harmless
enable_services() {
    step "s6 services from services.txt"

    local svc services off_svcs disabled=''
    off_svcs=$(off_items "$components_file" 4)
    services=$(read_list "$services_file" | without "$off_svcs")
    for svc in $services; do
        sudo s6 set enable "$svc" || error "cannot enable $svc"
        info "enabled $svc"
    done
    # a part turned off in shh config: its service too (only if it is on now)
    for svc in $off_svcs; do
        s6 set status 2>/dev/null | grep -qx "$svc-srv/active" || continue
        sudo s6 set disable "$svc" || error "cannot disable $svc"
        info "disabled $svc"
        disabled="$disabled $svc"
    done

    sudo s6 set commit || error "s6 set commit failed"
    sudo s6 live install || error "s6 live install failed"
    # live install only swaps the db: services new to it stay down until reboot
    sudo s6 live start $services || error "cannot start the services"
    [ -z "$disabled" ] || sudo s6 live stop $disabled || warn "cannot stop$disabled"

    # seat: screen and input for sway; audio: the sound card (no elogind);
    # vboxusers: usb in virtualbox (shh config: apps)
    local groups=seat,audio
    ! part_on virtualbox apps no || groups="$groups,vboxusers"
    sudo usermod -aG "$groups" "$USER"
    ok "added $USER to groups $groups (relogin to apply)"
}

configure_system() {
    step "system settings"

    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
        sudo chsh -s "$(command -v zsh)" "$USER"
        info "login shell: zsh"
    fi

    # XDG_RUNTIME_DIR at login, sway won't start without it (elogind did it before)
    if ! grep -q pam_rundir /etc/pam.d/system-login; then
        echo 'session    optional   pam_rundir.so' |
            sudo tee -a /etc/pam.d/system-login >/dev/null
    fi
    info "pam_rundir: XDG_RUNTIME_DIR at login"

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
    DOTS_NO_LOGO=1 sh "$dots_path/link.sh" ${mode:+"--$mode"}
}

# what parts turned off in shh config left behind; removing is up to you
leftovers() {
    local pkgs
    pkgs=$(off_items "$components_file" 2)
    # pacman -Qq prints the installed ones (with no names: all of them)
    [ -z "$pkgs" ] || pkgs=$(pacman -Qq $pkgs 2>/dev/null | tr '\n' ' ' || true)
    [ -z "$pkgs" ] || warn "not needed anymore: sudo pacman -Rs $pkgs"

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
tweak_pacman
enable_arch_repos
install_aur_helper
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
