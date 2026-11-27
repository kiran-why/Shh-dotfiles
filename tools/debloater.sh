# Shhware debloater API 1
# Inspect local package metadata and files. Candidate records live in this shell only.

deb_nl='
'
deb_categories='packages|Package candidates
duplicates|Duplicate binaries
cache|Package cache
builds|Build directories
links|Broken symlinks
apps|Application leftovers
backups|Old backups
large|Large files'
deb_proc_root=/proc

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

deb_managed_path() {
    local root
    while IFS= read -r root; do
        [ -n "$root" ] || continue
        case "$1/" in "$root/"*) return 0 ;; esac
    done <<ROOTS
${deb_managed_roots:-}
ROOTS
    return 1
}

# Keep shared inode sizes so totals spanning several trees count their blocks once.
deb_tree_size() {
    local device=${2%%:*}
    { find "$1" -xdev -exec stat -c '%d:%i %b %h %f' {} + || echo missing; } |
        awk -v dev="$device:" '
            NF!=4 {bad=1;next}
            index($1,dev)!=1 {next}
            $3>1 && $4 !~ /^4/ {
                if (seen[$1]++) next
                links=links "," $1 "=" sprintf("%.0f",$2*512)
            }
            {n++; blocks+=$2}
            END {printf "%s\t%s\t%s\n",n?sprintf("%.0f",blocks*512):"UNKNOWN",bad?"Partial":"Full",links?links:"-"}'
}

deb_file() {
    local path=$1 reason=$2 risk=$3 owner=${4:-N/A} status=${5:-Review} gate=${6:-review}
    local size stamp rest kind=logical quality=Full usage
    case "$deb_category" in
        cache|sources|builds) ;;
        *) if deb_managed_path "$path" || [ "${deb_roots_known:-0}" = 0 ]; then
               gate=blocked; risk='Managed cache or work tree; inspect its own category'
           fi ;;
    esac
    stamp=$(deb_stamp "$path") || { deb_notice 'UNKNOWN: object changed or inaccessible' 1; return; }
    rest=${stamp#*:*:*:}; size=${rest%%:*}
    if [ -d "$path" ] && [ ! -L "$path" ]; then
        kind=allocated
        if [ "${deb_verifying:-0}" = 1 ]; then size=UNKNOWN
        elif [ "$deb_category" = builds ] || [ "$deb_category" = sources ]; then
            usage=$(deb_tree_size "$path" "$stamp")
            size=${usage%%"$tab"*}; quality=${usage#*"$tab"}
        else size=UNKNOWN; fi
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$deb_category" "$(deb_escape "$path")" "$reason" "$size" "$(deb_escape "$owner")" "$risk" "$stamp" "$status" "$gate" "$kind" "$quality"
}

deb_protection() (
    local name parts files services group default pkg csv hardware drivers optional
    for pkg in $deb_base_packages ${build_tools:-}; do printf '%s\tBase system or toolchain\n' "$pkg"; done
    [ -r "$components_file" ] || return 1
    optional=$(awk -F'|' '!/^#/ {print $2}' "$components_file") || return 1
    hardware=$(sh "${hardware_script:-scripts/hardware}" 2>/dev/null) || hardware=''
    drivers=$(gpu_drivers "$hardware") || return 1
    for name in common $drivers; do
        csv=$packages_dir/$name.csv
        [ "$name" = common ] || [ -e "$csv" ] || continue
        awk -F, -v optional="$optional" 'BEGIN {n=split(optional,a,/[[:space:]]+/); for(i=1;i<=n;i++) skip[a[i]]=1}
            /^[^#]*,/ && $2!="" && !($2 in skip) {print $2 "\tShhware package list"}' "$csv" || return 1
    done
    set -f
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

deb_package_gate() {
    case "$1" in linux|linux-*|linux[0-9]*|grub|grub-*|runit|s6-*) echo protected; return ;; esac
    case "$deb_nl$deb_protected" in *"$deb_nl$1$tab"*) echo protected ;;
        *) if [ "$deb_protection_ok" = 1 ]; then echo review; else echo blocked; fi ;;
    esac
}

