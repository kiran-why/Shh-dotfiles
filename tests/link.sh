#!/bin/sh
# tests/link.sh - lib/link.sh in a throwaway HOME, for every distro:
# copies (your file goes to .bak), a second run, --uninstall (a changed file
# is kept, yours comes back), --link. Not as root: link.sh refuses root.
# prints PASS / FAIL per check; exit code = the number of FAILs (0 = all good)
# run: sh tests/link.sh

set -u

repo=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

# result WHAT CODE: PASS when CODE is 0
result() {
    if [ "$2" -eq 0 ]; then
        echo "PASS $1"
    else
        echo "FAIL $1"
        fails=$((fails + 1))
    fi
}

# fresh_home NAME: an empty HOME with your own foot.ini in it
fresh_home() {
    home="$tmp/$1"
    mkdir -p "$home/.config/foot"
    echo 'mine' >"$home/.config/foot/foot.ini"
}

# link SCRIPT ARGS...: link.sh in $home; its output in $tmp/log, its code in $rc
link() {
    HOME="$home" SHH_DISTRO="$distro" DOTS_NO_LOGO=1 sh "$@" >"$tmp/log" 2>&1
    rc=$?
    # the output only when something goes wrong
    [ "$rc" -eq 0 ] || sed 's/^/    /' "$tmp/log"
}

# count_bak: .bak-DATE files in $home
count_bak() {
    find "$home" -name '*.bak-*' | wc -l | tr -d ' '
}

# only_mine: the only file left in $home is your foot.ini, with your text
only_mine() {
    [ "$(find "$home" -type f -o -type l)" = "$home/.config/foot/foot.ini" ] &&
        grep -qx mine "$home/.config/foot/foot.ini"
}

for distro in artix void; do
    echo "== $distro"

    # 1-2: copies; our foot.ini takes the place, yours goes to foot.ini.bak-DATE
    fresh_home "$distro-copy"
    link "$repo/lib/link.sh" --copy
    result "$distro copy: exit 0" "$rc"
    set -- "$home"/.config/foot/foot.ini.bak-*
    [ -f "$1" ] && grep -qx mine "$1"
    result "$distro copy: your foot.ini kept as $(basename "$1")" $?
    cmp -s "$repo/config/foot/foot.ini" "$home/.config/foot/foot.ini"
    result "$distro copy: foot.ini is the repo one" $?

    # 3: a second run changes nothing
    baks=$(count_bak)
    link "$repo/lib/link.sh" --copy
    result "$distro again: exit 0" "$rc"
    grep -q 'done (copy): 0 put in place' "$tmp/log"
    result "$distro again: 0 files put in place" $?
    [ "$(count_bak)" = "$baks" ]
    result "$distro again: no new .bak" $?

    # 4: a config changed after the install stays
    echo '# my edit' >>"$home/.config/sway/config"
    link "$home/.local/share/shh/link.sh" --uninstall
    result "$distro uninstall: exit 0" "$rc"
    grep -q "changed since install, kept: $home/.config/sway/config" "$tmp/log" &&
        grep -qx '# my edit' "$home/.config/sway/config"
    result "$distro uninstall: changed sway/config kept" $?

    # 5: uninstall right after the install: all gone, your foot.ini back
    fresh_home "$distro-clean"
    link "$repo/lib/link.sh" --copy
    link "$home/.local/share/shh/link.sh" --uninstall
    result "$distro clean uninstall: exit 0" "$rc"
    only_mine
    result "$distro clean uninstall: only your foot.ini left" $?

    # 6: --link: share points into the repo (lib/ and system/DISTRO/)
    fresh_home "$distro-link"
    link "$repo/lib/link.sh" --link
    result "$distro link: exit 0" "$rc"
    share="$home/.local/share/shh"
    [ "$(readlink "$share/lib.sh")" = "$repo/lib/lib.sh" ] &&
        [ "$(readlink "$share/link.sh")" = "$repo/lib/link.sh" ] &&
        [ "$(readlink "$share/distro.sh")" = "$repo/system/$distro/distro.sh" ] &&
        [ "$(readlink "$share/services.txt")" = "$repo/system/$distro/services.txt" ] &&
        [ "$(readlink "$share/packages/common.csv")" = "$repo/system/$distro/packages/common.csv" ]
    result "$distro link: share links to lib/ and system/$distro/" $?
    link "$share/link.sh" --uninstall
    result "$distro link uninstall: exit 0" "$rc"
    only_mine
    result "$distro link uninstall: only your foot.ini left" $?
done

echo
if [ "$fails" -eq 0 ]; then echo "all passed"; else echo "$fails failed"; fi
exit "$fails"
