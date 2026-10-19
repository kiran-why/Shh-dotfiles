#!/bin/sh
# install.sh - set up a fresh Artix (s6) system with these dotfiles
#
# run as your normal user right after the base install, NOT as root:
#   sh install.sh               install everything (asks which desktop you want)
#   sh install.sh --wm sway     skip the question: sway or driftwm
#   sh install.sh --check       only check that every package exists
#
# what it does, in order:
#   0. asks which desktop you prefer: 1) sway  2) driftwm
#   1. sanity checks (artix, s6, internet, sudo)
#   2. pacman tweaks + arch repos (via artix-archlinux-support)
#   3. AUR helper (yay)
#   4. packages: packages/common.csv + packages/<desktop>.csv
#   5. s6 services from services.txt, user groups
#   6. system tweaks: zsh as login shell, iwd config, no pc speaker beep
#   7. symlinks via link.sh

# stop on errors and on undefined variables
set -eu

### SETTINGS ###

# absolute path to the dotfiles repo (the directory this script lives in)
dots_path=$(cd "$(dirname "$0")" && pwd -P)

# package lists live in their own directory
packages_dir="$dots_path/packages"
packages_file="$packages_dir/common.csv"
services_file="$dots_path/services.txt"
aur_helper="yay"

# chosen desktop: sway or driftwm (empty = not chosen yet, ask_wm fills it)
wm=""
# where the choice is remembered, so the session start can read it later
wm_file="$HOME/.local/state/shh/wm"

# temporary sudoers rule, removed on exit (see enable_nopasswd)
sudoers_tmp="/etc/sudoers.d/dotfiles-temp"

### SHARED HELPERS ###

# colors, messages (step, info, ok, warn, error) and the logo live in lib.sh
[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

### HELPERS ###

# read_list FILE: print non-empty lines that are not comments
read_list() {
    grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true
}

# package_lines: every package line to handle, common ones + chosen desktop.
# with no choice made (--check) both desktops are listed
package_lines() {
    read_list "$packages_file"
    case "$wm" in
        sway)    read_list "$packages_dir/sway.csv" ;;
        driftwm) read_list "$packages_dir/driftwm.csv" ;;
        *)       read_list "$packages_dir/sway.csv"
                 read_list "$packages_dir/driftwm.csv" ;;
    esac
}

# is_installed PKG: true if the package is already installed
is_installed() {
    pacman -Qq "$1" >/dev/null 2>&1
}

### STEPS ###

# ask which desktop to install; skipped if --wm was given
ask_wm() {
    [ -z "$wm" ] || return 0

    step "which desktop do you prefer?"
    echo "  1) sway     - tiling windows and workspaces"
    echo "  2) driftwm  - one infinite canvas, no workspaces (experimental)"
    echo

    local answer
    while [ -z "$wm" ]; do
        printf 'your choice [1/2]: '
        # no input at all (Ctrl+D) must not loop forever
        read -r answer || error "no answer"
        case "$answer" in
            1|sway)    wm=sway ;;
            2|driftwm) wm=driftwm ;;
            *)         warn "type 1 or 2" ;;
        esac
    done
    ok "desktop: $wm"
}

check_system() {
    step "checking the system"

    # as root, $HOME is /root and everything would go to the wrong user
    [ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

    grep -q '^ID=artix' /etc/os-release 2>/dev/null ||
        error "this is not Artix Linux"

    command -v s6-rc >/dev/null || error "s6 is not the init system here"
    command -v sudo  >/dev/null || error "sudo is not installed"
    [ -f "$packages_file" ]     || error "not found: $packages_file"
    [ -f "$services_file" ]     || error "not found: $services_file"

    ping -c 1 -W 5 artixlinux.org >/dev/null 2>&1 ||
        error "no internet connection"

    ok "artix + s6, internet, sudo"
}

# AUR builds take long and sudo would ask for the password again and again.
# Allow this user passwordless sudo while the script runs (same trick as LARBS),
# and remove the rule on any exit: normal end, error or Ctrl+C.
enable_nopasswd() {
    step "temporary passwordless sudo"
    sudo -v || error "sudo failed"

    # trap: run a command when the script exits for any reason.
    # Ctrl+C (INT) and kill (TERM) are turned into a normal exit,
    # which then fires the EXIT trap and removes the rule
    trap 'sudo rm -f "$sudoers_tmp"' EXIT
    trap 'exit 1' INT TERM

    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_tmp" >/dev/null
    sudo chmod 440 "$sudoers_tmp"
    ok "removed automatically when the script ends"
}

tweak_pacman() {
    step "pacman and makepkg settings"

    # colored output and parallel downloads
    sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf
    sudo sed -Ei 's/^#?(ParallelDownloads).*/\1 = 5/' /etc/pacman.conf

    # compile AUR packages on all cpu cores
    sudo sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf

    ok "Color, ParallelDownloads = 5, MAKEFLAGS = -j$(nproc)"
}

enable_arch_repos() {
    step "arch repositories"

    sudo pacman -S --needed --noconfirm artix-archlinux-support </dev/null ||
        error "cannot install artix-archlinux-support"

    # artix repos stay first, arch [extra] is added after them
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

    # build yay-bin: prebuilt binary, no need to compile Go
    local build_dir
    build_dir=$(mktemp -d)
    git clone --depth 1 "https://aur.archlinux.org/$aur_helper-bin.git" "$build_dir" ||
        error "cannot download $aur_helper"
    (cd "$build_dir" && makepkg -si --noconfirm </dev/null) ||
        error "cannot build $aur_helper"
    rm -rf "$build_dir"

    ok "$aur_helper installed"
}

# package list format: tag,package,description
#   empty tag = official repos (pacman), A = AUR
install_packages() {
    step "packages ($wm desktop)"

    local tag pkg desc
    # read the list line by line; IFS=, splits each line on commas
    package_lines | while IFS=, read -r tag pkg desc; do
        if is_installed "$pkg"; then
            ok "$pkg"
            continue
        fi

        info "$pkg - $desc"
        # </dev/null: the installer must not eat the rest of our list from stdin
        case "$tag" in
            A) "$aur_helper" -S --needed --noconfirm "$pkg" </dev/null ;;
            *) sudo pacman -S --needed --noconfirm "$pkg" </dev/null ;;
        esac || error "cannot install $pkg"
    done
}

