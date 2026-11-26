# Shhware debloater API 1
# Inspect local package metadata and files. Candidate records live in this shell only.

deb_nl='
'
deb_categories='packages|Orphan packages
duplicates|Duplicate binaries
cache|Package cache
builds|Build leftovers
links|Broken symlinks
apps|Application leftovers
backups|Old backups
large|Large files'

# Keep printable paths readable. Octal escapes round-trip through printf '%b'.
deb_escape() {
    case "$1" in
        *[!\ -~]*|*\\*) printf %s "$1" | od -An -v -tu1 | awk '{
            for(i=1;i<=NF;i++) if ($i>=32 && $i<=126 && $i!=92) printf "%c",$i
                else printf "\\0%03o",$i
        }' ;;
        *) printf %s "$1" ;;
    esac
}
deb_pkg_name() { case "$1" in ''|-*|*[!a-zA-Z0-9_.+-]*) return 1 ;; esac; }

deb_notice() { printf '!%s\t%s\t%s\n' "${2:-0}" "$deb_category" "$1"; }

# Never descend through a pseudo-filesystem or use the filesystem root as a scan root.
deb_directory() {
    local phys fs
    case "$1" in /*) ;; *) deb_notice 'UNKNOWN: non-absolute directory' 1; return 1 ;; esac
    if [ ! -d "$1" ]; then
        local parent=$1
        while [ ! -e "$parent" ] && [ ! -L "$parent" ]; do parent=${parent%/*}; [ -n "$parent" ] || parent=/; done
        if [ ! -d "$parent" ] || [ ! -x "$parent" ]; then deb_notice 'UNKNOWN: inaccessible directory' 1; fi
        return 1
    fi
    phys=$(cd -P "$1" && pwd -P && printf .) || { deb_notice 'UNKNOWN: inaccessible directory' 1; return 1; }
    phys=${phys%"$deb_nl."}
    fs=$(stat -f -c %t "$phys" 2>/dev/null) || fs=unknown
    case "$phys/" in //|/proc/*|/sys/*|/dev/*) deb_notice 'NOT TESTED: excluded scan root'; return 1 ;; esac
    case "$fs" in 9fa0|62656572|1cd1|unknown) deb_notice 'NOT TESTED: excluded filesystem'; return 1 ;; esac
    [ -r "$phys" ] && [ -x "$phys" ] || { deb_notice 'UNKNOWN: directory permissions' 1; return 1; }
}

deb_stamp() { stat -c '%d:%i:%f:%s:%y:%z' "$1" 2>/dev/null; }

deb_file() {
    local path=$1 reason=$2 risk=$3 owner=${4:-UNKNOWN} size stamp
    stamp=$(deb_stamp "$path") || { deb_notice 'UNKNOWN: object changed or inaccessible' 1; return; }
    if [ -d "$path" ] && [ ! -L "$path" ]; then size=UNKNOWN
    else size=$(stat -c %s "$path" 2>/dev/null) || size=UNKNOWN; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$deb_category" "$(deb_escape "$path")" "$reason" "$size" "$(deb_escape "$owner")" "$risk" "$stamp"
}

deb_protection() (
    local name parts files services group default pkg csv
    for pkg in $deb_base_packages ${build_tools:-} gcc clang make cmake meson ninja samurai binutils pkgconf; do printf '%s\tBase system or toolchain\n' "$pkg"; done
    for csv in "$packages_dir"/*.csv; do
        awk -F, '/^[^#]*,/ && $2!="" {print $2 "\tShhware package list"}' "$csv" || return 1
    done
    set -f
    [ -r "$components_file" ] || return 1
    while IFS='|' read -r name parts files services group default; do
        case "$name" in ''|'#'*) continue ;; esac
        part_on "$name" "$group" "$default" || continue
        for pkg in $parts; do printf '%s\tActive component %s\n' "$pkg" "$name"; done
    done <"$components_file"
    for pkg in $(setting debloater_protected '' | tr , ' '); do
        deb_pkg_name "$pkg" || return 1
        printf '%s\tUser protection\n' "$pkg"
    done
    local native
    native=$(deb_native_protection) || return 1
    for pkg in $native; do
        deb_pkg_name "$pkg" || return 1
        printf '%s\tPackage manager protection\n' "$pkg"
    done
)

deb_risk() {
    local why
    case "$1" in linux|linux-*|linux[0-9]*|grub*|runit*|s6-*|gcc*|musl*|glibc*) echo 'Protected: system or toolchain'; return ;; esac
    why=$(printf '%s\n' "$deb_protected" | awk -F '\t' -v p="$1" '$1==p {print $2; exit}')
    if [ -n "$why" ]; then printf 'Protected: %s\n' "$why"
    elif [ "$deb_protection_ok" = 0 ]; then echo 'Blocked: incomplete protection data'
    else echo 'Review native transaction'; fi
}

deb_packages() {
    local leaves pkg
    [ "$deb_db_ok" = 1 ] || { deb_notice 'UNKNOWN: installed database unavailable' 1; return; }
    leaves=$(deb_orphans 2>/dev/null) || { deb_notice 'UNKNOWN: orphan query failed' 1; return; }
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        deb_pkg_name "$pkg" && printf '%s\n' "$deb_installed" | grep -Fxq -- "$pkg" || {
            deb_notice 'UNKNOWN: unexpected package identifier' 1; continue
        }
        printf '%s\t%s\t%s\tUNKNOWN\t%s\t%s\tpackage\n' "$deb_category" "$pkg" "$deb_package_reason" "$pkg" "$(deb_risk "$pkg")"
    done <<PACKAGES
$leaves
PACKAGES
}

deb_binary_index() {
    local rest="$deb_search_path:" dir known='' key path origin=PATH
    while :; do
        case "$rest" in
            *:*) dir=${rest%%:*}; rest=${rest#*:} ;;
            '') case "$origin" in PATH) origin=local; dir=$HOME/.local/bin ;; local) origin=system; dir=/usr/local/bin ;; *) break ;; esac ;;
        esac
        case "$dir" in /*) ;; *) dir=$PWD/${dir:-.} ;; esac
        deb_directory "$dir" || continue
        key=$(stat -L -c '%d:%i' "$dir") || { deb_notice 'UNKNOWN: PATH directory changed' 1; continue; }
        case " $known " in *" $key "*) continue ;; esac
        known="$known $key"
        for path in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
            [ -f "$path" ] && [ -x "$path" ] || continue
            case "$path" in
                *[!\ -~]*|*\\*) printf '%s\t%s\t%s\n' "$(deb_escape "${path##*/}")" "$(deb_escape "$path")" "$origin" ;;
                *) printf '%s\t%s\t%s\n' "${path##*/}" "$path" "$origin" ;;
            esac
        done
    done
}

