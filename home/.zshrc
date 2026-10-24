# ~/.zshrc - read by every interactive zsh (every new terminal)
# for now: the prompt and fastfetch; history, keys etc. come later

# the prompt: <artix icon> kiran ~/Shh-dotfiles %
#   $''     the artix icon of the nerd font (nf-linux-artix), written
#                 as a code: $'...' turns \uXXXX into that character
#   %F{N} ... %f  text in color N of the terminal palette (see foot.ini):
#                 15 bright white, 8 gray, 1 red
#   %n            user name
#   %~            current directory, home shown as ~
#   %(?.A.B)      A if the last command succeeded, B if it failed:
#                 the % turns red after an error
#   %#            % for a normal user, # for root
# the linux console (TTY, TERM=linux) has no nerd font, so no artix icon there
if [ "$TERM" = linux ]; then
    PROMPT='%F{15}%n %F{8}%~ %(?.%F{15}.%F{1})%#%f '
else
    PROMPT='%F{15}'$''' %n %F{8}%~ %(?.%F{15}.%F{1})%#%f '
fi

# system info in every new foot window. not on the TTY: that's for rescue,
# keep it plain and fast
if [ "$TERM" = foot ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
