#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# ▀ ▄▄▄   ▄▄▄ ▄█▄   ▄▄▄  █ █    ▄▄▄ █▄▄  
# █ █  █ ▀▀▄▄  █   █  █  █ █   ▀▀▄▄ █  █ 
# ▀ ▀  ▀ ▀▀▀    ▀▀  ▀▀▀▀ ▀ ▀ ▀ ▀▀▀  ▀  ▀                                       
# Set up a fresh system with these dotfiles.
#
# Run as your user: 'sh install.sh'. '--check' only checks the package
# names. Safe to run again. What differs per distro is in system/DISTRO/,
# the steps are in MAIN at the bottom.

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

dots_path=$(cd "$(dirname "$0")" && pwd -P)

# The temporary sudo rule of enable_nopasswd.
#
# The 'zz-' puts it last: sudo reads sudoers.d in order and the last match
# wins, so a later %wheel rule would undo NOPASSWD.
sudoers_tmp="/etc/sudoers.d/zz-dotfiles-temp"

# A copy of the output of the last run (start_log).
install_log="$HOME/.local/state/shh/install.log"

# The date for backup names, like in link.sh.
stamp=$(date +%Y%m%d-%H%M%S)

[ -f "$dots_path/lib/lib.sh" ] || { echo "lib/lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib/lib.sh"

# The lists and steps of this distro ('$distro' is set in lib.sh).
system_dir="$dots_path/system/$distro"
packages_dir="$system_dir/packages"
packages_file="$packages_dir/common.csv"
services_file="$system_dir/services.txt"
# The parts 'shh config' can turn off.
components_file="$dots_path/components/${distro}_components.txt"
# Without a distro.sh check_system stops with "not supported".
[ ! -f "$system_dir/distro.sh" ] || . "$system_dir/distro.sh"

# The VM type or the graphics cards, one per line (scripts/hardware).
hardware=$(sh "$dots_path/scripts/hardware" 2>/dev/null || true)

# █  █ █▀▀▀ █    █▀▀▄ █▀▀▀ █▀▀▄ ▄▀▀▀ 
# █▀▀█ █▀▀  █    █▀▀  █▀▀  █▀█   ▀▀▄ 
# ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀    ▀▀▀▀ ▀  ▀ ▀▀▀  

# Print common.csv and the list of every graphics driver (gpu_drivers: lib.sh).
package_lines() {
    local hw
    read_list "$packages_file"
    for hw in $(gpu_drivers "$hardware"); do
        [ ! -f "$packages_dir/$hw.csv" ] || read_list "$packages_dir/$hw.csv"
    done
}

# Print every list, not only this machine's, so '--check' finds typos anywhere.
all_package_lines() {
    local list
    for list in "$packages_dir"/*.csv; do
        read_list "$list"
    done
}

# Put TEXT into FILE as root: write_root FILE TEXT.
#
# An old FILE with another text is renamed to FILE.bak-DATE first. A FILE
# with the same text is left alone.
write_root() {
    local file="$1"
    local text="$2"

    if sudo test -e "$file"; then
        [ "$(sudo cat "$file")" != "$text" ] || return 0
        sudo mv "$file" "$file.bak-$stamp" || error "cannot back up $file"
        msg "$red" "$sym_bak" "$file -> $file.bak-$stamp"
    fi

    sudo mkdir -p "$(dirname "$file")" || error "cannot create $(dirname "$file")"
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

    # Check the internet through the sites of this distro (online_sites).
    #
    # A fresh system may have no curl yet (Void base). The check is skipped
    # then: the first package download fails anyway without the internet.
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

# Show the menu on the first run. Later 'shh config' changes the choices.
choose_parts() {
    step "what to install"

    if [ -f "$shh_config" ]; then
        info "choices: $shh_config (change: shh config)"
    else
        SHH_INSTALL=1 sh "$dots_path/scripts/shh" config || error "shh config failed"
    fi
    ok "done"
}

# Check that every package exists ('--check'). Installs nothing.
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

# Send the output to the log too, from here on.
#
# 'tee' reads a fifo, so the script keeps writing to one place. This runs
# after the menu, as fzf draws on the terminal. Programs see no terminal
# from now on, so pacman prints no progress bars.
start_log() {
    local fifo
    mkdir -p "$(dirname "$install_log")"
    fifo=$(mktemp -u) || error "cannot make a temporary name"
    mkfifo "$fifo" || error "cannot make $fifo"
    tee "$install_log" <"$fifo" &
    exec >"$fifo" 2>&1
    # Both ends are open, so the name is not needed anymore.
    rm -f "$fifo"
    info "log: $install_log"
}

# Let sudo work without a password while the script runs.
#
# AUR builds would ask for it again and again (a trick from LARBS).
enable_nopasswd() {
    step "temporary passwordless sudo"
    sudo -v || error "sudo failed"

    # A rule left over by a run that was killed hard (kill -9, power off).
    if sudo test -e "$sudoers_tmp"; then
        warn "found a leftover $sudoers_tmp from an interrupted run, removing it"
        sudo rm -f "$sudoers_tmp"
    fi

    # Remove the rule on any exit, Ctrl+C too.
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

# Set what the graphics drivers need. The drivers themselves come from
# system/DISTRO/packages/CARD.csv.
configure_gpu() {
    step "graphics"

    local hw drivers want
    drivers=$(gpu_drivers "$hardware")
    if [ -z "$drivers" ]; then
        warn "no graphics card found, only mesa is installed"
        return 0
    fi
    if [ "$(setting gpu auto)" != auto ]; then
        info "picked in shh config: $(setting gpu auto)"
        # A card was found but left out by hand. It runs on mesa only, and
        # its firmware may be offered for removal at the end.
        for hw in $hardware; do
            case "$hw" in
                amd|intel) want=$hw ;;
                nvidia*)   want='nvidia\|nvidia-580xx\|nouveau' ;;
                *)         continue ;;
            esac
            printf '%s\n' "$drivers" | grep -qx "$want" ||
                warn "$hw card found, but its driver is not picked (shh config > settings > graphics)"
        done
    fi

    for hw in $drivers; do
        case "$hw" in
            # Picked in 'shh config' on a distro without it (Void musl).
            nvidia|nvidia-580xx) [ -f "$packages_dir/$hw.csv" ] || {
                warn "no $hw driver for this system, nouveau (mesa) runs the card"
                continue; } ;;
        esac
        case "$hw" in
            nvidia|nvidia-580xx)
                # sway needs kernel modesetting, which the 580xx driver has off by default.
                write_root /etc/modprobe.d/nvidia-modeset.conf "options nvidia_drm modeset=1"
                info "$hw: kernel modesetting on (after reboot)" ;;
            nvidia-legacy)
                warn "this NVIDIA card is too old for the NVIDIA driver, nouveau (mesa) runs it" ;;
            nouveau)
                info "nouveau: the free NVIDIA driver, in the kernel and mesa; nothing to install"
                info "the NVIDIA driver blocks it: remove its packages (asked at the end), then reboot" ;;
            *)
                info "$hw: nothing to set" ;;
        esac
    done

    ok "done"
}

# Set up the network. Runs before enable_services, which starts iwd and
# dhcpcd right away.
configure_network() {
    step "network settings"

    # iwd gets the IP address itself and hands DNS to openresolv.
    write_root /etc/iwd/main.conf \
        "$(printf '[General]\nEnableNetworkConfiguration=true\n\n[Network]\nNameResolvingService=resolvconf')"
    info "iwd: built-in DHCP, DNS via resolvconf"

    # dhcpcd takes the wired network only, wifi is iwd's ('wl*': wlan0, wlp1s0).
    if ! grep -q '^denyinterfaces wl\*$' /etc/dhcpcd.conf 2>/dev/null; then
        echo 'denyinterfaces wl*' | sudo tee -a /etc/dhcpcd.conf >/dev/null ||
            error "cannot write /etc/dhcpcd.conf"
    fi
    # Comment out the old rule of earlier installs, 'wl*' above covers it.
    if grep -q '^denyinterfaces wlan\*$' /etc/dhcpcd.conf 2>/dev/null; then
        sudo sed -i 's/^denyinterfaces wlan\*$/#&/' /etc/dhcpcd.conf ||
            error "cannot edit /etc/dhcpcd.conf"
        info "dhcpcd: commented out the old rule denyinterfaces wlan*"
    fi
    info "dhcpcd: wired only"

    # DNS from 'shh config' (settings > dns). 'dhcp' is the stock file: the
    # servers of the network.
    local dns conf
    dns=$(setting dns dhcp)
    conf='# Configuration for resolvconf(8)
# See resolvconf.conf(5) for details

resolv_conf=/etc/resolv.conf
# If you run a local name server, you should uncomment the below line and
# configure your subscribers configuration files below.
#name_servers=127.0.0.1'
    if [ "$dns" != dhcp ]; then
        # Root sources this file as sh, so let only addresses in.
        case "$dns" in
            *[!0-9A-Fa-f.:,]*) error "dns: not IP addresses: $dns (shh config)" ;;
        esac
        # Use only these servers: musl asks all of them at once and takes the
        # first answer.
        conf="$conf

# shh config: dns
resolv_conf_passthrough=NULL
name_servers=\"$(printf '%s' "$dns" | tr ',' ' ')\""
    fi
    # Write only on a change, so 'shh update' leaves resolv.conf alone.
    if [ "$(cat /etc/resolvconf.conf 2>/dev/null)" != "$conf" ]; then
        write_root /etc/resolvconf.conf "$conf"
        sudo resolvconf -u || warn "resolvconf -u failed"
    fi
    info "dns: $dns"

    ok "done"
}

# Turn on the services of services.txt: started now and at every boot.
#
# The service of a part turned off in 'shh config' is turned off too
# (svc_apply: distro.sh).
enable_services() {
    step "services from services.txt"

    local services off_svcs
    off_svcs=$(off_items "$components_file" 4)
    services=$(read_list "$services_file" | without "$off_svcs")
    svc_apply "$services" "$off_svcs $svc_unused"

    # sing-box gets our own service (vpn_setup: distro.sh). The vpn menu
    # starts it.
    if part_on sing-box ''; then
        sh "$dots_path/scripts/vpn" setup || error "vpn setup failed"
    fi

    # seat_groups and user_groups come from distro.sh.
    user_groups "$seat_groups"
    ok "added $USER to groups $seat_groups (relogin to apply)"
}

configure_system() {
    step "system settings"

    # user_shell comes from distro.sh.
    if [ "$(grep "^$USER:" /etc/passwd | cut -d: -f7)" != "$(command -v zsh)" ]; then
        user_shell "$(command -v zsh)"
        info "login shell: zsh"
    fi

    session_setup

    if [ "$(setting nobeep yes)" = yes ]; then
        write_root /etc/modprobe.d/nobeep.conf "blacklist pcspkr"
        info "pc speaker disabled"
    fi

    # Let the group video change the screen brightness (scripts/brightness).
    #
    # The trigger makes the rule work now, not after a reboot. A system
    # without udev does this in session_setup.
    if command -v udevadm >/dev/null; then
        write_root /etc/udev/rules.d/90-shh-backlight.rules \
            "$(printf '%s\n%s' \
                'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"' \
                'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"')"
        sudo udevadm trigger --action=add --subsystem-match=backlight || true
        info "brightness: group video"
    fi

    ok "done"
}

# Allow poweroff, reboot and sleep without a password (scripts/power).
#
# Only these commands (power_cmds: distro.sh). visudo checks the rule
# before sudo reads it: a broken sudoers file locks sudo out.
configure_power() {
    step "power"

    local rule tmp
    rule="$USER ALL=(root) NOPASSWD: $power_cmds"
    tmp=$(mktemp) || error "cannot make a temporary file"
    printf '%s\n' "$rule" >"$tmp"
    if ! sudo visudo -cqf "$tmp"; then
        rm -f "$tmp"
        error "bad sudoers rule: $rule"
    fi
    rm -f "$tmp"

    write_root /etc/sudoers.d/shh-power "$rule"
    sudo chmod 440 /etc/sudoers.d/shh-power || error "cannot chmod /etc/sudoers.d/shh-power"
    ok "poweroff, reboot, sleep: no password"
}

link_dotfiles() {
    step "dotfiles"
    # With no mode in 'shh config' link.sh keeps what is installed.
    local mode
    mode=$(setting mode '')
    DOTS_NO_LOGO=1 sh "$dots_path/lib/link.sh" ${mode:+"--$mode"}
}

# Print the packages of the graphics drivers that are not picked now.
#
# They are in a DRIVER.csv, but not in common.csv or in a picked list.
driver_leftovers() {
    local list keep
    keep=$(package_lines | cut -d, -f2)
    for list in "$packages_dir"/*.csv; do
        [ "$list" != "$packages_file" ] || continue
        read_list "$list" | cut -d, -f2
    # linux-headers is shared: other dkms modules (virtualbox) need it
    # without depending on it.
    done | sort -u | without "$keep" | without linux-headers
}

# Offer to remove what the parts turned off in 'shh config' left behind.
leftovers() {
    local pkgs answer
    pkgs=$(off_items "$components_file" 2; driver_leftovers)
    # With no names pkg_leftovers would print every installed package.
    [ -z "$pkgs" ] || pkgs=$(pkg_leftovers $pkgs)
    if [ -n "$pkgs" ]; then
        warn "not needed anymore: $pkg_remove $pkgs"
        # No terminal (run by a script): print the hint only.
        if [ -t 0 ]; then
            printf '  remove them now? [y/N] '
            read -r answer || answer=
            # The package manager lists what goes (with deps) and asks again.
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
start_log
enable_nopasswd
distro_prepare
# vmware_clipboard comes from distro.sh.
vmware_clipboard
install_packages
configure_gpu
configure_network
enable_services
configure_system
configure_power
link_dotfiles
leftovers

echo
ok "all done - reboot and log in on the TTY"
info "log: $install_log"
