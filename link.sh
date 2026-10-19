#!/bin/sh
# link.sh - create symlinks in $HOME pointing to files in this repo
#
# layout:
#   config/NAME   -> ~/.config/NAME
#   home/FILE     -> ~/FILE
#   scripts/FILE  -> ~/.local/bin/FILE
#
# usage: link.sh [-n | --dry-run] [-h | --help]
#
# safe to run again: correct links are skipped,
# anything in the way is renamed to a backup, never deleted

# stop on errors and on undefined variables
set -eu

### SETTINGS ###

# absolute path to the dotfiles repo (the directory this script lives in),
# regardless of where the script is run from;
# -P resolves symlinks so created links point to the real location
dots_path=$(cd "$(dirname "$0")" && pwd -P)

# where links go
config_dir="$HOME/.config"
bin_dir="$HOME/.local/bin"

# one timestamp per run, so all backups from this run share it
stamp=$(date +%Y%m%d-%H%M%S)

# 1 = only show what would be done, change nothing
dry_run=0

# counters for the summary at the end
linked=0
skipped=0
backups=0

### SHARED HELPERS ###

# colors, messages (info, ok, warn, error) and the logo live in lib.sh
[ -f "$dots_path/lib.sh" ] || { echo "lib.sh not found in $dots_path" >&2; exit 1; }
. "$dots_path/lib.sh"

# link.sh's own message for backups: red "~" (moved aside)
backup_msg() { msg "$red" "$sym_bak" "$1"; }

usage() {
    echo "usage: $0 [-n | --dry-run] [-h | --help]"
    echo "  -n, --dry-run  show what would be done, change nothing"
    echo "  -h, --help     show this help"
}

### FUNCTIONS ###

# link SRC DST: make DST a symlink to SRC, backing up whatever is in the way
link() {
    local src=$1
    local dst=$2

    # a missing source means a bug in the loops below
    [ -e "$src" ] || error "source not found: $src"

    # already linked to the right place - nothing to do
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "$dst"
        skipped=$((skipped + 1))
        return
    fi

    # something else is there (file, dir or broken link) - move it aside
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="$dst.bak-$stamp"
        [ "$dry_run" = 1 ] || mv "$dst" "$backup" || error "cannot back up $dst"
        backup_msg "$dst -> $backup"
        backups=$((backups + 1))
    fi

    # parent directory may not exist yet (e.g. ~/.local/bin on a fresh system)
    if [ "$dry_run" = 0 ]; then
        mkdir -p "$(dirname "$dst")" || error "cannot create $(dirname "$dst")"
        ln -s "$src" "$dst" || error "cannot link $dst"
    fi
    info "$dst -> $src"
    linked=$((linked + 1))
}

# link_dir FROM TO: link every entry of repo dir FROM into directory TO
link_dir() {
    local from=$1
    local to=$2
    local src

    # .[!.]* matches hidden files like .zshrc, but not . and ..
    for src in "$from"/.[!.]* "$from"/*; do
        # no match: the pattern stays as literal text - skip it
        [ -e "$src" ] || continue
        # .gitkeep only keeps empty dirs in git, it is not a config
        [ "$(basename "$src")" != ".gitkeep" ] || continue
        link "$src" "$to/$(basename "$src")"
    done
}

### MAIN ###

# options
case "${1:-}" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help)    usage; exit 0 ;;
    "")           ;;
    *)            usage >&2; error "unknown option: $1" ;;
esac

# as root, $HOME is /root and the links would land in the wrong home
[ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

# install.sh already showed the logo, so it sets DOTS_NO_LOGO=1
[ -n "${DOTS_NO_LOGO:-}" ] || logo

[ "$dry_run" = 0 ] || info "dry run: nothing will be changed"

link_dir "$dots_path/config"  "$config_dir"
link_dir "$dots_path/home"    "$HOME"
link_dir "$dots_path/scripts" "$bin_dir"

echo
echo "done: $linked linked, $skipped already ok, $backups backed up"
