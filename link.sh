#!/bin/sh
# link.sh - symlink the repo into $HOME
#   config/NAME  -> ~/.config/NAME
#   home/FILE    -> ~/FILE
#   scripts/FILE -> ~/.local/bin/FILE
#   wallpapers/  -> ~/wallpapers
# usage: link.sh [-n | --dry-run] [-u | --uninstall]. Safe to run again:
# anything in the way is renamed to NAME.bak-DATE, never deleted.
# --uninstall removes only our links and puts the oldest NAME.bak-DATE back

set -eu

### SETTINGS ###

dots_path=$(cd "$(dirname "$0")" && pwd -P)

config_dir="$HOME/.config"
bin_dir="$HOME/.local/bin"

stamp=$(date +%Y%m%d-%H%M%S)
dry_run=0
uninstall=0
linked=0
skipped=0
backups=0

[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

backup_msg() { msg "$red" "$sym_bak" "$1"; }

usage() {
    echo "usage: $0 [-n | --dry-run] [-u | --uninstall] [-h | --help]"
    echo "  -n, --dry-run    show what would be done, change nothing"
    echo "  -u, --uninstall  remove the links, put the old files back"
    echo "  -h, --help     show this help"
}

### FUNCTIONS ###

# link SRC DST: make DST a symlink to SRC, backing up whatever is in the way
link() {
    local src="$1"
    local dst="$2"

    [ -e "$src" ] || error "source not found: $src"
    [ "$uninstall" = 0 ] || { remove_link "$src" "$dst"; return; }

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "$dst"
        skipped=$((skipped + 1))
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="$dst.bak-$stamp"
        [ "$dry_run" = 1 ] || mv "$dst" "$backup" || error "cannot back up $dst"
        backup_msg "$dst -> $backup"
        backups=$((backups + 1))
    fi

    if [ "$dry_run" = 0 ]; then
        mkdir -p "$(dirname "$dst")" || error "cannot create $(dirname "$dst")"
        ln -s "$src" "$dst" || error "cannot link $dst"
    fi
    info "$dst -> $src"
    linked=$((linked + 1))
}

# remove_link SRC DST: delete DST only if it is our link to SRC, then put
# its oldest backup (the file from before the dotfiles) back
remove_link() {
    local src="$1"
    local dst="$2"
    local bak

    if [ ! -L "$dst" ] || [ "$(readlink "$dst")" != "$src" ]; then
        skipped=$((skipped + 1))
        return
    fi

    [ "$dry_run" = 1 ] || rm "$dst" || error "cannot remove $dst"
    info "removed $dst"
    linked=$((linked + 1))

    # the date in the name sorts, so the first one is the oldest
    for bak in "$dst".bak-*; do
        [ -e "$bak" ] || [ -L "$bak" ] || continue
        [ "$dry_run" = 1 ] || mv "$bak" "$dst" || error "cannot restore $bak"
        backup_msg "$bak -> $dst"
        backups=$((backups + 1))
        break
    done
}

# system changes stay: a mistake here breaks the login (seatd, pam_rundir)
print_system() {
    echo
    echo "install.sh also changed the system; undo by hand only what you need:"
    echo "  packages   packages/*.csv        sudo pacman -Rs NAME"
    echo "  services   services.txt          sudo s6 set disable NAME, sudo s6 set commit, sudo s6 live install"
    echo "  shell      zsh                   chsh -s /bin/bash"
    echo "  groups     seat, audio           sudo gpasswd -d $(id -un) GROUP"
    echo "  /etc       pam.d/system-login (pam_rundir), dhcpcd.conf (denyinterfaces wl*),"
    echo "             iwd/main.conf, modprobe.d/nobeep.conf, pacman.conf, makepkg.conf;"
    echo "             older versions of some are next to them as FILE.bak-DATE"
    echo "  without seatd or pam_rundir sway will not start"
}

# link_dir FROM TO: link every entry of FROM (hidden ones too) into TO
link_dir() {
    local from="$1"
    local to="$2"
    local src

    for src in "$from"/.[!.]* "$from"/*; do
        [ -e "$src" ] || continue
        [ "$(basename "$src")" != ".gitkeep" ] || continue
        link "$src" "$to/$(basename "$src")"
    done
}

### MAIN ###

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run)   dry_run=1 ;;
        -u|--uninstall) uninstall=1 ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; error "unknown option: $arg" ;;
    esac
done

[ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

# install.sh shows the logo itself
[ -n "${DOTS_NO_LOGO:-}" ] || logo

[ "$dry_run" = 0 ] || info "dry run: nothing will be changed"

link_dir "$dots_path/config"  "$config_dir"
link_dir "$dots_path/home"    "$HOME"
link_dir "$dots_path/scripts" "$bin_dir"

# the whole folder, so new pictures show up without running link.sh
link "$dots_path/wallpapers" "$HOME/wallpapers"

echo
if [ "$uninstall" = 0 ]; then
    echo "done: $linked linked, $skipped already ok, $backups backed up"
else
    echo "done: $linked removed, $backups restored, $skipped not ours or not there"
    print_system
fi
