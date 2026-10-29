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
