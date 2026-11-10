# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄▄█ ▀  ▄▄▄ ▄█▄  ▄ ▄▄  ▄▄     ▄▄▄ █▄▄
# █  █ █ ▀▀▄▄  █   █▀   █  █   ▀▀▄▄ █  █
#  ▀▀▀ ▀ ▀▀▀    ▀▀ ▀     ▀▀  ▀ ▀▀▀  ▀  ▀
# What only KISS has (musl, busybox, runit): kiss, runit services, the login.
#
# Loaded after lib.sh by install.sh, link.sh and shh. Every distro.sh has
# the same functions.

# The groups of the user. video: seatd gives its socket to it (libseat's
# seatd.run), and the GPU. audio: the sound card. wheel: sudo.
seat_groups=audio,video,wheel
# The sites for the internet check. https, not ping: ICMP is often
# blocked. A few of them, as one can be down or blocked.
online_sites='https://kisslinux.github.io https://codeberg.org https://github.com'
pkg_remove='kiss r'
# The root commands of power_run, for the sudoers rule (install.sh).
#
# "" means no arguments. There is no zzz here: suspend is "mem" written to
# /sys/power/state.
power_cmds='/usr/bin/poweroff "", /usr/bin/reboot "", /usr/bin/tee /sys/power/state'
# The repo files link.sh leaves out here. KISS's sway has no tray (no
# sd-bus), so 'tray_output' is an error.
distro_skip='config/swaybar/tray'

# The repos kiss builds from, cloned by kiss_repos. 'shh' holds our
# recipes and comes first: the first recipe found wins.
kiss_dir="$HOME/.local/share/kiss"
export KISS_PATH="$kiss_dir/shh:$kiss_dir/repo/core:$kiss_dir/repo/extra:$kiss_dir/repo/wayland:$kiss_dir/community/community:$kiss_dir/kiss-dbus/dbus"
export KISS_PROMPT=0
# Limit the number of parallel build jobs.
#
# kiss sets nothing here, so make runs on a single core while samurai
# (ninja) and cargo start a job for every thread. A large C++ file (the
# v8 in nodejs) needs around 2 GB to compile, which kills the build when
# memory runs out. One job per 2 GB of memory, but never more jobs than
# threads.
#
# Values set earlier (for example in /etc/profile) are kept. session_setup
# writes the same values to /etc/profile.d so 'kiss b' after login uses them.
build_jobs=$(awk -v n="$(nproc)" '/^MemTotal/ { j = int($2 / 2097152); print (j < 1 ? 1 : j > n ? n : j) }' /proc/meminfo)
export MAKEFLAGS="${MAKEFLAGS:--j$build_jobs}" SAMUFLAGS="${SAMUFLAGS:--j$build_jobs}" \
    CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$build_jobs}"

# Power off, reboot or suspend (scripts/power).
#
# 'sudo -n' fails instead of asking for a password.
power_run() {
    case "$1" in
        suspend) echo mem | sudo -n /usr/bin/tee /sys/power/state >/dev/null ;;
        *)       sudo -n "/usr/bin/$1" ;;
    esac
}

# Stop when this system can't take the setup.
distro_check() {
    [ -d /var/service ] && command -v sv >/dev/null || error "runit is not the init system here"

    # NVIDIA's driver is built for glibc only. On musl nouveau (mesa) runs
    # the card.
    case "$hardware" in
        *nvidia*) warn "NVIDIA: no NVIDIA driver on musl, nouveau (mesa) runs the card" ;;
    esac

    # sudo is not in base, and install.sh needs it to build anything.
    if ! command -v sudo >/dev/null; then
        info "as root: kiss U first, then kiss b sudo (the community repo must be in KISS_PATH)"
        info "then: addgroup $USER wheel, and in visudo uncomment the line %wheel ALL=(ALL:ALL) ALL"
    fi
}

