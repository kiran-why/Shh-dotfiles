# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# █ ▀ █▄▄     ▄▄▄ █▄▄  
# █ █ █  █   ▀▀▄▄ █  █ 
# ▀ ▀ ▀▀▀  ▀ ▀▀▀  ▀  ▀ 
# lib.sh - colors, messages, lists and the logo for install.sh, link.sh and shh
# not run on its own: loaded with  . "$dots_path/lib.sh"

# ▄▀▀▀ ▄▀▀▄ █    ▄▀▀▄ █▀▀▄ ▄▀▀▀ 
# █    █  █ █    █  █ █▀█   ▀▀▄ 
#  ▀▀▀  ▀▀  ▀▀▀▀  ▀▀  ▀  ▀ ▀▀▀  

# white and red only; no colors when the output is not a terminal
if [ -t 1 ]; then
    red=$(printf '\033[1;31m')
    white=$(printf '\033[1;37m')
    dim=$(printf '\033[2m')
    reset=$(printf '\033[0m')
else
    red='' white='' dim='' reset=''
fi

# █▄ ▄█ █▀▀▀ ▄▀▀▀ ▄▀▀▀ ▄▀▀▄ ▄▀▀▀ █▀▀▀ ▄▀▀▀ 
# █ ▀ █ █▀▀   ▀▀▄  ▀▀▄ █▀▀█ █ ▀█ █▀▀   ▀▀▄ 
# ▀   ▀ ▀▀▀▀ ▀▀▀  ▀▀▀  ▀  ▀  ▀▀▀ ▀▀▀▀ ▀▀▀  

# symbols in front of messages; plain ascii on the TTY (its font lacks ✓ ✗)
case "${TERM:-}" in
    linux) sym_ok='+' sym_info='-' sym_fail='x' ;;
    *)     sym_ok='✓' sym_info='·' sym_fail='✗' ;;
esac
sym_warn='!'
sym_bak='~'

# msg COLOR SYMBOL TEXT
msg() {
    printf '  %s%s%s %s\n' "$1" "$2" "$reset" "$3"
}

# step: a section header, like pacman's ":: Synchronizing"
step() { printf '\n%s::%s %s%s%s\n' "$red" "$reset" "$white" "$1" "$reset"; }
info() { msg "$dim"   "$sym_info" "$1"; }
ok()   { msg "$white" "$sym_ok"   "$1"; }
warn() { msg "$red"   "$sym_warn" "$1"; }

# error TEXT: print and stop the script
error() {
    msg "$red" "$sym_fail" "$1" >&2
    exit 1
}

# █    ▀█▀ ▄▀▀▀ ▀▀█▀▀ ▄▀▀▀ 
# █     █   ▀▀▄   █    ▀▀▄ 
# ▀▀▀▀ ▀▀▀ ▀▀▀    ▀   ▀▀▀  

# read_list FILE: lines without empty ones and comments
read_list() {
    grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true
}

# without LIST: stdin minus the lines that are in LIST (one per line)
without() {
    if [ -n "$1" ]; then grep -vxF -- "$1" || true; else cat; fi
}

# ▄▀▀▀ █  █ ▄▀▀▄ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀ 
# █    █▀▀█ █  █  █  █    █▀▀   ▀▀▄ 
#  ▀▀▀ ▀  ▀  ▀▀  ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀ 

# what shh config picked: NAME=VALUE lines, editable by hand; not in the
# repo, so shh update remembers it
shh_config="$HOME/.config/shh/config"

# setting NAME DEFAULT: NAME from $shh_config (the last line wins), or DEFAULT
setting() {
    local value
    value=$(sed -n "s/^$1=//p" "$shh_config" 2>/dev/null | tail -n 1 |
        sed 's/#.*//; s/[[:space:]]//g')
    printf '%s\n' "${value:-$2}"
}

# part_on NAME GROUP DEFAULT: is the part turned on? (components.txt)
part_on() {
    case "$2" in
        # two parts: noxwayland (the sway line) or xwayland (the package)
        xwayland)
            if [ "$(setting xwayland no)" = yes ]; then [ "$1" = xwayland ]; else [ "$1" = noxwayland ]; fi ;;
        *)        [ "$(setting "$1" "${3:-yes}")" = yes ] ;;
    esac
}