# --check mode: ask the repos whether each package exists, install nothing
check_packages() {
    step "checking package names"

    local tag pkg desc missing=0
    while IFS=, read -r tag pkg desc; do
        # AUR packages can only be checked once the AUR helper exists
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

# method from the s6-frontend docs, verified in the VM on 19.10.2026:
#   s6 set enable  - mark services as active in the working set (a draft)
#   s6 set commit  - compile the working set into a service database
#   s6 live install - make that database the live one; services start at boot
# commit alone changes nothing at boot. Right after install, s6-supervise may
# print "unable to chdir to <svc>-srv" once per new service: harmless, the
# services run fine after a reboot. Running install again is a no-op.
enable_services() {
    step "s6 services from services.txt"

    local svc
    for svc in $(read_list "$services_file"); do
        sudo s6 set enable "$svc" || error "cannot enable $svc"
        info "enabled $svc"
    done

    sudo s6 set commit || error "s6 set commit failed"
    sudo s6 live install || error "s6 live install failed"

    # seatd lets sway use the screen and input devices without root
    sudo usermod -aG seat "$USER"
    ok "added $USER to group seat (relogin to apply)"
}

configure_system() {
    step "system settings"

    # zsh as the login shell
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
        sudo chsh -s "$(command -v zsh)" "$USER"
        info "login shell: zsh"
    fi

    # iwd: get IP addresses itself (no dhcpcd needed for wifi)
    # and hand DNS to openresolv, since there is no systemd-resolved
    sudo mkdir -p /etc/iwd
    printf '[General]\nEnableNetworkConfiguration=true\n\n[Network]\nNameResolvingService=resolvconf\n' |
        sudo tee /etc/iwd/main.conf >/dev/null
    info "iwd: built-in DHCP, DNS via resolvconf"

    # no annoying beep from the pc speaker
    echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf >/dev/null
    info "pc speaker disabled"

    # remember the desktop choice for the session start
    mkdir -p "$(dirname "$wm_file")"
    echo "$wm" > "$wm_file"
    info "desktop choice saved: $wm_file"

    ok "done"
}

link_dotfiles() {
    step "symlinks"
    # the logo is already on screen, don't print it twice
    DOTS_NO_LOGO=1 sh "$dots_path/link.sh"
}

usage() {
    echo "usage: $0 [--wm sway|driftwm] [--check] [-h | --help]"
    echo "  --wm NAME   choose the desktop without being asked"
    echo "  --check     only check that all packages exist, install nothing"
    echo "  -h, --help  show this help"
}

### MAIN ###

check_only=0

# options; shift removes the handled argument from $@
while [ $# -gt 0 ]; do
    case "$1" in
        --check)   check_only=1 ;;
        --wm)      [ $# -ge 2 ] || error "--wm needs a name: sway or driftwm"
                   wm=$2
                   shift ;;
        -h|--help) usage; exit 0 ;;
        *)         usage >&2; error "unknown option: $1" ;;
    esac
    shift
done

case "$wm" in
    ""|sway|driftwm) ;;
    *) error "unknown desktop: $wm (use sway or driftwm)" ;;
esac

logo

if [ "$check_only" = 1 ]; then
    check_system
    check_packages
    exit 0
fi

ask_wm
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