deb_packages() {
    local leaves pkg gate status risk measurements size quality version
    [ "$deb_db_ok" = 1 ] || { deb_notice 'UNKNOWN: installed database unavailable' 1; return; }
    [ -n "$deb_installed" ] || return 0
    leaves=$(deb_orphans 2>/dev/null) || { deb_notice 'UNKNOWN: package candidate query failed' 1; return; }
    measurements=''
    [ "${deb_verifying:-0}" = 1 ] || measurements=$(deb_package_sizes "$leaves") || measurements=''
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        case "$deb_nl$deb_installed$deb_nl" in *"$deb_nl$pkg$deb_nl"*) deb_pkg_name "$pkg" ;; *) false ;; esac || {
            deb_notice 'UNKNOWN: unexpected package identifier' 1; continue
        }
        gate=$(deb_package_gate "$pkg")
        case "$gate" in
            protected) status=Protected
                risk=$(printf '%s\n' "$deb_protected" | awk -F '\t' -v p="$pkg" '$1==p {print $2;exit}')
                risk=${risk:-System package} ;;
            blocked) status=Blocked; risk='Incomplete protection data' ;;
            *) status=$deb_package_class; risk='Verify use and full native transaction'
                case "$pkg" in bubblewrap|gcompat|tzdata|gdb|ripgrep|github-cli|perl|pigz) status=Review ;; esac ;;
        esac
        size=UNKNOWN quality=UNKNOWN
        case "$deb_nl$measurements" in *"$deb_nl$pkg$tab"*)
            size=$deb_nl$measurements; size=${size#*"$deb_nl$pkg$tab"}
            size=${size%%"$deb_nl"*}; quality=${size#*"$tab"}; size=${size%%"$tab"*} ;;
        esac
        version=$(deb_package_version "$pkg") || version=''
        if ! deb_version_valid "$version"; then
            version=UNKNOWN
            if [ "$gate" = review ]; then status=Blocked; gate=blocked; risk='Installed version unavailable'; fi
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\tpackage:%s\t%s\t%s\tinstalled\t%s\n' "$deb_category" "$pkg" "$deb_package_reason" "$size" "$pkg" "$risk" "$version" "$status" "$gate" "$quality"
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
    local matches name encoded origin path active references other version identity seen='' previous='' reason owner
    matches=$(deb_binary_index | awk -F '\t' '
        /^![01]\t/ && $3!="PATH" && $3!="local" && $3!="system" {print; next}
        {rows[NR]=$0; names[NR]=$1; count[$1]++}
        END {for(i=1;i<=NR;i++) if(count[names[i]]>1) print rows[i]}' | sort -s -t "$tab" -k1,1)
    while IFS="$tab" read -r name encoded origin; do
        [ -n "$name" ] || continue
        case "$name:$origin" in '!0:NOT TESTED:'*|'!1:UNKNOWN:'*) printf '%s\t%s\t%s\n' "$name" "$encoded" "$origin"; continue ;; esac
        path=$(printf '%b.' "$encoded"); path=${path%.}
        identity=$(stat -L -c '%d:%i' "$path" 2>/dev/null) || { deb_notice 'UNKNOWN: executable changed' 1; continue; }
        if [ "$previous" != "$name" ]; then seen=''; active=''; references=''; previous=$name; fi
        if [ "$origin" != PATH ]; then reason='Outside PATH'
        elif [ -z "$active" ]; then active=$path; reason='Active in PATH'
        else reason='Shadowed in PATH'; fi
        local position="$reason" comparison
        case " $seen " in
            *" $identity "*) reason="$reason; Same file (same inode)" ;;
            *) if [ -n "$references" ]; then
                   comparison='Different copies'
                   while IFS= read -r other; do
                       other=$(printf '%b.' "$other"); other=${other%.}
                       if cmp -s "$other" "$path"; then comparison="Identical copies: $(deb_escape "$other")"; break
                       elif [ "$?" != 1 ]; then comparison='Contents UNKNOWN'; fi
                   done <<REFERENCES
$references
REFERENCES
                   reason="$reason; $comparison"
               fi
               references="${references:+$references$deb_nl}$encoded"
               seen="$seen $identity" ;;
        esac
        [ ! -L "$path" ] || reason="$reason; symlink"
        owner=$(deb_owner "$path" 2>/dev/null) || owner=UNKNOWN
        version=N/A
        case "$owner" in ''|Unowned|UNKNOWN) ;; *)
            if deb_pkg_name "$owner"; then version=$(deb_package_version "$owner" 2>/dev/null) || version=UNKNOWN; fi ;;
        esac
        case "$owner" in UNKNOWN|'') owner='Ownership unknown'; version=UNKNOWN ;; Unowned) ;; *) owner="Package-owned: $owner" ;; esac
        deb_file "$path" "$reason; package version: $(deb_escape "${version:-UNKNOWN}")" 'Executable may be in use' "$owner" "$position"
    done <<MATCHES
$matches
MATCHES
}

deb_version_valid() { case "$1" in ''|-*|*[!a-zA-Z0-9_:~.+-]*) return 1 ;; esac; }

# Inspect process identity on both sides of the cwd and argv reads.
deb_processes() (
    set -f
    local dir row start second pid parent cwd command flags comm args arg
    if [ ! -r "$deb_proc_root/mounts" ] || ! awk '$2=="/proc" {ok=1; if ($4 ~ /hidepid=([124]|invisible|noaccess|ptraceable)/) exit 1} END {if (!ok) exit 1}' "$deb_proc_root/mounts"; then
        echo incomplete
    fi
    set +f
    for dir in "$deb_proc_root"/[0-9]*; do
        [ -d "$dir" ] || { echo incomplete; continue; }
        IFS= read -r row <"$dir/stat" || { echo incomplete; continue; }
        pid=${dir##*/}; set -f; set -- ${row##*) }
        [ "$#" -ge 20 ] || { echo incomplete; continue; }
        parent=$2; flags=$7; start=${20}
        case "$flags" in ''|*[!0-9]*) echo incomplete; continue ;; esac
        [ "$1" != Z ] && [ "$((flags & 2097152))" = 0 ] || continue
        cwd=$(CDPATH= cd -P "$dir/cwd" && pwd -P && printf .) || cwd=UNKNOWN
        cwd=${cwd%"$deb_nl."}
        case "$cwd" in *[!\ -~]*|*\\*|UNKNOWN) echo incomplete; cwd=UNKNOWN ;; esac
        command=other
        comm=${row#*(}; comm=${comm%)*}
        case " ${deb_manager_names:-} curl wget wget2 aria2c axel " in *" $comm "*) command=inspect ;; esac
        case "$comm" in sh|ash|dash|bash|zsh|busybox|env) command=inspect ;; esac
        if [ "$command" = inspect ]; then
            args=$(tr '\000' '\n' <"$dir/cmdline") || args=''
            command=unknown
            while IFS= read -r arg; do
                [ -n "$arg" ] || break
                case "${arg##*/}" in sh|ash|bash|dash|zsh|busybox|env|-*) continue ;; esac
                case " ${deb_manager_names:-} " in
                    *" ${arg##*/} "*) command=manager ;;
                    *) case "${arg##*/}" in curl|wget|wget2|aria2c|axel) command=download ;; *) command=other ;; esac ;;
                esac
                break
            done <<ARGS
$args
ARGS
            [ -n "$args" ] && [ "$command" = unknown ] && command=other
        fi
        IFS= read -r second <"$dir/stat" || { echo incomplete; continue; }
        set -- ${second##*) }
        [ "$#" -ge 20 ] && [ "${20}" = "$start" ] && [ "$2" = "$parent" ] || { echo incomplete; continue; }
        [ "$command" != unknown ] || echo incomplete
        printf '%s\t%s\t%s\t%s\t%s\n' "$pid" "$parent" "$start" "${command:-other}" "$cwd"
    done
)

