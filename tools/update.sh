# Shhware update API 1

linked_checkout() {
    local lib root
    lib=$(readlink -f "$share/lib.sh") && [ -f "$lib" ] || error "broken checkout link: $share/lib.sh"
    root=${lib%/lib/lib.sh}
    [ "$root" != "$lib" ] && [ -f "$root/install.sh" ] && [ -f "$root/tools/shh" ] &&
        [ -f "$root/lib/link.sh" ] || error "invalid linked checkout: $lib"
    printf '%s\n' "$root"
}

update() {
    # 'tmp' is not local: the EXIT trap runs after update returns.
    local repo

    # Installed with '--link': update the repo the links point to.
    if [ -L "$share/lib.sh" ]; then
        repo=$(linked_checkout)
        step "updating the repo: $repo"
        git -C "$repo" pull --ff-only ||
            error "git pull failed (local changes? see git -C $repo status)"
        # 'exec', as 'git pull' may have replaced this very file.
        exec sh "$repo/install.sh"
    fi

    [ "$(setting mode copy)" != link ] ||
        error "link mode requires a persistent checkout; run sh install.sh there"
    tmp=$(mktemp -d) || error "cannot make a temporary folder"
    # An older downloaded installer may allow a mode change in its first-run menu.
    trap 'if [ "$(setting mode copy)" = link ] || [ -L "$share/lib.sh" ]; then
        warn "retained checkout: $tmp"
    else
        rm -rf "$tmp"
    fi' EXIT
    step "downloading $repo_url"
    git clone --depth 1 "$repo_url" "$tmp" || error "git clone failed"
    SHH_TEMP_CHECKOUT=$(cd "$tmp" && pwd -P) sh "$tmp/install.sh"
}

preview() {
    local src="$repo" mode
    info "remote state unknown (no fetch or network access)"
    if [ -L "$share/lib.sh" ]; then
        src=$(linked_checkout)
    elif [ "$from_repo" = 0 ]; then
        src="$HOME/Shh-dotfiles"
    fi
    mode=$(setting mode "$mode_now")
    case "$mode" in copy|link) ;; *) error "unknown install mode: $mode" ;; esac
    if [ "$1" = update ]; then
        if [ "$mode_now" = link ]; then info "apply: git pull --ff-only in $src, then install"
        elif [ "$mode" = link ]; then error "link mode requires a persistent checkout; run sh install.sh there"
        else info "apply: clone $repo_url into a temporary checkout, then install"
        fi
    fi
    [ -f "$src/tools/shh" ] && [ -f "$src/lib/link.sh" ] ||
        error "no local checkout at $src; run sh tools/shh $* from your checkout"
    step "local checkout: $src"
    if [ "$mode_now" = link ]; then
        info "linked files share the checkout content; edits through a link have no separate installed copy"
    fi
    if [ "$1" = update ]; then
        [ -r "$src/system/$distro/distro.sh" ] || error "unsupported distro: $distro"
        . "$src/system/$distro/distro.sh"
        packages_dir="$src/system/$distro/packages"
        components_file="$src/components/${distro}_components.txt"
        hardware_script="$src/scripts/hardware"
        recipes_dir="$src/system/$distro/repo"
        [ -f "$shh_config" ] || info "first install: the selection menu may change these defaults"
        info "apply: update the system, install missing selections, configure GPU, network, services and login, then install dotfiles"
        info "packages below use the local installed database; upgrade versions and dependency changes are unknown"
        check_packages preview
        if command -v recipe_preview >/dev/null; then
            step "KISS recipe changes (possible rebuilds only)"
            show_recipe_changes
        fi
    fi
    DOTS_NO_LOGO=1 sh "$src/lib/link.sh" --diff "--$mode"
}
