#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# █ ▀ ▄▄▄  █  ▄    ▄▄▄ █▄▄  
# █ █ █  █ █▄█    ▀▀▄▄ █  █ 
# ▀ ▀ ▀  ▀ ▀  ▀ ▀ ▀▀▀  ▀  ▀ 
# link.sh - put the repo into $HOME: copies, or symlinks with --link
#   config/ -> ~/.config   home/ -> ~   scripts/ -> ~/.local/bin
#   wallpapers/ -> ~/wallpapers
#   lib/*.sh, this distro's system/DISTRO/ and components/DISTRO_components.txt -> ~/.local/share/shh (flat)
# file by file; a file that is not ours goes to NAME.bak-DATE, never deleted.
# ours = listed in ~/.local/state/shh/installed

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

# readlink -f: shh runs this file through ~/.local/share/shh/link.sh.
# lib.sh lies next to it: <repo>/lib or ~/.local/share/shh
script_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)
# the repo root; from ~/.local/share/shh it is ~/.local/share (install_all refuses it)
dots_path=$(cd "$script_dir/.." && pwd -P)

config_dir="$HOME/.config"
bin_dir="$HOME/.local/bin"
share_dir="$HOME/.local/share/shh"
list="$HOME/.local/state/shh/installed"

stamp=$(date +%Y%m%d-%H%M%S)
tab=$(printf '\t')
dry_run=0
uninstall=0
done_count=0
skipped=0
backups=0
# for the lists at the end: our files updated, yours moved to .bak
updated=''
backed_up=''

# copies by default; once installed with --link, it stays links
mode=copy
[ ! -L "$share_dir/lib.sh" ] || mode=link

[ -f "$script_dir/lib.sh" ] || { echo "lib.sh not found in $script_dir" >&2; exit 1; }
. "$script_dir/lib.sh"

# distro_undo for print_system: next to this file in share, system/DISTRO/ in the repo.
# loaded now: --uninstall removes share/distro.sh
for distro_file in "$script_dir/distro.sh" "$dots_path/system/$distro/distro.sh"; do
    [ ! -f "$distro_file" ] || { . "$distro_file"; break; }
done

backup_msg() { msg "$red" "$sym_bak" "$1"; }

usage() {
    echo "usage: $0 [-n | --dry-run] [--link | --copy] [-u | --uninstall] [-h | --help]"
    echo "  -n, --dry-run    show what would be done, change nothing"
    echo "  --link           symlinks to the repo: edits land in it (for working on the dotfiles)"
    echo "  --copy           copies, the repo can be deleted (the default)"
    echo "  -u, --uninstall  remove what is ours, put the old files back"
    echo "  -h, --help       show this help"
}

# █▀▀▀ █  █ █▄  █ ▄▀▀▀ ▀▀█▀▀ ▀█▀ ▄▀▀▄ █▄  █ ▄▀▀▀ 
# █▀▀  █  █ █ ▀▄█ █      █    █  █  █ █ ▀▄█  ▀▀▄ 
# ▀     ▀▀  ▀   ▀  ▀▀▀   ▀   ▀▀▀  ▀▀  ▀   ▀ ▀▀▀  

checksum() { sha256sum <"$1" | cut -d' ' -f1; }

# key SRC: what the list keeps for SRC: the link target or the hash of the copy
key() {
    if [ "$mode" = link ]; then echo "$1"; else checksum "$1"; fi
}

# same DST KEY: DST is still exactly what we put there
same() {
    if [ -L "$1" ]; then
        [ "$(readlink "$1")" = "$2" ]
    else
        [ -f "$1" ] && [ "$(checksum "$1")" = "$2" ]
    fi
}

