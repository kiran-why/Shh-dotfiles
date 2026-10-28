#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# ▀ ▄▄▄   ▄▄▄ ▄█▄   ▄▄▄  █ █    ▄▄▄ █▄▄  
# █ █  █ ▀▀▄▄  █   █  █  █ █   ▀▀▄▄ █  █ 
# ▀ ▀  ▀ ▀▀▀    ▀▀  ▀▀▀▀ ▀ ▀ ▀ ▀▀▀  ▀  ▀                                       
# Set up a fresh Artix (s6) system with these dotfiles.
# Run as your user: sh install.sh. Use --check to check package names only.

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

dots_path=$(cd "$(dirname "$0")" && pwd -P)

packages_dir="$dots_path/packages"
packages_file="$packages_dir/common.csv"
services_file="$dots_path/services.txt"
aur_helper="yay"

# Temporary sudo rule, removed when the script exits. (see enable_nopasswd)
sudoers_tmp="/etc/sudoers.d/dotfiles-temp"

# Used to name backup files. same as link.sh
stamp=$(date +%Y%m%d-%H%M%S)

[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

# █  █ █▀▀▀ █    █▀▀▄ █▀▀▀ █▀▀▄ ▄▀▀▀ 
# █▀▀█ █▀▀  █    █▀▀  █▀▀  █▀█   ▀▀▄ 
# ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀    ▀▀▀▀ ▀  ▀ ▀▀▀  

read_list() {
    grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true
}

package_lines() {
    read_list "$packages_file"
}

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

# Back up the old file if its contents differ.
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

    # https, not ping: ICMP is often blocked, pacman needs https anyway
    # (curl comes with pacman)
    curl -s -o /dev/null -m 10 https://artixlinux.org ||
        error "no internet connection"

    ok "artix + s6, internet, sudo"
}

# in_arch PKG: is PKG in Arch [extra]? asks archlinux.org, because before
# enable_arch_repos pacman does not know that repo
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
$(package_lines)
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

    if command -v "$aur_helper" >/dev/null; then
        ok "already installed"
        return
    fi

    sudo pacman -S --needed --noconfirm git base-devel </dev/null ||
        error "cannot install git and base-devel"

    # yay-bin: prebuilt, no need to compile Go
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

    local tag pkg desc
    package_lines | while IFS=, read -r tag pkg desc; do
        if is_installed "$pkg"; then
            ok "$pkg"
            continue
        fi

        info "$pkg - $desc"
        # </dev/null: pacman must not read the rest of our list
        case "$tag" in
            A) "$aur_helper" -S --needed --noconfirm "$pkg" </dev/null ;;
            *) sudo pacman -S --needed --noconfirm "$pkg" </dev/null ;;
        esac || error "cannot install $pkg"
    done
}

# █   █ ▀█▀ █▀▀▄ ▀▀█▀▀ █  █ ▄▀▀▄ █        █▄ ▄█ ▄▀▀▄ ▄▀▀▀ █  █ ▀█▀ █▄  █ █▀▀▀ ▄▀▀▀ 
# ▀▄ ▄▀  █  █▀█    █   █  █ █▀▀█ █        █ ▀ █ █▀▀█ █    █▀▀█  █  █ ▀▄█ █▀▀   ▀▀▄ 
#   ▀   ▀▀▀ ▀  ▀   ▀    ▀▀  ▀  ▀ ▀▀▀▀     ▀   ▀ ▀  ▀  ▀▀▀ ▀  ▀ ▀▀▀ ▀   ▀ ▀▀▀▀ ▀▀▀  

# check if running inside vmware
is_vmware() {
    local f val
    for f in /sys/devices/virtual/dmi/id/product_name /sys/devices/virtual/dmi/id/sys_vendor; do
        [ -r "$f" ] || continue
        val="$(cat "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        case "$val" in
            *vmware*) return 0 ;;
        esac
    done
    return 1
}

# auto-install vmware clipboard tools if in vmware
# https://github.com/krisztianfekete/clipway
vmware_clipboard() {
    step "VMware clipboard support"

    if ! is_vmware; then
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
    if "$aur_helper" -S --needed --noconfirm open-vm-tools-clipway </dev/null >"$log" 2>&1; then
        ok "open-vm-tools-clipway installed"
    else
        warn "failed to install open-vm-tools-clipway (optional) - see $log"
    fi
}

# ▄▀▀▀ ▄▀▀▄ █▄  █ █▀▀▀ ▀█▀ ▄▀▀▀ █  █ █▀▀▄ ▄▀▀▄ ▀▀█▀▀ ▀█▀ ▄▀▀▄ █▄  █ 
# █    █  █ █ ▀▄█ █▀▀   █  █ ▀█ █  █ █▀█  █▀▀█   █    █  █  █ █ ▀▄█ 
#  ▀▀▀  ▀▀  ▀   ▀ ▀    ▀▀▀  ▀▀▀  ▀▀  ▀  ▀ ▀  ▀   ▀   ▀▀▀  ▀▀  ▀   ▀ 

# Enable the services listed in services.txt.
enable_services() {
    step "s6 services from services.txt"

    local svc
    for svc in $(read_list "$services_file"); do
        sudo s6 set enable "$svc" || error "cannot enable $svc"
        info "enabled $svc"
    done

    sudo s6 set commit || error "s6 set commit failed"
    sudo s6 live install || error "s6 live install failed"

    # seat: screen and input for sway; audio: the sound card (no elogind)
    sudo usermod -aG seat,audio "$USER"
    ok "added $USER to groups seat, audio (relogin to apply)"
}

configure_system() {
    step "system settings"

    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
        sudo chsh -s "$(command -v zsh)" "$USER"
        info "login shell: zsh"
    fi

    # iwd gets IP addresses itself, DNS goes to openresolv
    sudo mkdir -p /etc/iwd
    write_root /etc/iwd/main.conf \
        "$(printf '[General]\nEnableNetworkConfiguration=true\n\n[Network]\nNameResolvingService=resolvconf')"
    info "iwd: built-in DHCP, DNS via resolvconf"

    # XDG_RUNTIME_DIR at login, sway won't start without it (elogind did it before)
    if ! grep -q pam_rundir /etc/pam.d/system-login; then
        echo 'session    optional   pam_rundir.so' |
            sudo tee -a /etc/pam.d/system-login >/dev/null
    fi
    info "pam_rundir: XDG_RUNTIME_DIR at login"

    write_root /etc/modprobe.d/nobeep.conf "blacklist pcspkr"
    info "pc speaker disabled"

    ok "done"
}

link_dotfiles() {
    step "symlinks"
    DOTS_NO_LOGO=1 sh "$dots_path/link.sh"
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
enable_nopasswd
tweak_pacman
enable_arch_repos
install_aur_helper
vmware_clipboard
install_packages
enable_services
configure_system
link_dotfiles

echo
ok "all done - reboot and log in on the TTY"