deb_duplicates() {
    local matches name encoded origin path active reference version identity seen='' previous='' reason owner
    matches=$(deb_binary_index | awk -F '\t' '
        /^![01]\t/ && $3!="PATH" && $3!="local" && $3!="system" {print; next}
        {rows[NR]=$0; names[NR]=$1; count[$1]++}
        END {for(i=1;i<=NR;i++) if(count[names[i]]>1) print rows[i]}' | sort -s -t "$tab" -k1,1)
    while IFS="$tab" read -r name encoded origin; do
        [ -n "$name" ] || continue
        case "$name:$origin" in '!0:NOT TESTED:'*|'!1:UNKNOWN:'*) printf '%s\t%s\t%s\n' "$name" "$encoded" "$origin"; continue ;; esac
        path=$(printf '%b.' "$encoded"); path=${path%.}
        identity=$(stat -L -c '%d:%i' "$path" 2>/dev/null) || { deb_notice 'UNKNOWN: executable changed' 1; continue; }
        if [ "$previous" != "$name" ]; then seen=''; active=''; reference=''; previous=$name; fi
        if [ "$origin" != PATH ]; then reason='Outside PATH'
        elif [ -z "$active" ]; then active=$path; reason='Active in PATH'
        else reason='Shadowed in PATH'; fi
        if [ -L "$path" ]; then reason="$reason; symlink"
        else
            case " $seen " in *" $identity "*) reason="$reason; same inode (hardlink or alias)" ;;
                *) reason="$reason; independent file"
                   if [ -n "$reference" ]; then
                       if cmp -s "$reference" "$path"; then reason="$reason; identical contents"
                       elif [ "$?" = 1 ]; then reason="$reason; different contents"; fi
                   else reference=$path; fi ;;
            esac
            seen="$seen $identity"
        fi
        owner=$(deb_owner "$path" 2>/dev/null) || owner=UNKNOWN
        version=UNKNOWN
        case "$owner" in ''|Unowned|UNKNOWN) ;; *)
            if deb_pkg_name "$owner"; then version=$(deb_package_version "$owner" 2>/dev/null) || version=UNKNOWN; fi ;;
        esac
        deb_file "$path" "$reason; package version: $(deb_escape "${version:-UNKNOWN}")" 'Executable may be in use' "$owner"
    done <<MATCHES
