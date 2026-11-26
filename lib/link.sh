#!/bin/sh
# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# █ ▀ ▄▄▄  █  ▄    ▄▄▄ █▄▄  
# █ █ █  █ █▄█    ▀▀▄▄ █  █ 
# ▀ ▀ ▀  ▀ ▀  ▀ ▀ ▀▀▀  ▀  ▀ 
# Put the repo into $HOME: copies, or symlinks with '--link'.
#
#   config/ -> ~/.config   home/ -> ~   scripts/ -> ~/.local/bin
#   wallpapers/ -> ~/wallpapers
#   lib/*.sh, system/DISTRO/ and components/DISTRO_components.txt
#   -> ~/.local/share/shh (flat)
#
# Works file by file. A file that is not ours is renamed to NAME.bak-DATE
# and never deleted. Ours are the files in ~/.local/state/shh/installed.

set -eu

# ▄▀▀▀ █▀▀▀ ▀▀█▀▀ ▀▀█▀▀ ▀█▀ █▄  █ ▄▀▀▀ ▄▀▀▀ 
#  ▀▀▄ █▀▀    █     █    █  █ ▀▄█ █ ▀█  ▀▀▄ 
# ▀▀▀  ▀▀▀▀   ▀     ▀   ▀▀▀ ▀   ▀  ▀▀▀ ▀▀▀  

# Find lib.sh, which lies next to this file: <repo>/lib or ~/.local/share/shh.
#
# 'readlink -f' is for shh, which runs this file through a link in share.
script_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd -P)
# The repo root. From ~/.local/share/shh it is ~/.local/share, which
# install_all refuses.
dots_path=$(cd "$script_dir/.." && pwd -P)

config_dir="$HOME/.config"
bin_dir="$HOME/.local/bin"
share_dir="$HOME/.local/share/shh"
list="$HOME/.local/state/shh/installed"

stamp=$(date +%Y%m%d-%H%M%S)
tab=$(printf '\t')
dry_run=0
show_diff=0
new_tree=0
uninstall=0
done_count=0
skipped=0
backups=0
# For the lists at the end: our files updated, yours moved to .bak.
updated=''
backed_up=''

# Copies by default. Once installed with '--link', it stays links.
mode=copy
[ ! -L "$share_dir/lib.sh" ] || mode=link

[ -f "$script_dir/lib.sh" ] || { echo "lib.sh not found in $script_dir" >&2; exit 1; }
. "$script_dir/lib.sh"

# Load distro_undo for print_system: next to this file in share, or in
# system/DISTRO/ in the repo. Loaded now, as '--uninstall' removes it.
for distro_file in "$script_dir/distro.sh" "$dots_path/system/$distro/distro.sh"; do
    [ ! -f "$distro_file" ] || { . "$distro_file"; break; }
done

backup_msg() { msg "$red" "$sym_bak" "$1"; }

usage() {
    echo "usage: $0 [-n | --dry-run | --diff] [--link | --copy] [-u | --uninstall] [-h | --help]"
    echo "  -n, --dry-run    show what would be done, change nothing"
    echo "  --diff           dry run with content differences; omit unchanged files"
    echo "  --link           symlinks to the repo: edits land in it (for working on the dotfiles)"
    echo "  --copy           copies, the repo can be deleted (the default)"
    echo "  -u, --uninstall  remove what is ours, put the old files back"
    echo "  -h, --help       show this help"
}

# █▀▀▀ █  █ █▄  █ ▄▀▀▀ ▀▀█▀▀ ▀█▀ ▄▀▀▄ █▄  █ ▄▀▀▀ 
# █▀▀  █  █ █ ▀▄█ █      █    █  █  █ █ ▀▄█  ▀▀▄ 
# ▀     ▀▀  ▀   ▀  ▀▀▀   ▀   ▀▀▀  ▀▀  ▀   ▀ ▀▀▀  