# █▀▀▄ ▄▀▀▄ ▄▀▀▀ █ ▄▀ ▄▀▀▄ ▄▀▀▀ █▀▀▀ ▄▀▀▀
# █▀▀  █▀▀█ █    █▀▄  █▀▀█ █ ▀█ █▀▀   ▀▀▄
# ▀    ▀  ▀  ▀▀▀ ▀  ▀ ▀  ▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# Clone the repos that are missing and copy our recipes.
#
# The recipes are copied, not linked: 'kiss u' would otherwise run 'git
# pull' in the dotfiles repo. They come from the repo (install.sh) or from
# ~/.local/share/shh/repo (link.sh puts them there for shh).
#
# A recipe turned off in shh config (recipe_NAME=no) is left out, so kiss
# finds the one from kiss-community instead. '-L' copies the files behind
# the links of a 'link.sh --link' install, not the links themselves.
kiss_repos() {
    local url src recipe
    mkdir -p "$kiss_dir" || error "cannot create $kiss_dir"
    for url in https://github.com/kiss-community/repo \
               https://github.com/kiss-community/community \
               https://codeberg.org/kiss-community/kiss-dbus; do
        [ -d "$kiss_dir/${url##*/}" ] ||
            git clone --depth 1 "$url" "$kiss_dir/${url##*/}" || error "cannot clone $url"
    done
    src="${system_dir:-${distro_file%/*}}/repo"
    [ -d "$src" ] || return 0
    rm -rf "$kiss_dir/shh" && mkdir "$kiss_dir/shh" || error "cannot make $kiss_dir/shh"
    for recipe in "$src"/*; do
        [ "$(setting "recipe_${recipe##*/}" yes)" = no ] && continue
        cp -RL "$recipe" "$kiss_dir/shh/" || error "cannot copy $recipe to $kiss_dir/shh"
    done
}

pkg_installed() {
    kiss l "$1" >/dev/null 2>&1
}

# Build and install a package: pkg_install TAG PKG (no tags on KISS).
#
# With KISS_PROMPT=0 'kiss b' installs the dependencies but only builds
# PKG itself, so 'kiss i' follows. '</dev/null' keeps kiss from reading
# the rest of our list. The first call can come from 'shh config', before
# distro_prepare, hence the kiss_repos.
pkg_install() {
    [ -d "$kiss_dir/shh" ] || kiss_repos
    kiss b "$2" </dev/null && kiss i "$2" </dev/null
}