deb_build_state() {
    local path
    path=$(cd -P "$1" && pwd -P) || { echo 'Unknown state'; return; }
    printf '%s\n' "$deb_process_table" | DEB_DIR="$path" awk -F '\t' -v id="${1##*/}" -v op="$deb_operation" '
        BEGIN {dir=ENVIRON["DEB_DIR"]}
        NF==5 {
            parent[$1]=$2
            if ($5==dir || index($5,dir "/")==1) inside[$1]=1
            if ($1==id && $4=="manager") matching=1
        }
        END {
            for(pid in inside) {
                for(p=pid; p && !visited[p]++; p=parent[p]) if(p==id && matching) {
                    print "Active build\tKISS process or descendant in work tree"; exit
                }
                active=1
            }
            if (active) print "Active build\tProcess cwd in work tree"
            else if (matching || op!="Idle") print "Unknown state\tPackage activity or incomplete process visibility"
            else print "Inactive build\tComplete process snapshot; no process linked to tree"
        }'
}

deb_cache_index() {
    local dir path id encoded
    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        deb_directory "$dir" || continue
        for path in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
            [ -f "$path" ] && [ ! -L "$path" ] || continue
            encoded=$(deb_escape "$path")
            case "$path" in *.part|*.partial|*.sig|*.sig2) id='' ;;
                *) id=$(deb_archive_id "$path") || id='' ;;
            esac
            printf '%s\t%s\n' "${id:-?$tab?$tab?}" "$encoded"
        done
    done
}

deb_cache() {
    local roots rows pkg ver version arch encoded path current group='' previous='' order state gate reason versions='' unsafe=0
    roots=$deb_binary_roots
    [ "$deb_roots_known" = 1 ] || { deb_notice 'UNKNOWN: cache configuration unavailable' 1; return; }
    rows=$(printf '%s\n' "$roots" | deb_cache_index | sort -t "$tab" -k1,1 -k3,3 | awk -F '\t' '
        {r[NR]=$0; g[NR]=$1 FS $3; if (!seen[g[NR],$2]++) versions[g[NR]]=versions[g[NR]] " " $2}
        END {for(i=1;i<=NR;i++) print r[i] FS versions[g[i]]}')
    while IFS="$tab" read -r pkg ver arch encoded versions; do
        [ -n "$pkg" ] || continue
        case "$pkg" in '!0'|'!1') printf '%s\t%s\t%s\n' "$pkg" "$ver" "$arch"; continue ;; esac
        if [ "$group" != "$pkg/$arch" ]; then
            group=$pkg/$arch; previous=''; unsafe=0; current=''
            if deb_pkg_name "$pkg" && [ "$deb_db_ok" = 1 ]; then
                case "$deb_nl$deb_installed$deb_nl" in *"$deb_nl$pkg$deb_nl"*)
                    current=$(deb_package_version "$pkg") || current=''
                    deb_version_valid "$current" || current=''
                    deb_archive_arch "$pkg" "$arch" || current='' ;;
                    *) current='!absent' ;;
                esac
            fi
            if [ "${deb_policy:-previous}" = previous ] && [ -n "$current" ] && [ "$current" != '!absent' ]; then
                for version in $versions; do
                    [ "$version" != "$current" ] || continue
                    order=$(deb_compare_versions "$version" "$current") || { unsafe=1; continue; }
                    [ "$order" = -1 ] || continue
                    if [ -z "$previous" ]; then previous=$version
                    else
                        order=$(deb_compare_versions "$version" "$previous") || { unsafe=1; continue; }
                        [ "$order" != 1 ] || previous=$version
                    fi
                done
            fi
        fi
        path=$(printf '%b.' "$encoded"); path=${path%.}
        gate=blocked; state='Unknown state'; reason='Unidentified cache file'
        case "$path" in
            *.part|*.partial) reason='Partial download; activity unknown' ;;
            *.sig|*.sig2) reason='Archive signature; keep with archive' ;;
            *) if deb_version_valid "$ver" && deb_pkg_name "$pkg"; then
                case "$current" in
                    '') reason='Unknown installed version or architecture' ;;
                    '!absent') state='Not installed'; gate=review; reason='Package not installed' ;;
                    "$ver") state=Installed; reason='Installed version archive'
                        [ "${deb_policy:-previous}" != all ] || gate=review ;;
                    *) state=Alternate; reason='Alternate version archive'
                        case "${deb_policy:-previous}" in
                            all|installed) gate=review ;;
                            previous) if [ "$unsafe" = 0 ] && [ -n "$previous" ] &&
                                [ "$(deb_compare_versions "$ver" "$previous")" = -1 ]; then gate=review; fi ;;
                        esac ;;
                esac
            fi ;;
        esac
        [ "$deb_operation" = Idle ] || gate=blocked
        deb_file "$path" "$reason" "Policy: ${deb_policy:-previous}; package activity: $deb_operation" N/A "$state" "$gate"
    done <<ARCHIVES
$rows
ARCHIVES
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
            deb_managed_path "$path" && continue
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
    deb_managed_path "$deb_large_root" && return 0
    deb_directory "$deb_large_root" || return 0
    deb_large_walk "$deb_large_root" "$(stat -L -c %d "$deb_large_root")"
}

