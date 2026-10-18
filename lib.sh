# lib.sh - shared helpers for the Shh... dotfiles scripts
#
# not a script on its own: other scripts load it with
#   . "$dots_path/lib.sh"
# "." (source) runs this file inside the calling script,
# so the functions and variables below become available there

### COLORS ###

# colors only when printing to a terminal, not into a file or pipe
if [ -t 1 ]; then
    red=$(printf '\033[31m')
    green=$(printf '\033[32m')
    yellow=$(printf '\033[33m')
    blue=$(printf '\033[34m')
    dim=$(printf '\033[2m')
    reset=$(printf '\033[0m')
else
    red='' green='' yellow='' blue='' dim='' reset=''
fi

### MESSAGES ###

# msg COLOR TAG TEXT: print "[ tag  ] text" with a colored tag
# the text goes in as an argument, not into the format string,
# so a "%" in a file name can't break printf
msg() {
    printf '%s[ %-4s ]%s %s\n' "$1" "$2" "$reset" "$3"
}

step() { echo; msg "$blue" "==" "$1"; }
info() { msg "$blue"   ".."   "$1"; }
ok()   { msg "$green"  "ok"   "$1"; }
warn() { msg "$yellow" "warn" "$1"; }

# error TEXT: print to stderr and stop the whole script with failure
error() {
    msg "$red" "FAIL" "$1" >&2
    exit 1
}

### LOGO ###

# "Shh..." in blue, "dotfiles" in green, tagline dimmed.
# every line is printf '%s' ... with the art in single quotes,
# so backslashes and ' in the art are printed as is.
# %-27s pads the left part to the same width, so the columns line up
logo() {
    printf '%s%-27s%s  %s%s%s\n' "$blue" '   _____ __    __' "$reset" "$green" '' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$blue" '  / ___// /_  / /_' "$reset" "$green" '     __     __  ____ __' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$blue" '  \__ \/ __ \/ __ \' "$reset" "$green" ' ___/ /__  / /_/ _(_) /__ ___' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$blue" ' ___/ / / / / / / /  _ _ _' "$reset" "$green" '/ _  / _ \/ __/ _/ / / -_|_-<' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$blue" '/____/_/ /_/_/ /_/  (_|_|_)' "$reset" "$green" '\_,_/\___/\__/_//_/_/\__/___/' "$reset"
    printf '\n%s%s%s\n\n' "$dim" '      // quiet  // minimal  // no useless GUI' "$reset"
}