nl='
'
records=''
protected_trees=$nl
removed=$nl
stage=''
lock=''
state=${list%/*}
# Only backups recorded by this version can be restored automatically.
backup_list="$state/backups"

exists() { [ -e "$1" ] || [ -L "$1" ]; }

checksum() {
    local sum
    sum=$(sha256sum) || return 1
    printf '%s\n' "${sum%% *}"
}

same() {
    if [ -L "$1" ]; then
        # Append a sentinel to preserve trailing newlines in the link target.
        case "$2" in /*) ;; *) return 1 ;; esac
        [ "$(readlink "$1" && printf .)" = "$2$nl." ]
    else
        [ -f "$1" ] && [ "$(checksum <"$1")" = "$2" ]
    fi
}

old_key() {
    [ -f "$list" ] || return 0
    SHH_DST="$1" awk -F "$tab" '$2 == ENVIRON["SHH_DST"] { print $1; exit }' "$list"
}

# Checkpoint ownership between files. A retry after interruption must not
# adopt a matching private file or remove a backup that has been restored.
save_entry() (
    umask 077
    if [ -f "$list" ]; then
        SHH_DST="$1" awk -F "$tab" '$2 != ENVIRON["SHH_DST"]' "$list" >"$lock/installed"
    else
        : >"$lock/installed"
    fi
    if [ "$#" = 2 ]; then printf '%s\t%s\n' "$2" "$1" >>"$lock/installed"; fi
    mv -fT "$lock/installed" "$list"
)

# Prune only directories created by this installer.
ensure_dir() {
    [ -d "$1" ] && return 0
    ensure_dir "${1%/*}"
    mkdir "$1"
    (umask 077; printf '%s\t%s\n' "$1" directory >>"$backup_list")
}

linked_parent() {
    local dir=${1%/*}
    while [ "$dir" != "$HOME" ]; do
        [ ! -L "$dir" ] || return 0
        dir=${dir%/*}
    done
    return 1
}

# A redirected install root can alias the checkout itself. Replacing an
# entry there would move the source and could create a self-referential link.
check_destination() {
    local dir="${1%/*}" physical
    while [ ! -d "$dir" ]; do
        [ -n "$dir" ] || error "cannot resolve destination: $1"
        dir=${dir%/*}
    done
    physical=$(cd "$dir" && pwd -P) || error "cannot resolve $dir"
    if [ -f "$dots_path/tools/shh" ] && [ -f "$dots_path/lib/link.sh" ]; then
        case "$physical/" in "$dots_path/"*) error "destination inside checkout: $1" ;; esac
        if [ -d "$1" ] && [ ! -L "$1" ]; then
            case "$dots_path/" in "$physical/${1##*/}/"*) error "destination contains checkout: $1" ;; esac
        fi
    fi
    case "$1" in "$state"|"$state"/*) error "reserved state destination: $1" ;; esac
}

# Move the entire entry, including a directory or a dangling symlink.
put_aside() {
    local backup="$1.bak-$stamp" n=0
    check_destination "$1"
    while exists "$backup"; do
        n=$((n + 1))
        backup="$1.bak-$stamp-$n"
    done
    if [ -d "$1" ] || [ -L "$1" ]; then protected_trees="$protected_trees$1$nl"; fi
    if [ "$dry_run" = 0 ]; then
        mv -nT "$1" "$backup" && ! exists "$1" || error "cannot back up $1"
        (umask 077; printf '%s\t%s\n' "$1" "$backup" >>"$backup_list")
    fi
    backup_msg "$1 -> $backup"
    backups=$((backups + 1))
    backed_up="$backed_up  $1 -> $backup
"
}

install_file() {
    local src="$1" dst="$2" k old='' owned=0 rc
    check_destination "$dst"
    local cli_file=0
    case "$src" in "$dots_path"/tools/*) cli_file=1 ;; esac
    if [ "$mode" = link ]; then
        k=$src
    elif [ "$src" = - ]; then
        k=$(printf '%s\n' "$input" | checksum)
    else
        k=$(checksum <"$src")
    fi
    if [ "$new_tree" = 0 ] && exists "$dst"; then
        old=$(old_key "$dst")
        if [ -n "$old" ] && ! linked_parent "$dst" && same "$dst" "$old"; then owned=1; fi
        # The CLI loads only managed tools modules. Back up an identical
        # private entry too, so enabling the feature installs an owned copy or link.
        if { [ "$cli_file" = 0 ] || [ "$owned" = 1 ]; } &&
            same "$dst" "$k" && { [ "$mode" = link ] || [ ! -L "$dst" ]; }; then
            # Identical unmanaged entries stay outside the uninstall manifest.
            [ "$owned" = 0 ] || records="$records$k$tab$dst$nl"
            [ "$show_diff" = 1 ] || ok "$dst"
            skipped=$((skipped + 1))
            return
        fi
        if [ "$show_diff" = 1 ]; then
            if [ -L "$dst" ]; then
                info "replace symlink: $dst -> $(readlink "$dst")"
            elif [ -f "$dst" ]; then
                rc=0
                if [ "$src" = - ]; then
                    # BusyBox diff may spool non-seekable stdin to disk.
                    info "installed $dst (-), generated sway/input (+)"
                    sed 's/^/-/' "$dst" || error "cannot read $dst"
                    printf '%s\n' "$input" | sed 's/^/+/'
                else
                    diff -u "$dst" "$src" || rc=$?
                fi
                [ "$rc" -le 1 ] || error "cannot compare $dst"
            fi
        fi
    fi
    if [ "$dry_run" = 0 ]; then
        ensure_dir "${dst%/*}"
        stage=$(mktemp -d "${dst%/*}/.shh-install.XXXXXX")
        if [ "$mode" = link ]; then
            ln -s "$src" "$stage/file"
        elif [ "$src" = - ]; then
            printf '%s\n' "$input" >"$stage/file"
        else
            cp "$src" "$stage/file"
            same "$stage/file" "$k" || error "source changed during copy: $src"
        fi
    fi
    if [ "$owned" = 1 ] && [ "$dry_run" = 0 ] && ! same "$dst" "$old"; then
        owned=0
    fi
    if [ "$owned" = 1 ]; then
        updated="$updated  $dst$nl"
    elif [ "$new_tree" = 0 ] && exists "$dst"; then
        put_aside "$dst"
    fi
    if [ "$dry_run" = 0 ]; then
        if [ "$cli_file" = 1 ]; then
            ln "$stage/file" "$stage/witness"
            (umask 077; printf '%s\t%s\t%s\n' "$dst" "$k" "$stage" >"$lock/pending")
            mv -fT "$lock/pending" "$state/cli-pending"
        fi
        if [ "$owned" = 1 ]; then
            mv -fT "$stage/file" "$dst"
        else
            mv -nT "$stage/file" "$dst" && ! exists "$stage/file" || error "destination appeared: $dst"
        fi
        save_entry "$dst" "$k"
        if [ "$cli_file" = 1 ]; then rm "$stage/witness"; fi
        rmdir "$stage"
        if [ "$cli_file" = 1 ]; then rm "$state/cli-pending"; fi
        stage=''
    fi
    records="$records$k$tab$dst$nl"
    if [ "$show_diff" = 1 ] && [ "$mode" = link ]; then
        info "link $dst -> $src"
    else
        info "$dst"
    fi
    done_count=$((done_count + 1))
}

# Install a file, or a folder file by file: install_tree SRC DST.
install_tree() {
    local src="$1"
    local dst="$2"
    local new_tree="$new_tree"

    # Skip a part turned off in 'shh config' (components.txt).
    case "$off_files" in *" ${src#"$dots_path/"} "*) return 0 ;; esac
    [ -e "$src" ] || error "source not found: $src"
    if [ ! -d "$src" ]; then
        install_file "$src" "$dst"
        return
    fi

    # A link or a file is where our folder goes (old link.sh linked folders).
    if [ "$new_tree" = 0 ] && { [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -d "$dst" ]; }; }; then
        put_aside "$dst"
        [ "$dry_run" = 0 ] || new_tree=1
    fi
    install_entries "$src" "$dst"
    if [ "$src" = "$dots_path/config/sway" ]; then install_input; fi
}

# Install everything in a folder (hidden files too) into another.
#
# The target folder itself is never moved, even if it is a link
# (~/.config can be one).
install_entries() {
    local f
    for f in "$1"/.[!.]* "$1"/..?* "$1"/*; do
        [ -e "$f" ] || continue
        [ "${f##*/}" != ".gitkeep" ] || continue
        [ "$f" != "$dots_path/scripts/shh" ] || continue
        install_tree "$f" "$2/${f##*/}"
    done
}