$matches
MATCHES
}

deb_cache_dir() {
    local root=$1 path reason
    deb_directory "$root" || return 0
    for path in "$root"/* "$root"/.[!.]* "$root"/..?*; do
        [ -f "$path" ] && [ ! -L "$path" ] || continue
        case "$path" in *.part|*.partial) reason='Partial download; activity unknown' ;;
            *) reason=$(deb_archive_reason "$path") ;; esac
        deb_file "$path" "$reason" 'May be needed for recovery or an active download'
    done
}

deb_links() {
    local root=$HOME/.local/bin path target owner failure reason
    deb_directory "$root" || return 0
    for path in "$root"/* "$root"/.[!.]* "$root"/..?*; do
        [ -L "$path" ] && [ ! -e "$path" ] || continue
        target=$(readlink "$path" && printf .) || { deb_notice 'UNKNOWN: link changed' 1; continue; }
        target=${target%"$deb_nl."}
        owner=$(deb_owner "$path" 2>/dev/null) || owner=UNKNOWN
        failure=$(stat -L "$path" 2>&1) && continue
        case "$failure" in
            *'No such file or directory') reason='Missing target' ;;
            *'Permission denied') reason='Inaccessible target' ;;
            *'Too many levels of symbolic links') reason='Symlink loop' ;;
            *) reason='Unresolved target' ;;
        esac
        deb_file "$path" "$reason: $(deb_escape "$target")" 'Target may be inaccessible, offline or cyclic' "$owner"
    done
}

deb_apps() {
    local root=${XDG_CACHE_HOME:-$HOME/.cache} pkg
    [ "$deb_db_ok" = 1 ] || { deb_notice 'UNKNOWN: installed database unavailable' 1; return; }
    deb_directory "$root" || return 0
    for pkg in firefox mpv; do
        [ -d "$root/$pkg" ] && [ ! -L "$root/$pkg" ] || continue
        printf '%s\n' "$deb_installed" | grep -Fxq "$pkg" && continue
        deb_file "$root/$pkg" 'Matching package absent; application cache exists' 'Manual installations may still use these data'
    done
}

deb_backups() {
    local ledger=$HOME/.local/state/shh/backups src bak extra mtime age
    [ -e "$ledger" ] || return 0
    [ -f "$ledger" ] && [ ! -L "$ledger" ] && [ -r "$ledger" ] || { deb_notice 'UNKNOWN: backup ledger unavailable' 1; return; }
    while IFS="$tab" read -r src bak extra || [ -n "$src" ]; do
        [ "$bak" != directory ] || continue
        case "$src" in "$HOME"/*) ;; *) deb_notice 'UNKNOWN: invalid backup record' 1; continue ;; esac
        case "$bak" in "$src".bak-*) ;; *) deb_notice 'UNKNOWN: invalid backup destination' 1; continue ;; esac
        case "$bak/" in */../*|*/./*) deb_notice 'UNKNOWN: unsafe backup path' 1; continue ;; esac
        [ -z "$extra" ] || { deb_notice 'UNKNOWN: ambiguous backup record' 1; continue; }
        mtime=$(stat -c %Y "$bak" 2>/dev/null) || { deb_notice "UNKNOWN: recorded backup unavailable: $(deb_escape "$bak")" 1; continue; }
        age=$(( ($(date +%s) - mtime) / 86400 ))
        deb_file "$bak" "Shhware restore copy ($age days since modification) for $(deb_escape "$src")" 'Preserve for system recovery'
    done <"$ledger"
}

deb_large_walk() {
    local path dev size
    for path in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [ ! -L "$path" ] && [ -e "$path" ] || continue
        dev=$(stat -c %d "$path") || { deb_notice 'UNKNOWN: inaccessible entry' 1; continue; }
        [ "$dev" = "$2" ] || continue
        if [ -d "$path" ]; then
            deb_directory "$path" && deb_large_walk "$path" "$2"
        elif [ -f "$path" ]; then
            size=$(stat -c %s "$path") || { deb_notice 'UNKNOWN: size unavailable' 1; continue; }
            [ "$size" -lt 104857600 ] || deb_file "$path" 'At least 100 MiB' 'Size alone does not indicate disuse'
        fi
    done
    return 0
}
deb_large() {
    if [ -L "$deb_large_root" ]; then deb_notice 'NOT TESTED: selected root is a symlink'; return; fi
    deb_directory "$deb_large_root" || return 0
    deb_large_walk "$deb_large_root" "$(stat -L -c %d "$deb_large_root")"
}

deb_scan() {
    local key deb_category output
    deb_records='' deb_selected=' ' deb_partial=0 deb_scanned=1
    deb_protected='' deb_installed='' deb_db_ok=0 deb_protection_ok=0
    case " $* " in *' packages '*|*' apps '*)
        if deb_installed=$(deb_installed_packages 2>/dev/null); then deb_db_ok=1; fi
        ;;
    esac
    while IFS='|' read -r key deb_category; do
        case " $* " in *" $key "*) ;; *) continue ;; esac
        if [ "$key" = packages ]; then
            if deb_protected=$(deb_protection 2>/dev/null); then deb_protection_ok=1
            else deb_records="!1$tab$deb_category${tab}UNKNOWN: incomplete protection data$deb_nl"; fi
        fi
        if ! output=$("deb_$key" 2>/dev/null); then
            output="${output:+$output$deb_nl}!1$tab$deb_category${tab}UNKNOWN: scan unavailable"
        fi
        deb_records="$deb_records${output:+$output$deb_nl}"
    done <<CATEGORIES
$deb_categories
CATEGORIES
    case "$deb_nl$deb_records" in *"$deb_nl!1$tab"*) deb_partial=1 ;; esac
}

deb_format() {
    awk -F '\t' '
        /^![01]\t/ {print $2 " — " $3; next}
        NF==7 {n=split($2,p,"/"); print "Name: " p[n] "\n" ($7=="package" ? "Package: " : "Path: ") $2
            print "Category: " $1 "\nReason: " $3 "\nSize: " $4 ($4=="UNKNOWN" ? "" : " bytes")
            print "Package owner: " $5 "\nRisk: " $6 "\n"; count++}
        END {if(!count) print "No candidates found in completed checks."}'
}

deb_show() {
    printf '%s\n' "$2" | fzf --no-input --border-label=" $1 " --header='Esc: back' >/dev/null || :
}

deb_plan() {
    local id category encoded reason size owner risk stamp path pkg native current
    set --
    if [ "$deb_selected" = ' ' ]; then echo 'No actions selected'; return; fi
    for id in $deb_selected; do
        IFS="$tab" read -r category encoded reason size owner risk stamp <<ROW
$(printf '%s' "$deb_records" | sed -n "${id}p")
ROW
        if [ "$stamp" != package ]; then
            path=$(printf '%b.' "$encoded"); path=${path%.}
            current=$(deb_stamp "$path") || current=''
            if [ "$stamp" != "$current" ]; then printf 'Blocked (changed since scan): %s\n' "$encoded"
            else printf 'Review only: %s — %s\n' "$encoded" "$risk"; fi
        elif [ "$risk" != 'Review native transaction' ]; then printf 'Blocked: %s — %s\n' "$encoded" "$risk"
        else set -- "$@" "$encoded"; fi
    done
    [ "$#" -gt 0 ] || return 0
    printf 'Requested packages: %s\n' "$*"
    native=$(deb_native_plan "$@" 2>/dev/null) && [ -n "$native" ] || {
        echo 'Blocked: complete native transaction unavailable'; return
    }
    for pkg do
        printf '%s\n' "$native" | grep -Fxq -- "$pkg" || { echo 'Blocked: incomplete transaction'; return; }
    done
    local blocked=0
    while IFS= read -r pkg; do
        deb_pkg_name "$pkg" || { echo 'Blocked: ambiguous transaction'; return; }
        risk=$(deb_risk "$pkg")
        printf 'Preview removal: %s — %s\n' "$pkg" "$risk"
        [ "$risk" = 'Review native transaction' ] || blocked=1
    done <<PACKAGES
$native
PACKAGES
    if [ "$blocked" = 1 ]; then echo 'Blocked: transaction includes protected or unverified packages'; fi
}

deb_review_lines() {
    line plan '' 'Preview plan' '>'
    printf '%s' "$deb_records" | DEB_SELECTED="$deb_selected" awk -F '\t' '
        /^![01]\t/ {print "notice" NR "\t    " $2 " — " $3; next}
        NF==7 {print NR "\t" (index(ENVIRON["DEB_SELECTED"]," " NR " ") ? "[x] " : "[ ] ") $2 "  " $1}'
}

deb_review_act() {
    local id=$1 row action
    case "$id" in
        plan) deb_show 'Cleanup plan' "$(deb_plan)"; return ;;
        notice*) return ;;
        ''|*[!0-9]*) return ;;
    esac
    row=$(printf '%s' "$deb_records" | sed -n "${id}p")
    case "$deb_selected" in *" $id "*) action='Remove from preview' ;; *) action='Add to preview' ;; esac
    if printf 'select\t%s\n' "$action" | menu --border-label=' Candidate ' \
        --header="$(printf '%s\n' "$row" | deb_format)" >/dev/null; then
        case "$deb_selected" in
            *" $id "*) deb_selected="${deb_selected%" $id "*} ${deb_selected#*" $id "}" ;;
            *) deb_selected="$deb_selected$id " ;;
        esac
    fi
}

deb_lines() {
    local key label box label_width=20
    line scan '' 'Scan system' '>'
    line review '' 'Review candidates' '>'
    line protected '' 'Protected packages' '>'
    line history '' 'Cleanup history' '>'
    printf -- '-\t\n'
    while IFS='|' read -r key label; do
        case "$deb_enabled" in *" $key "*) box='[x]' ;; *) box='[ ]' ;; esac
        line "$key" "$box" "$label" ''
    done <<CATEGORIES
$deb_categories
CATEGORIES
}

deb_history() {
    local log=$HOME/.local/state/shh/debloater/history entry
    if [ ! -e "$log" ] && [ ! -L "$log" ]; then echo 'No cleanup history'; return; fi
    [ -f "$log" ] && [ ! -L "$log" ] && [ -r "$log" ] || { echo 'Cleanup history unavailable'; return 1; }
    while IFS= read -r entry || [ -n "$entry" ]; do deb_escape "$entry"; printf '\n'; done <"$log"
}

deb_act() {
    local choice rows
    case "$1" in
        scan)
            deb_scan $deb_enabled
            if [ "$deb_partial" = 1 ]; then note='Partial scan. Review candidates for details.'
            else note='Scan complete. Review candidates.'; fi ;;
        review)
            if [ "$deb_scanned" = 0 ]; then note='Scan the system first'; return; fi
            loop 'Review candidates' 'Enter: details   Esc: back' deb_review_lines deb_review_act ;;
        protected)
            rows=$(deb_protection 2>/dev/null) || rows="$rows$deb_nl Protection data incomplete"
            deb_show 'Protected packages' "$rows" ;;
        history) deb_show 'Cleanup history' "$(deb_history)" ;;
        *) case "$deb_enabled" in
            *" $1 "*) deb_enabled="${deb_enabled%" $1 "*} ${deb_enabled#*" $1 "}" ;;
            *) if [ "$1" = large ]; then
                   choice=$(choose 'Large files (100 MiB)' "downloads${tab}Downloads
cache${tab}Application cache")
                   case "$choice" in downloads) deb_large_root=$HOME/Downloads ;; cache) deb_large_root=${XDG_CACHE_HOME:-$HOME/.cache} ;; *) return ;; esac
               fi
               deb_enabled="$deb_enabled$1 " ;;
        esac ;;
    esac
}

deb_main() {
    local deb_enabled=' packages duplicates cache builds links ' deb_records='' deb_selected=' '
    local deb_scanned=0 deb_partial=0 deb_large_root='' deb_installed='' deb_protected='' deb_protection_ok=0 deb_db_ok=0
    local art
    case "${1:-}" in
        --help)
            printf '%s\n' 'usage: shh debloater [OPTION]' \
                '  --scan         scan the five default categories' \
                '  --packages     inspect orphan candidates' \
                '  --duplicates   inspect executable paths' \
                '  --cache        inspect package caches' \
                '  --dry-run      select and preview in a terminal' \
                '  --history      read cleanup history' \
                '  --help         show this help'
            return ;;
        --history) deb_history; return ;;
        --scan|--packages|--duplicates|--cache)
            case "$1" in --scan) deb_scan $deb_enabled ;; *) deb_scan "${1#--}" ;; esac
            printf '%s' "$deb_records" | deb_format
            return "$deb_partial" ;;
        --dry-run) if [ ! -t 0 ] || [ ! -t 1 ]; then echo 'No actions selected'; return; fi ;;
    esac
    [ -t 0 ] && [ -t 1 ] && command -v fzf >/dev/null || { echo 'Interactive terminal and fzf required; use --scan' >&2; return 1; }
    if [ -z "${FZF_DEFAULT_OPTS_FILE:-}" ] && [ -f "$repo/config/fzf/fzfrc" ]; then
        export FZF_DEFAULT_OPTS_FILE="$repo/config/fzf/fzfrc"
    fi
    if [ "${1:-}" = --dry-run ]; then
        deb_scan $deb_enabled
        loop 'Review candidates' 'Enter: details   Esc: finish preview' deb_review_lines deb_review_act
        deb_plan
        return "$deb_partial"
    fi
    art=$(deb_banner)
    loop 'shh debloater' 'Enter: open or toggle   Esc: done' deb_lines deb_act "$art"
}

deb_banner() {
    local cols
    cols=$(menu_columns)
    if [ "${cols:-0}" -eq 0 ] || [ "$cols" -ge 83 ]; then
        banner_block "$cols" 79 <<'ART'
     ██▓            ██▓      ▓██                       ▄██
 ▄██▄██▒   ▄███▄   ▓██▒▄██▄  ▒██    ▄████▄    ▄████▄  ▓█████▒   ▄███▄    ██▄██▄
▓██▀ ▀██ ▓██▀ ▀██▒ ▒██▀  ▀██ ▒██░  ▒██▀ ▀██▒  ▄▄▀▓██   ▓██    ▓██▀ ▀██▒ ▓██▀ ▀▀
▒██  ▓██ ▒███▀▀▀   ░██▄  ▄██ ░██░  ▒██   ██░ ▓██  ██   ▒██    ▒███▀▀▀   ▓██
░▀███▓█▒ ░▒████▄▒  ░▓█▒███▀  ░▓██▄ ░▀████▓▀  ░▀███▓█▄  ░▀██▄▒ ░▒████▄▒  ▒██░
░ ░▓░ ░  ░░ ▒░ ░   ░▒▓▒░ ░   ░▒▓ ░ ░ ▒░▒░▒░  ░ ░▓░ ░    ▒ ░░  ░░ ▒░ ░   ░ ▒▓
 ░ ▒  ░   ░ ░  ░   ▒░▒ ░ ░    ░▒     ░ ▒ ▒░   ░ ▒  ░    ░ ░    ░ ░  ░     ░▒ ░
   ░        ░       ░  ░      ░    ░ ░ ░        ░         ░      ░        ░
    ░       ░  ░    ░           ░      ░         ░      ░        ░  ░      ░
ART
    elif [ "$cols" -ge 75 ]; then
        banner_block "$cols" 71 <<'ART'
     ██▓          ██▓     ▓██                    ▄██
 ▄██▄██▒  ▄███▄  ▓██▒▄██▄ ▒██   ▄████▄   ▄████▄ ▓█████▒  ▄███▄   ██▄██▄
▓██▀ ▀██▓██▀ ▀██▒▒██▀  ▀██▒██░ ▒██▀ ▀██▒ ▄▄▀▓██  ▓██   ▓██▀ ▀██▒▓██▀ ▀▀
▒██  ▓██▒███▀▀▀  ░██▄  ▄██░██░ ▒██   ██░▓██  ██  ▒██   ▒███▀▀▀  ▓██
░▀███▓█▒░▒████▄▒ ░▓█▒███▀ ░▓██▄░▀████▓▀ ░▀███▓█▄ ░▀██▄▒░▒████▄▒ ▒██░
░ ░▓░ ░ ░░ ▒░ ░  ░▒▓▒░ ░  ░▒▓ ░░ ▒░▒░▒░ ░ ░▓░ ░   ▒ ░░ ░░ ▒░ ░  ░ ▒▓
 ░ ▒  ░  ░ ░  ░  ▒░▒ ░ ░   ░▒    ░ ▒ ▒░  ░ ▒  ░   ░ ░   ░ ░  ░    ░▒ ░
   ░       ░      ░  ░     ░   ░ ░ ░       ░        ░     ░       ░
    ░      ░  ░   ░          ░     ░        ░     ░       ░  ░     ░
ART
    else
        banner_block "$cols" 44 <<'ART'
          ▓██
 ▄████▄   ▒██     ▄███▄    ▄████▄   ██▄██▄
▒██▀ ▀█   ▒██░  ▓██▀ ▀██▒  ▄▄▀▓██  ▓██▀ ▀██▒
▒▓█    ▄  ░██░  ▒███▀▀▀   ▓██  ██  ▓██   ██▒
▒ ▓███▀ ░ ░▓██▄ ░▒████▄▒  ░▀███▓█▄ ▒██░  ██░
░ ░▒ ▒  ░ ░▒▓ ░ ░░ ▒░ ░   ░ ░▓░ ░  ░ ▒░  ▒ ░
  ░  ▒     ░▒    ░ ░  ░    ░ ▒  ░  ░ ░░  ░ ░
░          ░       ░         ░        ░  ░
░ ░          ░     ░  ░       ░          ░
ART
    fi
}