deb_activity() {
    deb_process_table=$(deb_processes 2>/dev/null) || deb_process_table=incomplete
    deb_operation=$(printf '%s\n' "$deb_process_table" | DEB_ROOTS="$deb_managed_roots" awk -F '\t' '
        BEGIN {n=split(ENVIRON["DEB_ROOTS"],roots,"\n")}
        NF!=5 {incomplete=1; next}
        $4=="manager" || $4=="download" {active=1}
        {for(i=1;i<=n;i++) if (roots[i] && ($5==roots[i] || index($5,roots[i] "/")==1)) active=1}
        END {print active?"Active":incomplete?"UNKNOWN":"Idle"}')
    if command -v deb_manager_locked >/dev/null; then
        if deb_manager_locked; then deb_operation=Active
        elif [ "$?" != 1 ]; then deb_operation=UNKNOWN; fi
    fi
}

deb_scan() {
    local key label deb_category output
    deb_process_table= deb_operation=UNKNOWN deb_roots_known=1
    deb_binary_roots='' deb_managed_roots=''
    case " $* " in *' cache '*|*' sources '*|*' builds '*|*' large '*|*' backups '*|*' duplicates '*|*' links '*|*' apps '*)
        deb_binary_roots=$(deb_cache_roots 2>/dev/null) || deb_roots_known=0
        deb_managed_roots=$deb_binary_roots
        if command -v deb_work_root >/dev/null; then
            deb_managed_roots="$deb_managed_roots$deb_nl$(deb_work_root)$deb_nl$(deb_source_root)"
        fi ;;
    esac
    case " $* " in *" builds "*|*" cache "*|*" sources "*)
        deb_activity ;;
    esac
    deb_checked=" $* "
    deb_records='' deb_selected=' ' deb_partial=0 deb_scanned=1
    deb_protected='' deb_installed='' deb_db_ok=0 deb_protection_ok=0
    case " $* " in *' packages '*|*' apps '*|*' cache '*|*' sources '*)
        if deb_installed=$(deb_installed_packages 2>/dev/null); then deb_db_ok=1; fi
        ;;
    esac
    while IFS='|' read -r key label; do
        deb_category=$key
        case " $* " in *" $key "*) ;; *) continue ;; esac
        if [ "$key" = packages ]; then
            if deb_protected=$(deb_protection 2>/dev/null); then deb_protection_ok=1
            else deb_records="$deb_records!1$tab$deb_category${tab}UNKNOWN: incomplete protection data$deb_nl"; fi
        fi
        if ! output=$("deb_$key" 2>/dev/null); then
            output="${output:+$output$deb_nl}!1$tab$deb_category${tab}UNKNOWN: scan unavailable"
        fi
        deb_records="$deb_records${output:+$output$deb_nl}"
    done <<CATEGORIES
$deb_categories
CATEGORIES
    deb_records=$(printf '%s' "$deb_records" | awk -F '\t' '
        {row[NR]=$0}
        NF>=11 && $1!="packages" {
            split($7,a,":"); id[NR]=a[1] ":" a[2]
            if ($9!="review") locked[id[NR]]=1
        }
        END {OFS="\t"; for(i=1;i<=NR;i++) {
            $0=row[i]; if(id[i] in locked && $9=="review") {$9="blocked"; $6=$6 "; another observation is blocked"}
            print
        }}')
    deb_records="${deb_records:+$deb_records$deb_nl}"
    case "$deb_nl$deb_records" in *"$deb_nl!1$tab"*) deb_partial=1 ;; esac
}

# Render cached observations without running probes in the preview pane.
deb_view() {
    printf '%s' "$deb_records" | awk -F '\t' -v mode="$1" -v filter="${2:-}" \
        -v checked="$deb_checked" -v categories="$deb_categories" -v selected="$deb_selected" '
        function bytes(v) {
            if (v=="UNKNOWN") return v
            if (v ~ /B$/) return v
            v+=0
            if (v<1024) return sprintf("%.0f B",v)
            if (v<1048576) return sprintf("%.1f KiB",v/1024)
            if (v<1073741824) return sprintf("%.1f MiB",v/1048576)
            return sprintf("%.1f GiB",v/1073741824)
        }
        function metric(key,label,value) {
            if (!index(checked," " key " ")) value="NOT TESTED"
            else if (notice[key]) value=(seen[key]?value " (Partial)":notice[key])
            if (mode=="counts") print key "\t" label "  " value
            else printf "  %-28s  %s\n",label,value
        }
        function add(scope,   n,i,a,b) {
            if (added[scope,identity]++) return
            if (size !~ /^[0-9]+$/) return
            sums[scope,kind]+=size
            n=split($12,a,",")
            for(i=1;i<=n;i++) if (split(a[i],b,"=")==2 && shared[scope,kind,b[1]]++) sums[scope,kind]-=b[2]
        }
        BEGIN {
            ncat=split(categories,rows,"\n")
            for(i=1;i<=ncat;i++) {split(rows[i],c,"[|]"); keys[i]=c[1]; labels[c[1]]=c[2]}
        }
        /^![01]\t/ {
            if ($1=="!1" || !notice[$2]) notice[$2]=($1=="!1"?"UNKNOWN":"NOT TESTED")
            if(mode=="list") print labels[$2] "  " $3
            if(mode=="rows" && filter==$2) print "notice\t" $3 "\t" labels[$2] "\t" $3 "\tN/A\tN/A\tCheck incomplete"
            notices++; next
        }
        NF>=11 {
            key=$1; path=$2; size=$4; state=$8; gate=$9; kind=$10
            n=split(path,p,"/"); name=p[n]
            id=key=="packages"?"pkg:" path:"path:" path
            split($7,stamp,":"); identity=key=="packages"?id:kind ":" stamp[1] ":" stamp[2]
            size_label=($11=="Partial"?"Partial ":($11=="Rounded"?"~":"")) bytes(size)
            seen[key]++
            if(key=="duplicates" && !names[name]++) groups++
            if(key=="cache" && state=="Alternate") archives++
            if(key=="builds" && state=="Active build") active++
            if(key=="packages" && gate=="protected") protected_pkgs++
            if(key=="packages" && gate=="blocked") blocked_pkgs++
            first=!observed[id]++
            if(first) {
                objects++; protected+=(gate=="protected"); blocked+=(gate=="blocked"); eligible+=(gate=="review")
                unknown+=(size=="UNKNOWN"); partial+=($11=="Partial"); rounded+=($11=="Rounded")
                add("all"); if(gate=="review") add("candidate")
            }
            detail=$3 " | " kind " size"
            if(mode=="list") {
                print labels[key] "  " path "  " size_label "  " state
                print "  " detail " | Owner: " $5 " | " gate " | " $6
            }
            if(mode=="rows" && ((key==filter && gate!="protected") || (filter=="protected" && key=="packages" && gate=="protected") ||
                (filter=="select" && first && gate=="review"))) {
                mark=filter=="select"?(index(selected," " NR " ")?"[x] ":"[ ] "):""
                row=sprintf("%s%-24.24s %13s  %s",mark,name,size_label,state)
                print NR "\t" row "\t" path "\t" detail "\t" size_label "\t" $5 "\t" gate " | " $6
            }
            if(mode=="selection" && index(selected," " NR " ")) {
                picked++; missing+=(size=="UNKNOWN"); picked_partial+=($11=="Partial"); picked_rounded+=($11=="Rounded"); add("selected")
            }
        }
        END {
            if(mode=="list" && !objects && !notices) print "No candidates found in completed checks."
            if(mode=="selection") printf "Selected: %d | Installed: %s | Logical: %s | Allocated: %s | Unknown sizes: %d\n",picked,bytes(sums["selected","installed"]+0),bytes(sums["selected","logical"]+0),bytes(sums["selected","allocated"]+0),missing
            if(mode=="selection" && (picked_partial || picked_rounded)) printf "Partial sizes: %d | Rounded only: %d\n", picked_partial,picked_rounded
            if(mode!="summary" && mode!="counts") exit
            for(i=1;i<=ncat;i++) {
                k=keys[i]; if(mode=="summary" && !index(checked," " k " ")) continue
                v=seen[k]+0
                if(k=="packages") v-=protected_pkgs+blocked_pkgs
                if(k=="duplicates") v=sprintf("%d groups (%d paths)",groups,v)
                metric(k,labels[k],v)
                if(mode=="summary" && k=="packages") {
                    metric(k,"Protected packages",protected_pkgs+0); metric(k,"Blocked packages",blocked_pkgs+0)
                }
                if(mode=="summary" && k=="cache") metric(k,"Alternate package archives",archives+0)
                if(mode=="summary" && k=="builds") metric(k,"Active builds",active+0)
            }
            if(mode=="counts") {print "protected\tProtected packages  " protected_pkgs+0; exit}
            printf "\n  Detected: %d | Protected: %d | Blocked: %d | Selectable: %d\n",objects,protected,blocked,eligible
            printf "  %-23s %14s %14s\n","Known size","All objects","Candidates"
            split("installed logical allocated",kinds," ")
            for(i=1;i<=3;i++) {k=kinds[i]; printf "  %-23s %14s %14s\n",k,bytes(sums["all",k]+0),bytes(sums["candidate",k]+0)}
            printf "  Unknown sizes: %d | Partial sizes: %d | Rounded only: %d\n",unknown,partial,rounded
        }'
}