# Check that a package exists ('--check'): 0 found, 1 not found.
pkg_exists() {
    [ -d "$kiss_dir/shh" ] || kiss_repos >/dev/null
    kiss s "$2" >/dev/null 2>&1
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

# Update the repos and the whole system, before any package.
#
# Everything is built from source, so the first run takes hours.
# shortcut: a new OpenSSL soname breaks sudo during kiss U (its recipe has no depends), then: as root kiss b sudo
distro_prepare() {
    step "system update"
    kiss_repos
    kiss u </dev/null || error "cannot update the repos (no internet?)"
    kiss U </dev/null || error "system update failed"
    ok "system updated"
}

# Skip the VMware clipboard: the clipway fork of open-vm-tools is not
# packaged for KISS.
vmware_clipboard() {
    [ "$hardware" != vmware ] || info "VMware clipboard: not packaged for KISS, skipped"
}

# ▄▀▀▀ █▀▀▀ █▀▀▄ █   █ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀
#  ▀▀▄ █▀▀  █▀█  ▀▄ ▄▀  █  █    █▀▀   ▀▀▄
# ▀▀▀  ▀▀▀▀ ▀  ▀   ▀   ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀

# Turn services on and off: svc_apply ON OFF.
#
# A runit service is on while /var/service/NAME links to /etc/sv/NAME:
# runsvdir starts it within 5 s and at every boot. Without the link
# runsvdir stops it.
#
# eiwd's own service runs 'iwd -d', and the debug output floods tty1, so
# it gets our run file. It is written on every run, as 'kiss U' can bring
# the file of the package back.
svc_apply() {
    local svc
    write_root /etc/sv/eiwd/run "$(printf '#!/bin/sh\nexec iwd 2>&1')"
    sudo chmod 755 /etc/sv/eiwd/run || error "cannot chmod /etc/sv/eiwd/run"
    # Make mdevd load drivers for new devices.
    #
    # mdevd loads no drivers on its own. The MODALIAS rule goes first and
    # starts with '-' so the rules below still run for the same device.
    # The '-q' keeps modprobe quiet about drivers built into the kernel,
    # which would otherwise print hundreds of "not found" lines at boot.
    #
    # An older rule without '-q' is replaced: '1i' inserts the new rule
    # above the first line and 'd' then drops every old one.
    grep -q '^-\$MODALIAS=.*@modprobe -q ' /etc/mdevd.conf ||
        sudo sed -i -e '1i -$MODALIAS=.* 0:0 660 @modprobe -q "$MODALIAS"' \
            -e '/^-\$MODALIAS=/d' /etc/mdevd.conf ||
        error "cannot add the driver rule to /etc/mdevd.conf"

    # Run the rules for the devices that are already there at boot
    # (coldplug), not only for the ones plugged in later.
    grep -q 'mdevd -C' /etc/sv/mdevd/run ||
        sudo sed -i 's/exec mdevd /exec mdevd -C /' /etc/sv/mdevd/run ||
        error "cannot turn on coldplug in /etc/sv/mdevd/run"

    for svc in $1; do
        # Skip bluetoothd when the kernel has no bluetooth support.
        # It cannot start without it and runit would restart it forever.
        if [ "$svc" = bluetoothd ] && [ ! -d /sys/class/bluetooth ]; then
            info "skipped bluetoothd: the kernel has no bluetooth"
            continue
        fi
        [ -d "/etc/sv/$svc" ] || error "no service $svc in /etc/sv"
        # Send the output of the service to /var/log/NAME, not the console.
        #
        # runsvdir is started by init on the console, so a service without
        # a log/ prints everything over the boot messages and the login
        # prompt. svlogd keeps the last 10 files of 1 MB each. runsv sees a
        # new log/ only when it starts again, so this works after a reboot.
        if ! sudo test -e "/etc/sv/$svc/log/run"; then
            sudo mkdir -p "/var/log/$svc" || error "cannot create /var/log/$svc"
            write_root "/etc/sv/$svc/log/run" "$(printf '#!/bin/sh\nexec svlogd -tt /var/log/%s' "$svc")"
            sudo chmod 755 "/etc/sv/$svc/log/run" || error "cannot chmod /etc/sv/$svc/log/run"
        fi
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
# child. Its log/ is a child too, so the logger does not count.
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
    # 'pgrep -l' prints "PID NAME" lines, 'grep -v' finds one that is not the
    # logger.
    pgrep -l -P "$pid" | grep -qv ' svlogd$' || { echo " down"; return 1; }
}

# Start or stop a service now, till the reboot (settings > Svc).
#
# runit has no dependencies: with dbus off bluetoothd fails and restarts.
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

# No unused consoles to turn off: the gettys are in /etc/inittab, not
# services.
svc_unused=''

# The vpn service (scripts/vpn): our own, run as root.
vpn_svc=shh-vpn

# Make the service that runs the command '$1'.
#
# runit knows it after this, but a "down" file keeps it from starting at
# boot (vpn > Start at boot removes the file). Without a log/ sing-box
# writes over the login prompt. svlogd, as KISS runs no syslog.
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

# Set up the login session. There is no PAM and no udev here.
#
# rc.boot sources /etc/rc.d/*.boot at every boot, when /run is empty.
# Login shells read /etc/profile.d (zsh too: KISS's /etc/zprofile loads
# /etc/profile). ALSA goes through PipeWire, as firefox has only the ALSA
# backend on KISS.
# shortcut: brightness is set once at boot, a backlight that appears later needs an mdev.conf rule
session_setup() {
    local uid
    uid=$(id -u)
    write_root /etc/rc.d/shh.boot "mkdir -p -m 700 /run/user/$uid
chown $USER /run/user/$uid
for light in /sys/class/backlight/*/brightness; do
    [ -e \"\$light\" ] && chgrp video \"\$light\" && chmod g+w \"\$light\"
done"
    # Set LANG, which nothing on KISS does.
    #
    # musl always works in UTF-8, but programs look at LANG to find out:
    # btop refuses to start without a UTF-8 one. A LANG set earlier is kept.
    write_root /etc/profile.d/shh.sh "export XDG_RUNTIME_DIR=/run/user/\$(id -u)
export LANG=\"\${LANG:-C.UTF-8}\"
export KISS_PATH=$KISS_PATH
export MAKEFLAGS=\"\${MAKEFLAGS:-$MAKEFLAGS}\" SAMUFLAGS=\"\${SAMUFLAGS:-$SAMUFLAGS}\" CARGO_BUILD_JOBS=\"\${CARGO_BUILD_JOBS:-$CARGO_BUILD_JOBS}\""
    info "XDG_RUNTIME_DIR and LANG at login, brightness: group video, build jobs: $SAMUFLAGS"

    # Drop the KISS_PATH line the KISS install guide adds to /etc/profile.
    #
    # /etc/profile reads profile.d first and sets its own KISS_PATH after,
    # so ours (with our recipes) would never be seen. '-i.bak-DATE' keeps
    # the old file next to it, like write_root does.
    ! grep -q '^export KISS_PATH=' /etc/profile ||
        sudo sed -i".bak-$stamp" '/^export KISS_PATH=/d' /etc/profile ||
        error "cannot remove KISS_PATH from /etc/profile"

    [ -e /etc/asound.conf ] || [ -L /etc/asound.conf ] ||
        sudo ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/asound.conf ||
        error "cannot link /etc/asound.conf"
    info "alsa: through pipewire"

    # KISS's patch makes pipewire start wireplumber, and scripts/sound starts
    # it too.
    write_root /etc/pipewire/pipewire.conf.d/shh.conf 'context.properties = { exec.session-manager = false }'
}

# Add the user to GROUPS (comma-separated).
#
# busybox has no usermod, and 'addgroup USER GROUP' takes one group.
user_groups() {
    local group
    for group in $(printf %s "$1" | tr , ' '); do
        sudo addgroup "$USER" "$group" || error "cannot add $USER to $group"
    done
}

# Set the login shell of the user. busybox has no chsh.
user_shell() {
    sudo sed -i "/^$USER:/s|[^:]*\$|$1|" /etc/passwd || error "cannot edit /etc/passwd"
}

# Print what install.sh changed in the system ('link.sh --uninstall').
distro_undo() {
    echo "  packages   packages/*.csv        kiss r NAME"
    echo "  repos      $kiss_dir             rm -r it"
    echo "  services   services.txt          sudo rm /var/service/NAME"
    echo "  shell      zsh                   the last field of your line in /etc/passwd"
    echo "  groups     audio, video, wheel   sudo delgroup $(id -un) GROUP"
    echo "  /etc       rc.d/shh.boot (/run/user, brightness), profile.d/shh.sh (XDG_RUNTIME_DIR, LANG, KISS_PATH, build jobs), profile (KISS_PATH line removed), sv/eiwd/run, sv/mdevd/run, sv/*/log (output to /var/log/NAME), mdevd.conf,"
    echo "             dhcpcd.conf (denyinterfaces wl*), iwd/main.conf, modprobe.d/nobeep.conf, asound.conf, pipewire/pipewire.conf.d/shh.conf,"
    echo "             sudoers.d/shh-power (poweroff, reboot, sleep): sudo rm /etc/sudoers.d/shh-power;"
    echo "             older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or rc.d/shh.boot sway will not start"
}
