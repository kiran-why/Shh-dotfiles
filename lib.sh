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

# msg COLOR TAG TEXT: print "[ tag  ] text" with a colored tag
# the text goes in as an argument, not into the format string,
# so a "%" in a file name can't break printf
msg() {
    printf '%s[ %-4s ]%s %s\n' "$1" "$2" "$reset" "$3"
}

step() { echo; msg "$red" "==" "$1"; }
info() { msg "$dim"   ".."   "$1"; }
ok()   { msg "$white" "ok"   "$1"; }
warn() { msg "$red"   "warn" "$1"; }

# error TEXT: print to stderr and stop the whole script with failure
error() {
    msg "$red" "FAIL" "$1" >&2
    exit 1
}

### LOGO ###

# the whole logo in white, tagline dimmed.
# every line is printf '%s' ... with the art in single quotes,
# so backslashes and ' in the art are printed as is.
# %-27s pads the left part to the same width, so the columns line up
logo() {
    printf '%s%-27s%s  %s%s%s\n' "$white" '   _____ __    __' "$reset" "$white" '' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$white" '  / ___// /_  / /_' "$reset" "$white" '     __     __  ____ __' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$white" '  \__ \/ __ \/ __ \' "$reset" "$white" ' ___/ /__  / /_/ _(_) /__ ___' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$white" ' ___/ / / / / / / /  _ _ _' "$reset" "$white" '/ _  / _ \/ __/ _/ / / -_|_-<' "$reset"
    printf '%s%-27s%s  %s%s%s\n' "$white" '/____/_/ /_/_/ /_/  (_|_|_)' "$reset" "$white" '\_,_/\___/\__/_//_/_/\__/___/' "$reset"
    printf '\n%s%s%s\n\n' "$dim" '      // quiet  // minimal  // no useless GUI' "$reset"
}
