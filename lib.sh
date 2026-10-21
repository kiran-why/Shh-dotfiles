# lib.sh - shared helpers for the Shh... dotfiles scripts
#
# not a script on its own: other scripts load it with
#   . "$dots_path/lib.sh"
# "." (source) runs this file inside the calling script,
# so the functions and variables below become available there

### COLORS ###

# palette: white and red only.
# \033[...m codes: 1 bold, 2 dim, 31 red, 37 white
# colors only when printing to a terminal, not into a file or pipe
if [ -t 1 ]; then
    red=$(printf '\033[1;31m')
    white=$(printf '\033[1;37m')
    dim=$(printf '\033[2m')
    reset=$(printf '\033[0m')
else
    red='' white='' dim='' reset=''
fi

### MESSAGES ###

# symbols in front of messages. The linux console (TTY, TERM=linux) uses a
# small built-in font that probably lacks ✓ and ✗, so it gets plain ascii;
# terminals like foot or ssh windows get the unicode ones
case "${TERM:-}" in
    linux) sym_ok='+' sym_info='-' sym_fail='x' ;;
    *)     sym_ok='✓' sym_info='·' sym_fail='✗' ;;
esac
sym_warn='!'
sym_bak='~'

# msg COLOR SYMBOL TEXT: print "  SYMBOL text" with a colored symbol.
# the text goes in as an argument, not into the format string,
# so a "%" in a file name can't break printf
msg() {
    printf '  %s%s%s %s\n' "$1" "$2" "$reset" "$3"
}

# step: a section header, not indented, like pacman's ":: Synchronizing"
step() { printf '\n%s::%s %s%s%s\n' "$red" "$reset" "$white" "$1" "$reset"; }
info() { msg "$dim"   "$sym_info" "$1"; }
ok()   { msg "$white" "$sym_ok"   "$1"; }
warn() { msg "$red"   "$sym_warn" "$1"; }

# error TEXT: print to stderr and stop the whole script with failure
error() {
    msg "$red" "$sym_fail" "$1" >&2
    exit 1
}

### LOGO ###

# the big logo is 94 columns wide; in a narrower terminal it would wrap,
# so there we print the small one instead.
# "stty size" prints "ROWS COLUMNS" of the terminal on stdin;
# not a terminal -> empty output -> small logo
logo() {
    local cols
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)

    if [ "${cols:-0}" -ge 94 ]; then
        logo_big
    else
        logo_small
    fi
    printf '\n%s%s%s\n\n' "$dim" '      // quiet  // minimal  // no useless GUI' "$reset"
}

# <<'EOF' is a here-document: the lines up to EOF go to cat's input as is.
# the quotes around EOF turn off $ and \ expansion inside, so the art stays untouched
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

# the old slant logo, 57 columns
# %-26s pads the left part to the same width, so the columns line up
logo_small() {
    printf '%s%-26s%s  %s%s%s\n' "$white" '   _____ __    __' "$reset" "$white" '' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  / ___// /_  / /_' "$reset" "$white" '     __     __  ____ __' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '  \__ \/ __ \/ __ \' "$reset" "$white" ' ___/ /__  / /_/ _(_) /__ ___' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" ' ___/ / / / / / / / _ _ _' "$reset" "$white" '/ _  / _ \/ __/ _/ / / -_|_-<' "$reset"
    printf '%s%-26s%s  %s%s%s\n' "$white" '/____/_/ /_/_/ /_/ (_|_|_)' "$reset" "$white" '\_,_/\___/\__/_//_/_/\__/___/' "$reset"
}