# ours DST: we put DST there and nobody changed it, so no backup is needed.
# A link into the repo is ours too: that is how link.sh worked before the list
ours() {
    local old
    if [ -L "$1" ]; then
        case "$(readlink "$1")" in "$dots_path"/*) return 0 ;; esac
    fi
    [ -f "$list" ] || return 1
    old=$(awk -F "$tab" -v d="$1" '$2 == d { print $1; exit }' "$list")
    [ -n "$old" ] && same "$1" "$old"
}

# put_aside DST: remove our old DST, rename anything else to DST.bak-DATE
put_aside() {
    if ours "$1"; then
        [ "$dry_run" = 1 ] || rm "$1" || error "cannot remove $1"
        updated="$updated  $1
"
        return
    fi
    local backup="$1.bak-$stamp"
    [ "$dry_run" = 1 ] || mv "$1" "$backup" || error "cannot back up $1"
    backup_msg "$1 -> $backup"
    backups=$((backups + 1))
    backed_up="$backed_up  $1 -> $backup
"
}

# install_file SRC DST: copy or link one file and add it to the list
install_file() {
    local src="$1"
    local dst="$2"
    local k
    k=$(key "$src")
    printf '%s\t%s\n' "$k" "$dst" >>"$new_list"

    # already in place: the right link, or a copy with the same content
    if { [ "$mode" = link ] && same "$dst" "$k"; } ||
       { [ "$mode" = copy ] && [ ! -L "$dst" ] && same "$dst" "$k"; }; then
        ok "$dst"
        skipped=$((skipped + 1))
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        put_aside "$dst"
    fi
    if [ "$dry_run" = 0 ]; then
        mkdir -p "$(dirname "$dst")" || error "cannot create $(dirname "$dst")"
        if [ "$mode" = link ]; then
            ln -s "$src" "$dst" || error "cannot link $dst"
        else
            cp "$src" "$dst" || error "cannot copy $dst"
        fi
    fi
    info "$dst"
    done_count=$((done_count + 1))
}

# install_tree SRC DST: a file, or a folder file by file
install_tree() {
    local src="$1"
    local dst="$2"

    [ -e "$src" ] || error "source not found: $src"
    # a part turned off in shh config (components.txt)
    case "$off_files" in *" ${src#"$dots_path/"} "*) return 0 ;; esac
    if [ ! -d "$src" ]; then
        install_file "$src" "$dst"
        return
    fi

    # a link or a file where our folder goes (old link.sh linked whole folders)
    if [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -d "$dst" ]; }; then
        put_aside "$dst"
    fi
    install_entries "$src" "$dst"
}

# install_entries FROM TO: everything in FROM (hidden too) into TO; TO itself
# is never moved, even if it is a link (~/.config can be one)
install_entries() {
    local f
    for f in "$1"/.[!.]* "$1"/*; do
        [ -e "$f" ] || continue
        [ "${f##*/}" != ".gitkeep" ] || continue
        install_tree "$f" "$2/${f##*/}"
    done
}

# restore DST: put the oldest DST.bak-DATE (from before the dotfiles) back;
# the date in the name sorts, so the first one is the oldest
restore() {
    local bak
    for bak in "$1".bak-*; do
        [ -e "$bak" ] || [ -L "$bak" ] || continue
        [ "$dry_run" = 1 ] || mv "$bak" "$1" || error "cannot restore $bak"
        backup_msg "$bak -> $1"
        backups=$((backups + 1))
        return
    done
}

# remove_entry KEY DST: delete DST if it is still ours, then empty folders above it
remove_entry() {
    local dir="${2%/*}"

    if [ ! -e "$2" ] && [ ! -L "$2" ]; then
        skipped=$((skipped + 1))
        return
    fi
    if ! same "$2" "$1"; then
        warn "changed since install, kept: $2"
        skipped=$((skipped + 1))
        return
    fi

    [ "$dry_run" = 1 ] || rm "$2" || error "cannot remove $2"
    info "removed $2"
    done_count=$((done_count + 1))
    restore "$2"

    [ "$dry_run" = 0 ] || return 0
    while [ "$dir" != "$HOME" ] && rmdir "$dir" 2>/dev/null; do
        restore "$dir"
        dir="${dir%/*}"
    done
}

# system changes stay: a mistake here breaks the login (seat, XDG_RUNTIME_DIR)
print_system() {
    echo
    echo "install.sh also changed the system; undo by hand only what you need:"
    ! command -v distro_undo >/dev/null || distro_undo
}

uninstall_all() {
    [ -f "$list" ] || error "nothing to remove: no $list"

    local k dst dir
    while IFS="$tab" read -r k dst; do
        remove_entry "$k" "$dst"
    done <"$list"
    if [ "$dry_run" = 0 ]; then
        rm "$list"
        # state/shh, then state and .local if they are empty now (like remove_entry)
        dir="${list%/*}"
        while [ "$dir" != "$HOME" ] && rmdir "$dir" 2>/dev/null; do
            dir="${dir%/*}"
        done
    fi

    echo
    echo "done: $done_count removed, $backups restored, $skipped changed or not there"
    print_system
}

