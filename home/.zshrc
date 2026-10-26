# ~/.zshrc - read by every interactive zsh (every new terminal)
# prompt, history, Tab completion, keys, suggestions, highlighting, fastfetch

# the prompt, two lines and an empty line before it:
#
#   ~/Shh-dotfiles
#   <artix icon> : _
#
#   $'...'        turns \n into a new line and  into the artix icon
#                 of the nerd font (nf-linux-artix)
#   %F{N} ... %f  text in color N of the terminal palette (see foot.ini):
#                 15 bright white, 1 red
#   %~            current directory, home shown as ~
#   %(?.A.B)      A if the last command succeeded, B if it failed:
#                 the : turns red after an error
# the linux console (TTY, TERM=linux) has no nerd font, so no icon there
if [ "$TERM" = linux ]; then
    PROMPT=$'\n%F{15}%~%f\n%(?.%F{15}.%F{1}):%f '
else
    PROMPT=$'\n%F{15}%~%f\n%F{15}%f %(?.%F{15}.%F{1}):%f '
fi

# history: commands are kept in a file between sessions.
#   HISTSIZE          how many lines the shell keeps in memory
#   SAVEHIST          how many lines go into the file
#   SHARE_HISTORY     every terminal sees the commands of the others
#   HIST_IGNORE_ALL_DUPS  a repeated command replaces its older copy
#   HIST_IGNORE_SPACE a command typed with a space in front is not kept
#                     (handy for anything with a password in it)
mkdir -p ~/.local/state/zsh
HISTFILE=~/.local/state/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

# Tab completion: commands, paths, flags of many programs.
#   autoload -Uz NAME  load a zsh function from its library when needed
#   compinit           turns completion on; -d: where it keeps its cache
#   menu select        a second Tab shows a list to walk with the arrows
#   matcher-list       small letters also match capitals: "doc" -> "Documents"
mkdir -p ~/.cache/zsh
autoload -Uz compinit
compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# keys: what the keyboard does while typing a command.
# bindkey KEYS WIDGET: KEYS is what the terminal sends for that key,
# a WIDGET is a zsh action. Some keys are sent differently by foot and
# by the TTY, so both are bound. -e: emacs-style keys (Ctrl+A, Ctrl+E ...)
bindkey -e
# Ctrl+Left / Ctrl+Right: one word back / forward
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
# Home / End: start / end of the line; Delete: the letter under the cursor
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char
# Up / Down: walk the history, but only commands that start like the
# one already typed ("git" + Up -> the last git command).
# zle -N makes a loaded function usable as a widget
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# br: broot, and on exit cd into the folder picked there (alt+enter).
# broot prints this function itself (broot docs, "install br"); the
# install state is set once by install.sh, so broot doesn't offer to
# write into this file on its first start
if command -v broot >/dev/null; then
    eval "$(broot --print-shell-function zsh)"
fi

# plugins from the repos (packages/common.csv), loaded only if installed.
# not on the TTY: its console has real colors (cyan, purple ...) instead
# of our grays, and the TTY is for rescue, keep it plain
plugins=/usr/share/zsh/plugins
[ "$TERM" = linux ] && plugins=/nonexistent

# suggestions: while typing, the rest of a matching command from the
# history shows in gray (color 8); Right arrow or End accepts it
if [ -r "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    source "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# highlighting while typing: a command that exists stays plain white,
# an unknown one turns gray and underlined (underlined, so it doesn't look
# like a gray suggestion). The plugin must be loaded last, after
# everything that adds keys or widgets.
# typeset -A: ZSH_HIGHLIGHT_STYLES is an associative array (name -> style);
# 'none' = no style, the normal text color
if [ -r "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    typeset -A ZSH_HIGHLIGHT_STYLES
    for style in command builtin alias function precommand hashed-command reserved-word arg0; do
        ZSH_HIGHLIGHT_STYLES[$style]='none'
    done
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=8,underline'
fi
unset plugins style

# system info in every new foot window. not on the TTY: that's for rescue,
# keep it plain and fast
if [ "$TERM" = foot ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