deb_user_scan() {
    local spinner='' owner start='' end='' rest rc=0
    deb_elapsed=''
    if [ -t 0 ] && [ -t 1 ] && [ -t 2 ] && [ -n "${red:-}" ] &&
        [ "${TERM:-dumb}" != dumb ] && command -v tui_spinner >/dev/null &&
        IFS=' ' read -r owner rest </proc/self/stat; then
        tui_spinner "$owner" 'Scanning system...' &
        spinner=$!
    fi
    if [ -r /proc/uptime ]; then read -r start rest </proc/uptime || start=''; fi
    deb_scan "$@" || rc=$?
    if [ -n "$start" ]; then read -r end rest </proc/uptime || end=''; fi
    if [ -n "$spinner" ]; then
        kill "$spinner" 2>/dev/null || :
        wait "$spinner" 2>/dev/null || :
    fi
    if [ -n "$end" ]; then
        deb_elapsed=$(LC_ALL=C awk -v a="$start" -v b="$end" 'BEGIN {
            if (a ~ /^[0-9]+[.][0-9]+$/ && b ~ /^[0-9]+[.][0-9]+$/ && b+0>=a+0) printf "%.2f s",b-a
        }')
    fi
    return "$rc"
}

deb_summary() {
    local heading='System scan completed' color=$white
    if [ "$deb_partial" = 1 ]; then heading='System scan incomplete'; color=$red; fi
    printf '%s%s%s%s\n\n' "$color" "$heading" "$reset" "${deb_elapsed:+ ($deb_elapsed)}"
    case "$deb_checked" in *[!\ ]*) deb_view summary ;; *) echo '  No scan categories enabled.' ;; esac
    printf '\n  Review: shh debloater --list\n\n  No changes applied.\n'
}

deb_show() {
    printf '%s\n' "$2" | fzf --ansi --no-input --border-label=" $1 " --header='Esc: back' >/dev/null || :
}

