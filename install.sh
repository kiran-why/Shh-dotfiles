#!/bin/sh
# install.sh - set up a fresh Artix (s6) system with these dotfiles
# run as your user, not root:  sh install.sh  (or --check: only check
# package names). Safe to run again. Steps are in MAIN at the bottom

set -eu

### SETTINGS ###

dots_path=$(cd "$(dirname "$0")" && pwd -P)

packages_dir="$dots_path/packages"
packages_file="$packages_dir/common.csv"
services_file="$dots_path/services.txt"
aur_helper="yay"

# temporary passwordless sudo, removed on exit (see enable_nopasswd)
sudoers_tmp="/etc/sudoers.d/dotfiles-temp"

[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

### HELPERS ###

# read_list FILE: lines that are not empty and not comments
read_list() {
    grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true
}

package_lines() {
    read_list "$packages_file"
}

is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

### STEPS ###

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

    ping -c 1 -W 5 artixlinux.org >/dev/null 2>&1 ||
        error "no internet connection"

    ok "artix + s6, internet, sudo"
}

# AUR builds would ask for the password again and again (trick from LARBS)
enable_nopasswd() {
    step "temporary passwordless sudo"
    sudo -v || error "sudo failed"

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

# --check: does every package exist? installs nothing
check_packages() {
    step "checking package names"

    local tag pkg desc missing=0
    while IFS=, read -r tag pkg desc; do
        if [ "$tag" = "A" ] && ! command -v "$aur_helper" >/dev/null; then
            warn "skipped (no $aur_helper yet): $pkg"
            continue
        fi
        case "$tag" in
            A) "$aur_helper" -Si "$pkg" >/dev/null 2>&1 ;;
            *) pacman -Si "$pkg" >/dev/null 2>&1 ;;
        esac && ok "$pkg" || { warn "not found: $pkg"; missing=$((missing + 1)); }
    done <<EOF
$(package_lines)
EOF

    [ "$missing" -eq 0 ] || error "$missing package(s) not found"
    ok "all packages exist"
}

# s6: enable (draft) -> commit -> live install; services start at boot.
# a one-time "unable to chdir to <svc>-srv" right after it is harmless
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
    printf '[General]\nEnableNetworkConfiguration=true\n\n[Network]\nNameResolvingService=resolvconf\n' |
        sudo tee /etc/iwd/main.conf >/dev/null
    info "iwd: built-in DHCP, DNS via resolvconf"

    # XDG_RUNTIME_DIR at login, sway won't start without it (elogind did it before)
    if ! grep -q pam_rundir /etc/pam.d/system-login; then
        echo 'session    optional   pam_rundir.so' |
            sudo tee -a /etc/pam.d/system-login >/dev/null
    fi
    info "pam_rundir: XDG_RUNTIME_DIR at login"

    echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf >/dev/null
    info "pc speaker disabled"

    ok "done"
}

link_dotfiles() {
    step "symlinks"
    DOTS_NO_LOGO=1 sh "$dots_path/link.sh"
}

usage() {
    echo "usage: $0 [--check] [-h | --help]"
    echo "  --check     only check that all packages exist, install nothing"
    echo "  -h, --help  show this help"
}

### MAIN ###

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
install_packages
enable_services
configure_system
link_dotfiles

echo
ok "all done - reboot and log in on the TTY"