# off_items COMPONENTS FIELD: one per line, FIELD (2 packages, 3 files,
# 4 services) of the parts in COMPONENTS turned off. Shared by a part that
# is on: not off
off_items() {
    local name group default line words on='' off=''
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        IFS='|' read -r name _ _ _ _ group default <<EOF
$line
EOF
        words=$(printf '%s\n' "$line" | cut -d'|' -f"$2")
        if part_on "$name" "$group" "$default"; then on="$on $words"; else off="$off $words"; fi
    done <<EOF
$(read_list "$1")
EOF
    # unquoted on purpose: one word per line
    printf '%s\n' $off | grep -v '^$' | without "$(printf '%s\n' $on | grep -v '^$')"
}

# █    ▄▀▀▄ ▄▀▀▀ ▄▀▀▄ 
# █    █  █ █ ▀█ █  █ 
# ▀▀▀▀  ▀▀   ▀▀▀  ▀▀  

# the big logo needs 94 columns, a narrower terminal gets the small one
logo() {
    local cols
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)

    if [ "${cols:-0}" -ge 94 ]; then
        logo_big
        tagline 27
    else
        logo_small
        tagline 9
    fi
}

# tagline N: the tagline, N spaces from the left to center it
tagline() {
    printf '\n%*s%s%s%s\n\n' "$1" '' "$dim" '// quiet  // minimal  // no useless GUI' "$reset"
}

logo_big() {
    printf '%s' "$white"
    cat <<'EOF'
         █▄        █▄                  ▄█▀          ▄█▀    ▄█▀█▄ ▄▀▀▄  ▄█▀
         █▓▌       █▓▌                ▐▓█▄         ▐▓█▄▄  █▓▌  █▌▌■▀▐▌▐▓█
   ▄▄██▄▐▓▓█░▄▓▄  ▐▓▓█░▄▓▄        ▄▓▄░▀▓▓▌  ▄▓██▄  ▀▓▓▌  ▐▓▓▄  ▀ ▀■▓▀ ▐▓▓▌      ▄▄█▄▄    ▄▄██▄
  ▓▓  ▀▀▐▒▒ ▀ ▀██ ▐▒▒ ▀ ▀██      ██▀ ▀ ▒▒  ▓▓▀  ▀▓ ▐▒▒    ▒▒▌▀█▄  ▄▄▓▀▐▒▒      ▓█▀ ▀▓▓  ▓▓  ▀▀
   ▀▀▀▄  ░░▌   ▐▓▌ ░░▌   ▐▓▌    ▐▓▌    ░░▌▐▒▌   ▐▓▌ ░░▌  ▐░░  ░   ▐▓▓  ░░▌    ▐▒▌  ▄▒▀   ▀▀▀▄
▐█▌  ░█░ ██▓  ▄██  ██▓  ▄██      ██▄  ▐██ ▐░░▄ ▄▒▒  ▐██  ██▌       ▒▒▌ ▐██   ▄ ▀░░▀   ▐█▌  ░█░
 █░▄██▀  ▐█▌  █▀   ▐█▌  █▀        ▀░█▄██▌  ▀█░█░▀    █░▀▀░█       ▐░░   █░█▄█▀  ▀█▄  ▄ █░▄██▀
  ▀▀░     ▀    ▀    ▀    ▀           ▀▀▀      ▀     ▀      ▀      ██▀    ▀▀▀       ▀▀   ▀▀░
                                                                  ▀▄
EOF
    printf '%s' "$reset"
}

# the small slant logo, 57 columns
logo_small() {
    printf '%s%-26s%s  %s%s%s\n' "$white" '   _____ __    __' "$reset" "$white" '' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  / ___// /_  / /_' "$reset" "$white" '     __     __  ____ __' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  \__ \/ __ \/ __ \' "$reset" "$white" ' ___/ /__  / /_/ _(_) /__ ___' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" ' ___/ / / / / / / / _ _ _' "$reset" "$white" '/ _  / _ \/ __/ _/ / / -_|_-<' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '/____/_/ /_/_/ /_/ (_|_|_)' "$reset" "$white" '\_,_/\___/\__/_//_/_/\__/___/' "$reset"
}