# Bind a cache record to its configured directory, ancestors and archive policy.
deb_archive_guard() (
    local encoded=$1 path dir root entry chain='' archive pkg version
    path=$(printf '%b.' "$encoded"); path=${path%.}
    case "$path/" in */../*|*/./*|*//*|[!/]*) return 1 ;; esac
    [ -f "$path" ] && [ ! -L "$path" ] && [ "$(stat -c %h "$path")" = 1 ] || return 1
    dir=${path%/*}
    while IFS= read -r root; do
        [ -n "$root" ] && [ "${root%/}" = "$dir" ] && break
    done <<ROOTS
$deb_binary_roots
ROOTS
    [ -n "$dir" ] && [ "${root%/}" = "$dir" ] && deb_directory "$dir" >/dev/null || return 1
    for entry in deb_work_root deb_source_root; do
        command -v "$entry" >/dev/null || continue
        root=$("$entry") && [ -n "$root" ] || return 1
        root=$(CDPATH='' cd -P "$root" 2>/dev/null && pwd -P) || {
            root=$("$entry") || return 1
            [ ! -e "$root" ] && [ ! -L "$root" ] || return 1
        }
        case "$path/" in "${root%/}/"*) return 1 ;; esac
    done
    while :; do
        [ -d "$dir" ] && [ ! -L "$dir" ] || return 2
        entry=$(stat -c '%d:%i:%f:%u:%g' "$dir") || return 1
        chain="$chain/$entry"
        [ "$dir" != / ] || break
        dir=${dir%/*}; dir=${dir:-/}
    done
    [ "$(deb_owner "$path" 2>/dev/null)" = Unowned ] || return 1
    archive=$(deb_archive_id "$path") || return 1
    pkg=${archive%%"$tab"*}
    deb_pkg_name "$pkg" && [ "$deb_db_ok" = 1 ] || return 1
    case "$deb_nl$deb_installed$deb_nl" in
        *"$deb_nl$pkg$deb_nl"*) version=$(deb_package_version "$pkg") && deb_version_valid "$version" || return 1 ;;
        *) version='!absent' ;;
    esac
    printf '%s|%s|%s|%s|%s\n' "$chain" "$deb_checked" "$deb_policy" "$version" "$(deb_escape "$archive")"
)

deb_lookup() {
    printf '%s' "$deb_records" | DEB_PATH="$2" awk -F '\t' -v category="$1" '
        $1==category && $2==ENVIRON["DEB_PATH"] {row=$0; count++}
        END {if (count!=1) exit 1; print row}'
}

# Compare classification and identity. Verification scans omit expensive size measurements.
deb_matches() {
    [ "$(printf '%s\n' "$1" | cut -f1-3,5,7-10)" = "$(printf '%s\n' "$2" | cut -f1-3,5,7-10)" ]
}

# Capture every transaction member and version before showing the group.
deb_transaction() (
    local native pkg version members=''
    native=$(deb_native_plan "$@" 2>/dev/null) && [ -n "$native" ] || {
        echo 'complete native transaction unavailable'; return 1
    }
    for pkg do
        case "$deb_nl$native$deb_nl" in *"$deb_nl$pkg$deb_nl"*) ;; *) echo 'incomplete transaction'; return 1 ;; esac
    done
    while IFS= read -r pkg; do
        deb_pkg_name "$pkg" || { echo 'ambiguous transaction'; return 1; }
        case "$deb_nl$deb_installed$deb_nl" in *"$deb_nl$pkg$deb_nl"*) ;; *) echo 'unverified transaction member'; return 1 ;; esac
        [ "$(deb_package_gate "$pkg")" = review ] || { echo "$pkg — Protected transaction member"; return 1; }
        version=$(deb_package_version "$pkg") && deb_version_valid "$version" || { echo 'unknown transaction version'; return 1; }
        members="${members:+$members }$pkg=$version"
    done <<PACKAGES
$native
PACKAGES
    printf '%s\n' "$members"
)

# Prefix each original observation with operation, disposition, explanation and verification data.
deb_plan() (
    local old=$deb_records ids=$deb_selected checked=$deb_checked deb_verifying=1
    local id row category encoded rest gate op verdict note guard fresh packages='' package_rows='' transaction='' invalid=0 seen=' '
    case "$ids" in *[!\ ]*) ;; *) return 0 ;; esac
    deb_settings_read
    deb_scan $checked
    for id in $ids; do
        case "$id" in ''|*[!0-9]*|0*) return 1 ;; esac
        case "$seen" in *" $id "*) return 1 ;; esac
        seen="$seen$id "
        row=$(printf '%s' "$old" | sed -n "${id}p")
        category=${row%%"$tab"*}; rest=${row#*"$tab"}; encoded=${rest%%"$tab"*}
        gate=$(printf '%s\n' "$row" | cut -f9)
        [ -n "$gate" ] || return 1
        verdict=Blocked; note='Manual review only'; guard=-
        case "$category" in packages) op=remove-package ;; cache) op=unlink-archive ;; *) op=review ;; esac
        if [ "$gate" != review ]; then note="Detection gate: $gate"
        elif ! fresh=$(deb_lookup "$category" "$encoded") || ! deb_matches "$row" "$fresh"; then
            note='changed since scan or unavailable'
        elif ! printf '%s\n' "$deb_enabled" | grep -Fq " $category "; then note='Category disabled'
        elif [ "$category" = packages ]; then
            deb_pkg_name "$encoded" || return 1
            packages="${packages:+$packages }$encoded"
            package_rows="${package_rows:+$package_rows$deb_nl}$row"
            continue
        elif [ "$category" = cache ]; then
            if [ "$deb_partial" = 1 ]; then note='Incomplete verification scan'
            elif guard=$(deb_archive_guard "$encoded"); then verdict=Ready; note='Preview only'
            else guard=-; note='Unverified archive ownership, type or directory'; fi
        fi
        [ "$category" != packages ] || invalid=1
        printf '%s\t%s\t%s\t%s\t%s\n' "$op" "$verdict" "$note" "$guard" "$row"
    done
    [ -n "$packages" ] || return 0
    note='Package execution is blocked'
    if [ "$invalid" = 1 ]; then note='Selected package group changed'; transaction=-
    elif ! transaction=$(deb_transaction $packages); then note=$transaction; transaction=-; fi
    while IFS= read -r row; do
        printf 'remove-package\tBlocked\t%s\t%s\t%s\n' "$note" "$transaction" "$row"
    done <<PACKAGES
$package_rows
PACKAGES
)

deb_preview() (
    local plan=$1 deb_records deb_selected category encoded op verdict note guard rest pkg reason size owner risk shown=''
    [ -n "$plan" ] || { echo 'No actions selected'; return; }
    deb_records=$(printf '%s\n' "$plan" | cut -f5-)
    deb_selected=$(printf '%s\n' "$plan" | awk '{printf " %d",NR} END {print " "}')
    deb_view selection
    while IFS="$tab" read -r op verdict note guard category encoded reason size owner risk rest; do
        printf '%s: %s — %s (%s)\n' "$verdict" "$encoded" "$note" "$op"
        printf '  %s | %s\n' "$reason" "$risk"
        if [ "$category" = packages ]; then
            printf 'Requested packages: %s\n' "$encoded"
            if [ "$guard" != - ] && [ "$guard" != "$shown" ]; then
                for pkg in $guard; do printf 'Preview removal: %s (%s)\n' "${pkg%%=*}" "${pkg#*=}"; done
                shown=$guard
            fi
        fi
    done <<PLAN
$plan
PLAN
    echo 'Preview only. Real cleanup is blocked.'
)

# Test execution uses the exact plan shown here, including blocked entries.
deb_confirm() {
    local answer
    [ -n "$1" ] || return 1
    [ -t 0 ] && [ -t 2 ] || { echo 'Interactive terminal required for confirmation' >&2; return 1; }
    deb_preview "$1" >&2 || return 1
    printf 'Confirm selected operations? [y/N] ' >&2
    IFS= read -r answer && [ "$answer" = y ]
}

# A fixture supplies its own executor in the test shell.
deb_execute_archive() { return 125; }

# Update the result reason on refusal. A busy manager invalidates the remaining archives.
deb_revalidate_archive() {
    local row=$1 encoded=$2 guard=$3 current fresh stamp
    deb_settings_read
    deb_scan $deb_enabled || { note='Verification scan failed'; return 1; }
    path=$(printf '%b.' "$encoded"); path=${path%.}
    stamp=$(printf '%s\n' "$row" | cut -f7)
    if [ "$deb_operation" != Idle ] || [ "$activity_blocked" = 1 ]; then
        activity_blocked=1; note='Package or build activity active or unknown'
    elif [ "$deb_partial" != 0 ]; then note='Incomplete verification scan'
    elif [ "$(deb_stamp "$path")" != "$stamp" ]; then status=Skipped; note='Object changed or disappeared'
    elif current=$(deb_archive_guard "$encoded"); then
        if [ "${current%%|*}" != "${guard%%|*}" ]; then status=Skipped; note='Parent directory changed'
        elif [ "$current" != "$guard" ]; then note='Scope, archive policy or package metadata changed'
        elif ! fresh=$(deb_lookup cache "$encoded"); then status=Skipped; note='Object no longer a candidate'
        elif [ "$(printf '%s\n' "$fresh" | cut -f9)" != review ]; then note='Detection now blocks the object'
        elif ! deb_matches "$row" "$fresh"; then status=Skipped; note='Candidate state changed'
        else
            deb_activity
            if [ "$deb_operation" != Idle ]; then activity_blocked=1; note='Package or build activity active or unknown'
            elif [ "$(deb_stamp "$path")" != "$stamp" ]; then status=Skipped; note='Object changed during verification'
            else return 0; fi
        fi
    elif [ "$?" = 2 ]; then status=Skipped; note='Parent directory changed'
    else note='Unverified archive ownership, type or directory'; fi
    return 1
}

deb_apply_confirmed() (
    local activity_blocked=0 deb_verifying=1 op verdict note guard row category encoded rest path status
    while IFS="$tab" read -r op verdict note guard row; do
        [ -n "$op" ] || continue
        category=${row%%"$tab"*}; rest=${row#*"$tab"}; encoded=${rest%%"$tab"*}
        status=Blocked
        if [ "$op/$category/$verdict" = unlink-archive/cache/Ready ] && deb_revalidate_archive "$row" "$encoded" "$guard"; then
            if deb_execute_archive "$path"; then status=Completed; note='Executor completed'
            elif [ "$?" = 125 ]; then note='Real file cleanup is disabled'
            else status=Failed; note='Executor failed'; fi
        fi
        printf '%s\t%s\t%s\t%s\n' "$status" "$op" "$encoded" "$note"
    done <<PLAN
$1
PLAN
)

deb_apply() {
    deb_confirm "$1" && deb_apply_confirmed "$1"
}

# fzf shell-quotes field placeholders. Use them only as printf arguments.
deb_objects() {
    fzf --no-input --delimiter="$tab" --with-nth=2 --with-shell='/bin/sh -c' \
        --preview="printf 'Object: %s\\nReason: %s\\nSize: %s\\nOwner: %s\\nRisk: %s\\n' {3} {4} {5} {6} {7}" \
        --preview-window='down,40%,wrap' "$@"
}

deb_select() {
    local rows pick id pos=1 header plan
    deb_selected=' '
    while :; do
        rows=$(deb_view rows select)
        if [ -z "$rows" ]; then
            printf 'No selectable candidates.\n'
            deb_view summary
            return
        fi
        header="$(deb_view selection)
Tab: toggle   Enter: preview   Esc: cancel
    NAME                              SIZE  STATUS"
        if [ "$deb_partial" = 1 ]; then header="$header$deb_nl Partial scan. See --list for details."; fi
        pick=$(printf '%s\n' "$rows" | deb_objects --expect=tab --header="$header" \
            --border-label=' Preview cleanup ' --bind="load:pos($pos)") || { deb_selected=' '; return 1; }
        case "$pick" in
            "tab$deb_nl"*)
                pick=${pick#*"$deb_nl"}; id=${pick%%"$tab"*}
                case "$id" in ''|*[!0-9]*) continue ;; esac
                case "$deb_selected" in
                    *" $id "*) deb_selected="${deb_selected%" $id "*} ${deb_selected#*" $id "}" ;;
                    *) deb_selected="$deb_selected$id " ;;
                esac
                pos=$(printf '%s\n' "$rows" | awk -F '\t' -v id="$id" '$1==id {print NR; exit}')
                ;;
            *)
                plan=$(deb_plan) || return 1
                deb_preview "$plan" || return 1
                echo 'No changes applied.'
                return ;;
        esac
    done
}

deb_lines() {
    line scan '' 'Scan system' '>'
    line review '' 'Review candidates' '>'
    line plan '' 'Preview cleanup' '>'
    line history '' 'Cleanup history' '>'
    line settings '' 'Settings' '>'
    line :back '' 'Back' ''
}

deb_review_lines() {
    deb_view counts
    line :back '' 'Back' ''
}

deb_review_act() {
    local key=$1 rows
    if [ "$key" = protected ]; then
        key=packages
        case "$(choose 'Protected packages' "found${tab}Detected packages
rules${tab}Protection rules")" in
            found) ;;
            rules)
                if [ "$deb_protection_ok" = 1 ]; then rows=$deb_protected
                else rows=$(deb_protection 2>/dev/null) || rows="$rows$deb_nl Protection data incomplete"; fi
                deb_show 'Protection rules' "$rows"; return ;;
            *) return ;;
        esac
    fi
    case "$deb_checked" in *" $key "*) ;; *) note='Category disabled. Enable it in Settings.'; return ;; esac
    rows=$(deb_view rows "$1")
    if [ -z "$rows" ]; then note='No matching objects in completed checks.'; return; fi
    printf '%s\n' "$rows" | deb_objects --border-label=' Review candidates ' --header='NAME                              SIZE  STATUS   |   Esc: back' >/dev/null || :
}

deb_settings_lines() {
    local key label box
    line policy '' 'Archive policy' "$deb_policy >"
    line root '' 'Large files location' "$deb_location >"
    line :back '' 'Back' ''
    printf -- '-\t\n'
    while IFS='|' read -r key label; do
        case "$deb_enabled" in *" $key "*) box='[x]' ;; *) box='[ ]' ;; esac
        line "$key" "$box" "$label" ''
    done <<CATEGORIES
$deb_categories
CATEGORIES
}

deb_settings_act() {
    local value name
    case "$1" in
        policy)
            value=$(choose 'Archive policy' "previous${tab}Keep installed versions and one previous version
installed${tab}Keep installed versions
all${tab}Review all archives")
            case "$value" in previous|installed|all) ;; *) return ;; esac
            [ "$value" != "$deb_policy" ] || return 0
            name=debloater_archive_policy ;;
        root)
            value=$(choose 'Large files (100 MiB)' "downloads${tab}Downloads
cache${tab}Application cache")
            case "$value" in downloads|cache) ;; *) return ;; esac
            [ "$value" != "$deb_location" ] || return 0
            name=debloater_location ;;
        *)
            case "$deb_enabled" in *" $1 "*) value=no ;; *) value=yes ;; esac
            name=debloater_$1 ;;
    esac
    mkdir -p "${shh_config%/*}" && set_value "$name" "$value" || { note='Could not save settings'; return; }
    deb_settings_read
    deb_scanned=0 deb_checked='' deb_records='' deb_selected=' '
}

deb_settings_read() {
    local key label default
    deb_enabled=' '
    while IFS='|' read -r key label; do
        case "$key" in apps|backups|large) default=no ;; *) default=yes ;; esac
        [ "$(setting "debloater_$key" "$default")" != yes ] || deb_enabled="$deb_enabled$key "
    done <<CATEGORIES
$deb_categories
CATEGORIES
    deb_policy=$(setting debloater_archive_policy previous)
    case "$deb_policy" in previous|installed|all) ;; *) deb_policy=previous ;; esac
    deb_location=$(setting debloater_location downloads)
    case "$deb_location" in cache) deb_large_root=${XDG_CACHE_HOME:-$HOME/.cache} ;;
        *) deb_location=downloads; deb_large_root=$HOME/Downloads ;; esac
}

deb_history() {
    local log=$HOME/.local/state/shh/debloater/history entry
    if [ ! -e "$log" ] && [ ! -L "$log" ]; then echo 'No cleanup history'; return; fi
    [ -f "$log" ] && [ ! -L "$log" ] && [ -r "$log" ] || { echo 'Cleanup history unavailable'; return 1; }
    while IFS= read -r entry || [ -n "$entry" ]; do deb_escape "$entry"; printf '\n'; done <"$log"
}

deb_act() {
    local plan
    case "$1" in
        scan)
            deb_user_scan $deb_enabled || return $?
            deb_show 'Scan system' "$(deb_summary)" ;;
        review|plan)
            [ "$deb_scanned" = 1 ] || deb_user_scan $deb_enabled || return $?
            if [ "$1" = review ]; then
                loop 'Review candidates' 'Enter: open   Esc: back' deb_review_lines deb_review_act
            elif plan=$(deb_select); then deb_show 'Cleanup plan' "$plan"; fi ;;
        history) deb_show 'Cleanup history' "$(deb_history)" ;;
        settings)
            load_module config
            loop settings 'Enter: change   Esc: back' deb_settings_lines deb_settings_act "$(config_banner settings)" ;;
    esac
}

deb_main() {
    local deb_categories="$deb_categories" deb_enabled deb_location deb_large_root deb_records='' deb_selected=' ' deb_checked=''
    local red="$red" white="$white" reset="$reset" deb_elapsed=''
    if [ ! -t 2 ] || [ "${TERM:-dumb}" = dumb ]; then red='' white='' reset=''; fi
    local deb_scanned=0 deb_partial=0 deb_installed='' deb_protected='' deb_protection_ok=0 deb_db_ok=0
    case "${1:-}" in
        --help) usage debloater; return ;;
        --history) deb_history; return ;;
        --dry-run) if [ ! -t 0 ] || [ ! -t 1 ]; then echo 'No actions selected'; return; fi ;;
    esac
    if command -v deb_source_root >/dev/null; then deb_categories="$deb_categories$deb_nl"'sources|Source cache'; fi
    deb_settings_read
    case "${1:-}" in
        --scan|--list|--build|--packages|--duplicates|--cache)
            case "$1" in --scan|--list) deb_user_scan $deb_enabled ;; --build) deb_user_scan builds ;; *) deb_user_scan "${1#--}" ;; esac || return $?
            if [ "$1" = --scan ]; then deb_summary; else deb_view list; fi
            return "$deb_partial" ;;
    esac
    [ -t 0 ] && [ -t 1 ] && command -v fzf >/dev/null || { echo 'Interactive terminal and fzf required; use --scan' >&2; return 1; }
    if [ -z "${FZF_DEFAULT_OPTS_FILE:-}" ] && [ -f "$repo/config/fzf/fzfrc" ]; then
        export FZF_DEFAULT_OPTS_FILE="$repo/config/fzf/fzfrc"
    fi
    if [ "${1:-}" = --dry-run ]; then
        deb_user_scan $deb_enabled || return $?
        deb_select || return 0
        return "$deb_partial"
    fi
    loop 'shh debloater' 'Enter: open   Esc: back' deb_lines deb_act "$(deb_banner)"
}
