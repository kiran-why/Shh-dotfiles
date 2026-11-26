# Shhware components API 1

show_recipe_changes() {
    local changes
    changes=$(recipe_preview)
    printf '%s\n' "${changes:-No pending recipe changes.}"
}

# Check the packages: common.csv and the driver lists, like install.sh.
check_packages() {
    step "packages"

    local hw hardware csv names missing pkg problem=bad
    [ "${1:-}" != preview ] || problem=warn
    for csv in "$packages_dir/common.csv" "$components_file"; do
        if [ ! -f "$csv" ] || [ ! -r "$csv" ]; then
            "$problem" "UNAVAILABLE: cannot check packages without $csv"
            return
        fi
    done
    if [ "$distro" = kiss ]; then
        local db="${KISS_ROOT:-}/${pkg_db:-var/db/kiss/installed}"
        if [ ! -d "$db" ] || [ ! -r "$db" ] || [ ! -x "$db" ]; then
            "$problem" "UNAVAILABLE: installed packages unknown: cannot read $db"
            return
        fi
    fi
    if [ "${1:-}:$distro" != preview:kiss ] && ! command -v "$pkg_query" >/dev/null; then
        "$problem" "UNAVAILABLE: cannot query installed packages: $pkg_query missing"
        return
    fi
    hardware=$(sh "$hardware_script" 2>/dev/null || true)
    names=$(for hw in common $(gpu_drivers "$hardware"); do
        csv="$packages_dir/$hw.csv"
        [ ! -f "$csv" ] || read_list "$csv" | cut -d, -f2
    done | without "$(off_items "$components_file" 2)")

    # pkg_missing (distro.sh) prints the missing ones.
    if [ "$distro" = artix ]; then
        local rc=0
        missing=$(pacman -T $names) || rc=$?
        if [ "$rc" != 0 ] && { [ "$rc" != 127 ] || [ -z "$missing" ]; }; then
            "$problem" "UNAVAILABLE: installed packages unknown: pacman -T failed ($rc)"
            return
        fi
    elif [ "$distro" = void ] && ! xbps-query -l >/dev/null; then
        "$problem" "UNAVAILABLE: installed packages unknown: xbps-query failed"
        return
    else
        missing=$(pkg_missing $names)
    fi

    for pkg in $missing; do
        if [ "${1:-}" = preview ]; then info "would install: $pkg"; else bad "not installed: $pkg (sh install.sh)"; fi
    done
    [ -n "$missing" ] || ok "all $(printf '%s\n' "$names" | awk 'NF { n++ } END { print n+0 }') packages installed"
}
