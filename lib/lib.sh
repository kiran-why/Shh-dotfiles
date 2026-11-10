# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

# █ ▀ █▄▄     ▄▄▄ █▄▄  
# █ █ █  █   ▀▀▄▄ █  █ 
# ▀ ▀ ▀▀▀  ▀ ▀▀▀  ▀  ▀ 
# Colors, messages, lists and the logo for install.sh, link.sh and shh.
#
# Not run on its own: a script loads it with '. lib/lib.sh'.

# ▄▀▀▀ ▄▀▀▄ █    ▄▀▀▄ █▀▀▄ ▄▀▀▀ 
# █    █  █ █    █  █ █▀█   ▀▀▄ 
#  ▀▀▀  ▀▀  ▀▀▀▀  ▀▀  ▀  ▀ ▀▀▀  

# Use white and red only, and no colors when the output is not a terminal.
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

# Put a symbol in front of each message.
#
# The font of the TTY lacks the check mark and the cross, so it gets ASCII.
case "${TERM:-}" in
    linux) sym_ok='+' sym_info='-' sym_fail='x' ;;
    *)     sym_ok='✓' sym_info='·' sym_fail='✗' ;;
esac
sym_warn='!'
sym_bak='~'

# Print TEXT with a colored SYMBOL in front: msg COLOR SYMBOL TEXT.
msg() {
    printf '  %s%s%s %s\n' "$1" "$2" "$reset" "$3"
}

# Print a section header, like pacman's ":: Synchronizing".
step() { printf '\n%s::%s %s%s%s\n' "$red" "$reset" "$white" "$1" "$reset"; }
info() { msg "$dim"   "$sym_info" "$1"; }
ok()   { msg "$white" "$sym_ok"   "$1"; }
warn() { msg "$red"   "$sym_warn" "$1"; }

# Print TEXT as an error and stop the script.
error() {
    msg "$red" "$sym_fail" "$1" >&2
    exit 1
}

# █    ▀█▀ ▄▀▀▀ ▀▀█▀▀ ▄▀▀▀ 
# █     █   ▀▀▄   █    ▀▀▄ 
# ▀▀▀▀ ▀▀▀ ▀▀▀    ▀   ▀▀▀  

# Print the lines of a file, without the empty ones and the comments.
read_list() {
    grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true
}

# Print stdin without the lines that are in the list '$1' (one per line).
without() {
    if [ -n "$1" ]; then grep -vxF -- "$1" || true; else cat; fi
}

# ▄▀▀▀ █  █ ▄▀▀▄ ▀█▀ ▄▀▀▀ █▀▀▀ ▄▀▀▀ 
# █    █▀▀█ █  █  █  █    █▀▀   ▀▀▄ 
#  ▀▀▀ ▀  ▀  ▀▀  ▀▀▀  ▀▀▀ ▀▀▀▀ ▀▀▀ 

# Find the distro: the ID from /etc/os-release (artix, void, kiss).
#
# It picks system/ID/ and components/ID_components.txt. SHH_DISTRO
# overrides it, for tests on another system.
distro=${SHH_DISTRO:-}
# Check that the file is there first: '.' on a missing file stops dash.
[ -n "$distro" ] || [ ! -r /etc/os-release ] || distro=$(. /etc/os-release && echo "${ID:-}")

# Keep what 'shh config' picked as NAME=VALUE lines, editable by hand.
#
# The file is not in the repo, so 'shh update' remembers the choices.
shh_config="$HOME/.config/shh/config"

# Print the value of NAME from the config, or DEFAULT: setting NAME DEFAULT.
#
# The last line with NAME wins.
setting() {
    local value
    value=$(sed -n "s/^$1=//p" "$shh_config" 2>/dev/null | tail -n 1 |
        sed 's/#.*//; s/[[:space:]]//g')
    printf '%s\n' "${value:-$2}"
}

# Check if a part is turned on: part_on NAME GROUP DEFAULT (components.txt).
part_on() {
    case "$2" in
        # Two parts: noxwayland (the sway line) or xwayland (the package).
        xwayland)
            if [ "$(setting xwayland no)" = yes ]; then [ "$1" = xwayland ]; else [ "$1" = noxwayland ]; fi ;;
        # One of the two editors (settings > editor).
        editor)   [ "$(setting editor vim)" = "$1" ] ;;
        # One of the two file managers (settings > file manager).
        files)    [ "$(setting files broot)" = "$1" ] ;;
        *)        [ "$(setting "$1" "${3:-yes}")" = yes ] ;;
    esac
}

# Print the graphics drivers to install, one per line.
#
# On 'auto' these are the cards scripts/hardware found ('$1'), else the
# ones picked in 'shh config' (gpu=amd,nvidia). Every name has a list in
# system/DISTRO/packages/NAME.csv.
gpu_drivers() {
    local gpu card
    gpu=$(setting gpu auto)
    if [ "$gpu" = auto ]; then
        printf '%s\n' "$1"
        return 0
    fi
    for card in $(printf '%s\n' "$gpu" | tr , ' '); do
        # Take the open or the older 580xx driver, whichever fits the card found.
        [ "$card" != nvidia ] || card=$(printf '%s\n' "$1" nvidia | grep -x 'nvidia\|nvidia-580xx' | head -n 1)
        echo "$card"
    done
}

# Print one field of the parts that are turned off, one word per line.
#
# off_items COMPONENTS FIELD, where FIELD is 2 (packages), 3 (files) or
# 4 (services). A word shared with a part that is on is left out.
off_items() {
    local name group default line words on='' off=''
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        IFS='|' read -r name _ _ _ group default <<EOF
$line
EOF
        words=$(printf '%s\n' "$line" | cut -d'|' -f"$2")
        if part_on "$name" "$group" "$default"; then on="$on $words"; else off="$off $words"; fi
    done <<EOF
$(read_list "$1")
EOF
    # Unquoted on purpose: one word per line.
    printf '%s\n' $off | grep -v '^$' | without "$(printf '%s\n' $on | grep -v '^$')"
}

# █    ▄▀▀▄ ▄▀▀▀ ▄▀▀▄ 
# █    █  █ █ ▀█ █  █ 
# ▀▀▀▀  ▀▀   ▀▀▀  ▀▀  

# Print the logo. The big one needs 94 columns, a narrower terminal gets
# the small one.
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

# Print the tagline, N spaces from the left to center it: tagline N.
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

# Print the small slant logo, 57 columns wide.
logo_small() {
    printf '%s%-26s%s  %s%s%s\n' "$white" '   _____ __    __' "$reset" "$white" '' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  / ___// /_  / /_' "$reset" "$white" '     __     __  ____ __' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  \__ \/ __ \/ __ \' "$reset" "$white" ' ___/ /__  / /_/ _(_) /__ ___' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" ' ___/ / / / / / / / _ _ _' "$reset" "$white" '/ _  / _ \/ __/ _/ / / -_|_-<' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '/____/_/ /_/_/ /_/ (_|_|_)' "$reset" "$white" '\_,_/\___/\__/_//_/_/\__/___/' "$reset"
}