# install_input: ~/.config/sway/input from shh config (layouts, switch layout).
# Made here, not in the repo, so always a copy, even with --link
install_input() {
    local layouts toggle old_mode="$mode"
    layouts=$(setting layouts us,ru)
    toggle=$(setting layout_toggle alt_shift_toggle)

    # the file can be edited by hand; a bad value breaks the keyboard in sway
    if ! printf '%s\n' "$layouts" | grep -qx '[a-z]\{2,\}\(,[a-z]\{2,\}\)*'; then
        warn "layouts=$layouts in $shh_config is not like us,ru, using us,ru"
        layouts=us,ru
    fi
    if ! printf '%s\n' "$toggle" | grep -qx '[a-z_]\{1,\}'; then
        warn "layout_toggle=$toggle in $shh_config is not an xkb option, using alt_shift_toggle"
        toggle=alt_shift_toggle
    fi

    printf '%s\n' \
        '# ~/.config/sway/input - keyboard and touchpad' \
        '# made by link.sh from ~/.config/shh/config: change it with shh config, then shh update' \
        '' \
        'input type:keyboard {' \
        "    xkb_layout $layouts" \
        "    xkb_options grp:$toggle" \
        '    xkb_numlock enabled' \
        '}' \
        '' \
        '# libinput has tapping off by default; 1 finger: left, 2 fingers: right' \
        'input type:touchpad {' \
        '    tap enabled' \
        '}' >"$new_list.input"

    mode=copy
    install_file "$new_list.input" "$config_dir/sway/input"
    mode="$old_mode"
}

install_all() {
    [ -d "$dots_path/config" ] || error "run lib/link.sh from the repo, not from $script_dir"

    # this distro's lists ($distro: lib.sh)
    local system_dir="$dots_path/system/$distro"
    local components="$dots_path/components/${distro}_components.txt"
    [ -f "$system_dir/distro.sh" ] && [ -f "$components" ] ||
        error "not supported: ${distro:-unknown distro} (no system/${distro:-DISTRO}/distro.sh or its components file)"

    # files of the parts turned off, " a b ": install_tree skips them
    off_files=" $(off_items "$components" 3 | tr '\n' ' ') ${distro_skip:-} "

    local f k dst first_wall=0
    install_entries "$dots_path/config"  "$config_dir"
    install_input
    install_entries "$dots_path/home"    "$HOME"
    install_entries "$dots_path/scripts" "$bin_dir"
    # scripts/wallpaper takes the newest picture: on the first install make it
    # wallpapers/DISTRO.jpg; later runs keep what you picked with touch
    [ -e "$HOME/wallpapers/$distro.jpg" ] || first_wall=1
    install_tree "$dots_path/wallpapers" "$HOME/wallpapers"
    [ "$first_wall" = 0 ] || [ "$dry_run" = 1 ] || [ ! -e "$HOME/wallpapers/$distro.jpg" ] ||
        touch "$HOME/wallpapers/$distro.jpg"
    # flat in share: shh and installed systems expect these paths
    install_tree "$script_dir/lib.sh"              "$share_dir/lib.sh"
    install_tree "$script_dir/link.sh"             "$share_dir/link.sh"
    install_tree "$system_dir/services.txt"        "$share_dir/services.txt"
    install_tree "$components"                     "$share_dir/components.txt"
    install_tree "$system_dir/packages"            "$share_dir/packages"
    install_tree "$system_dir/distro.sh"           "$share_dir/distro.sh"
    # Our package recipes (KISS only): shh config lists them and kiss_repos copies them.
    [ ! -d "$system_dir/repo" ] || install_tree "$system_dir/repo" "$share_dir/repo"

    # files that left the repo since the last run
    if [ -f "$list" ]; then
        while IFS="$tab" read -r k dst; do
            awk -F "$tab" -v d="$dst" '$2 == d { found = 1 } END { exit !found }' "$new_list" ||
                remove_entry "$k" "$dst"
        done <"$list"
    fi

    if [ "$dry_run" = 0 ]; then
        mkdir -p "${list%/*}"
        mv "$new_list" "$list"
    fi

    echo
    echo "done ($mode): $done_count put in place, $skipped already ok, $backups backed up"

    # easy to miss in the long list above
    if [ -n "$updated" ]; then
        echo
        info "updated from the repo:"
        printf '%s' "$updated"
    fi
    if [ -n "$backed_up" ]; then
        echo
        warn "$backups file(s) replaced by the repo version, yours are kept as .bak:"
        printf '%s' "$backed_up"
    fi
}

# █▄ ▄█ ▄▀▀▄ ▀█▀ █▄  █ 
# █ ▀ █ █▀▀█  █  █ ▀▄█ 
# ▀   ▀ ▀  ▀ ▀▀▀ ▀   ▀ 

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run)   dry_run=1 ;;
        --link)         mode=link ;;
        --copy)         mode=copy ;;
        -u|--uninstall) uninstall=1 ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; error "unknown option: $arg" ;;
    esac
done

[ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

# install.sh shows the logo itself
[ -n "${DOTS_NO_LOGO:-}" ] || logo

[ "$dry_run" = 0 ] || info "dry run: nothing will be changed"

new_list=$(mktemp)
trap 'rm -f "$new_list" "$new_list.input"' EXIT

if [ "$uninstall" = 1 ]; then
    uninstall_all
else
    install_all
fi