# Older unrecorded backups stay available for manual recovery.
restore() {
    local dst bak
    restored=0
    [ -f "$backup_list" ] || return 0
    while IFS="$tab" read -r dst bak; do
        [ "$dst" = "$1" ] || continue
        case "$bak" in "$dst".bak-*) ;; *) continue ;; esac
        case "${bak#"$dst".bak-}" in */*) continue ;; esac
        exists "$bak" || continue
        if [ "$dry_run" = 0 ]; then
            mv -nT "$bak" "$dst" && ! exists "$bak" || error "cannot restore $bak"
            # Consume the record so a later file at the same name stays private.
            SHH_BAK="$bak" awk -F "$tab" '$2 != ENVIRON["SHH_BAK"]' "$backup_list" >"$lock/backups"
            chmod 600 "$lock/backups"
            mv -fT "$lock/backups" "$backup_list"
        fi
        protected_trees="$protected_trees$dst$nl"
        restored=1
        backup_msg "$bak -> $dst"
        backups=$((backups + 1))
        return
    done <"$backup_list"
}

# Model rmdir during preview, including children already scheduled for removal.
preview_empty() {
    local child
    for child in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        exists "$child" || continue
        case "$removed" in *"$nl$child$nl"*) ;; *) return 1 ;; esac
    done
    return 0
}

# Delete DST if it is still ours, then the empty folders above it.
remove_entry() {
    local dir="${2%/*}" parent="$2" restored
    while [ "$parent" != "$HOME" ]; do
        case "$protected_trees" in *"$nl$parent$nl"*) return 0 ;; esac
        parent=${parent%/*}
    done

    if linked_parent "$2"; then
        warn "kept: symlink parent ($2)"
        skipped=$((skipped + 1))
        return
    fi
    if [ ! -e "$2" ] && [ ! -L "$2" ]; then
        skipped=$((skipped + 1))
        return
    fi
    check_destination "$2"
    if ! same "$2" "$1"; then
        warn "changed since install, kept: $2"
        skipped=$((skipped + 1))
        return
    fi

    if [ "$dry_run" = 0 ]; then
        save_entry "$2"
        if ! same "$2" "$1"; then
            warn "changed during removal, kept: $2"
            return 0
        fi
        rm "$2" || error "cannot remove $2"
    fi
    info "removed $2"
    done_count=$((done_count + 1))
    restore "$2"
    [ "$restored" = 0 ] || return 0
    if [ "$dry_run" = 1 ]; then removed="$removed$2$nl"; fi
    while [ "$dir" != "$HOME" ] && [ -f "$backup_list" ] &&
        grep -Fxq -- "$dir${tab}directory" "$backup_list"; do
        if [ "$dry_run" = 1 ]; then
            preview_empty "$dir" || break
        else
            rmdir "$dir" 2>/dev/null || break
            SHH_DIR="$dir" awk -F "$tab" '$1 != ENVIRON["SHH_DIR"] || $2 != "directory"' "$backup_list" >"$lock/backups"
            chmod 600 "$lock/backups"
            mv -fT "$lock/backups" "$backup_list"
        fi
        restore "$dir"
        [ "$restored" = 0 ] || break
        if [ "$dry_run" = 1 ]; then removed="$removed$dir$nl"; fi
        dir="${dir%/*}"
    done
}

# Print the system changes. They stay: a mistake here breaks the login
# (seat, XDG_RUNTIME_DIR).
print_system() {
    echo
    echo "install.sh also changed the system; undo by hand only what you need:"
    ! command -v distro_undo >/dev/null || distro_undo
}

uninstall_all() {
    [ -f "$list" ] || error "nothing to remove: no $list"

    local k dst
    while IFS="$tab" read -r k dst || [ -n "$k$dst" ]; do
        remove_entry "$k" "$dst"
    done <"$list"
    if [ "$dry_run" = 0 ]; then
        rm "$list"
        if [ -f "$backup_list" ] && [ ! -s "$backup_list" ]; then rm "$backup_list"; fi
    fi

    echo
    echo "done: $done_count removed, $backups restored, $skipped changed or not there"
    print_system
}

# Make ~/.config/sway/input from 'shh config' (layouts, switch layout).
#
# The file is made here, not kept in the repo, so it is always a copy,
# even with '--link'.
install_input() {
    local layouts toggle mode=copy input
    layouts=$(setting layouts us,ru)
    toggle=$(setting layout_toggle alt_shift_toggle)

    # The config can be edited by hand, and a bad value breaks the keyboard
    # in sway.
    if ! printf '%s\n' "$layouts" | grep -qx '[a-z]\{2,\}\(,[a-z]\{2,\}\)*'; then
        warn "layouts=$layouts in $shh_config is not like us,ru, using us,ru"
        layouts=us,ru
    fi
    if ! printf '%s\n' "$toggle" | grep -qx '[a-z_]\{1,\}'; then
        warn "layout_toggle=$toggle in $shh_config is not an xkb option, using alt_shift_toggle"
        toggle=alt_shift_toggle
    fi

    input=$(printf '%s\n' \
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
        '}')
    install_file - "$config_dir/sway/input"
}

install_all() {
    [ -d "$dots_path/config" ] || error "run lib/link.sh from the repo, not from $script_dir"

    # The lists of this distro ('$distro' is set in lib.sh).
    local system_dir="$dots_path/system/$distro"
    local components="$dots_path/components/${distro}_components.txt"
    [ -f "$system_dir/distro.sh" ] && [ -f "$components" ] ||
        error "not supported: ${distro:-unknown distro} (no system/${distro:-DISTRO}/distro.sh or its components file)"

    # The files of the parts turned off, as " a b ". install_tree skips them.
    off_files=" $(off_items "$components" 3 | tr '\n' ' ') ${distro_skip:-} "

    local f k dst first_wall=0
    local cli_modules='tui config components update diagnostics debloater' header
    [ -f "$dots_path/tools/shh" ] && [ ! -L "$dots_path/tools/shh" ] &&
        [ -x "$dots_path/tools/shh" ] && sh -n "$dots_path/tools/shh" || error "invalid CLI entry point"
    for f in $cli_modules; do
        case "$off_files" in *" tools/$f.sh "*) continue ;; esac
        [ -f "$dots_path/tools/$f.sh" ] && [ ! -L "$dots_path/tools/$f.sh" ] &&
            IFS= read -r header <"$dots_path/tools/$f.sh" &&
            [ "$header" = "# Shhware $f API 1" ] && sh -n "$dots_path/tools/$f.sh" ||
            error "invalid CLI module: $f"
    done
    linked_parent "$share_dir/tools" && error "symlink parent for CLI modules"
    install_entries "$dots_path/config"  "$config_dir"
    [ -d "$dots_path/config/sway" ] || install_input
    install_entries "$dots_path/home"    "$HOME"
    install_entries "$dots_path/scripts" "$bin_dir"
    # scripts/wallpaper shows the newest picture. On the first install that
    # must be wallpapers/DISTRO.jpg, later runs keep what you picked.
    [ -e "$HOME/wallpapers/$distro.jpg" ] || first_wall=1
    install_tree "$dots_path/wallpapers" "$HOME/wallpapers"
    [ "$mode" = copy ] || first_wall=0
    [ "$first_wall" = 0 ] || [ "$dry_run" = 1 ] || [ ! -e "$HOME/wallpapers/$distro.jpg" ] ||
        touch "$HOME/wallpapers/$distro.jpg"
    # Flat in share: shh and installed systems expect these paths.
    install_tree "$script_dir/lib.sh"              "$share_dir/lib.sh"
    install_tree "$script_dir/link.sh"             "$share_dir/link.sh"
    install_tree "$system_dir/services.txt"        "$share_dir/services.txt"
    install_tree "$components"                     "$share_dir/components.txt"
    install_tree "$system_dir/packages"            "$share_dir/packages"
    install_tree "$system_dir/distro.sh"           "$share_dir/distro.sh"
    # Our package recipes (KISS only): 'shh config' lists them and kiss_repos
    # copies them.
    [ ! -d "$system_dir/repo" ] || install_tree "$system_dir/repo" "$share_dir/repo"

    if [ -L "$share_dir/tools" ] || { exists "$share_dir/tools" && [ ! -d "$share_dir/tools" ]; }; then
        put_aside "$share_dir/tools"
        [ "$dry_run" = 0 ] || new_tree=1
    fi
    for f in $cli_modules; do
        install_tree "$dots_path/tools/$f.sh" "$share_dir/tools/$f.sh"
    done
    new_tree=0
    install_tree "$dots_path/tools/shh" "$bin_dir/shh"

    # Remove the files that left the repo since the last run.
    if [ -f "$list" ]; then
        while IFS="$tab" read -r k dst || [ -n "$k$dst" ]; do
            case "$records" in
                *"$tab$dst$nl"*) ;;
                *) remove_entry "$k" "$dst" ;;
            esac
        done <"$list"
    fi

    if [ "$dry_run" = 0 ]; then
        (umask 077; printf '%s' "$records" >"$lock/installed")
        mv -fT "$lock/installed" "$list"
    fi

    echo
    echo "done ($mode): $done_count put in place, $skipped already ok, $backups backed up"

    # Easy to miss in the long list above.
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
        --diff)         dry_run=1; show_diff=1 ;;
        --link)         mode=link ;;
        --copy)         mode=copy ;;
        -u|--uninstall) uninstall=1 ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; error "unknown option: $arg" ;;
    esac
done

if [ "$mode" = link ] && [ "$dots_path" = "${SHH_TEMP_CHECKOUT:-}" ]; then
    error "link mode requires a persistent checkout"
fi
[ "$(id -u)" -ne 0 ] || error "do not run as root, run as your user"

# install.sh shows the logo itself.
[ -n "${DOTS_NO_LOGO:-}" ] || logo

[ "$dry_run" = 0 ] || info "dry run: nothing will be changed"

# Validate the line-oriented manifest before touching any destination.
case "$HOME" in /*) ;; *) error "HOME must be absolute" ;; esac
case "$HOME:$dots_path" in *"$tab"*|*"$nl"*) error "tab or newline in path" ;; esac
case "$HOME/" in *//*|*/../*|*/./*) error "unsafe HOME: $HOME" ;; esac
if [ "$uninstall" = 0 ]; then
    for tree in "$dots_path/config" "$dots_path/home" "$dots_path/scripts" "$dots_path/wallpapers" "$dots_path/system/$distro"; do
        [ -d "$tree" ] || continue
        invalid=$(find -L "$tree" \( -name "*$tab*" -o -name "*$nl*" -o \( ! -type d ! -type f \) \) -print) || error "cannot inspect $tree"
        [ -z "$invalid" ] || error "unsupported name or source type under $tree: $invalid"
    done
fi
if linked_parent "$list"; then error "symlink parent for installation state: $state"; fi
if [ "$dry_run" = 1 ] && exists "$state/.link-lock"; then
    error "preview unavailable during an active or interrupted link operation: $state/.link-lock"
fi
if [ "$dry_run" = 0 ]; then
    mkdir -p "$state"
    lock="$state/.link-lock"
    mkdir -m 700 "$lock" || error "another or interrupted link operation: $lock"
    trap 'if [ -n "$stage" ] && [ ! -e "$state/cli-pending" ]; then rm -f "$stage/file" "$stage/witness"; rmdir "$stage"; fi
        rm -f "$lock/installed" "$lock/backups" "$lock/pending"
        rmdir "$lock"' EXIT
    trap 'exit 1' HUP INT TERM
fi

for file in "$list" "$backup_list"; do
    [ ! -L "$file" ] && { [ ! -e "$file" ] || [ -f "$file" ]; } || error "unsafe state file: $file"
done
if [ -f "$list" ]; then
    while IFS= read -r row || [ -n "$row" ]; do
        k=${row%%"$tab"*}
        dst=${row#*"$tab"}
        case "$dst" in "$HOME"/*) ;; *) error "invalid manifest path: $dst" ;; esac
        case "$dst" in "$state"|"$state"/*) error "reserved manifest path: $dst" ;; esac
        case "$dst/" in *"$tab"*|*//*|*/../*|*/./*) error "invalid manifest path: $dst" ;; esac
        [ -n "$k" ] && [ "$dst" != "$row" ] || error "invalid manifest record"
    done <"$list"
fi

# Recover ownership only when the destination is still the very same staged inode.
if exists "$state/cli-pending"; then
    [ "$dry_run" = 0 ] || error "interrupted CLI installation; retry before preview"
    [ -f "$state/cli-pending" ] && [ ! -L "$state/cli-pending" ] &&
        IFS="$tab" read -r dst k pending <"$state/cli-pending" || error "invalid CLI checkpoint"
    case "$dst" in
        "$bin_dir/shh"|"$share_dir/tools/"config.sh|"$share_dir/tools/"tui.sh|"$share_dir/tools/"components.sh|"$share_dir/tools/"update.sh|"$share_dir/tools/"diagnostics.sh|"$share_dir/tools/"debloater.sh) ;;
        *) error "invalid CLI checkpoint destination" ;;
    esac
    [ "${pending%/*}" = "${dst%/*}" ] || error "invalid staging directory"
    case "${pending##*/}" in .shh-install.??????) ;; *) error "invalid staging directory" ;; esac
    linked_parent "$pending/witness" && error "symlink parent for CLI checkpoint"
    if exists "$dst" && exists "$pending/witness" &&
        installed_inode=$(stat -c '%d:%i' "$dst") && staged_inode=$(stat -c '%d:%i' "$pending/witness") &&
        [ "$installed_inode" = "$staged_inode" ] && same "$dst" "$k"; then
        save_entry "$dst" "$k"
    fi
    rm -f "$pending/file" "$pending/witness"
    [ ! -d "$pending" ] || rmdir "$pending"
    rm "$state/cli-pending"
fi

if [ "$uninstall" = 1 ]; then
    uninstall_all
else
    install_all
fi
