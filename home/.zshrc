# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄       ▄▀   ▄▄▄▄  ▄▄▄ █▄▄  ▄ ▄▄  ▄▄▄ 
# ▀ ▀▄▀  ▄▀      ▄▀  ▀▀▄▄ █  █ █▀   █    
#       ▀     ▀ ▀▀▀▀ ▀▀▀  ▀  ▀ ▀     ▀▀▀   
# Zsh configuration.  


# █▀▀▄ █▀▀▄ ▄▀▀▄ █▄ ▄█ █▀▀▄ ▀▀█▀▀ 
# █▀▀  █▀█  █  █ █ ▀ █ █▀▀    █   
# ▀    ▀  ▀  ▀▀  ▀   ▀ ▀      ▀   
                                
# The prompt is the folder, then "<distro icon> :", where ':' turns red
# after an error. '%F{N}' is a color from foot.ini.
#
# The icon is picked by ID in /etc/os-release from the Nerd Fonts
# nf-linux-* set. KISS has no icon there, so it gets a heart
# (nf-md-heart), a play on the name. Any other distro gets Tux.
# The TTY has no Nerd Font, so the prompt there has no icon at all.
distro_id=$([ -r /etc/os-release ] && . /etc/os-release && echo "${ID:-}")
case "$distro_id" in
    artix)  icon=$'\uf31f' ;;
    void)   icon=$'\uf32e' ;;
    gentoo) icon=$'\uf30d' ;;
    kiss)   icon=$'\U000f02d1' ;;
    *)      icon=$'\uf31a' ;;
esac
if [ "$TERM" = linux ]; then
    PROMPT=$'\n%F{15}%~%f\n%(?.%F{15}.%F{1}):%f '
else
    PROMPT=$'\n%F{15}%~%f\n%F{15}'"$icon"$'%f %(?.%F{15}.%F{1}):%f '
fi
unset distro_id icon

# ▄▀▀▀ █  █ █▀▀▀ █    █    
#  ▀▀▄ █▀▀█ █▀▀  █    █    
# ▀▀▀  ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀          

# History. A command with a space in front is not saved.
mkdir -p ~/.local/state/zsh
HISTFILE=~/.local/state/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

# Completion: a menu on the second Tab, case-insensitive.
mkdir -p ~/.cache/zsh
autoload -Uz compinit
compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Keys. foot and the TTY send some keys differently, so both are bound.
bindkey -e

# Ctrl+Left and Ctrl+Right move by words.
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Home, End and Delete.
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char

# Up and Down search the history that starts like the typed text.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# br: broot that can cd into the picked folder (Alt+Enter).
if command -v broot >/dev/null; then
    eval "$(broot --print-shell-function zsh)"
fi

# y: yazi that cds into the folder it was closed in ('q', while 'Q' quits
# without). From the yazi docs (quick start, shell wrapper).
if command -v yazi >/dev/null; then
    y() {
        local tmp cwd
        tmp=$(mktemp -t yazi-cwd.XXXXXX)
        command yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd <"$tmp"
        [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
        command rm -f -- "$tmp"
    }
fi

# █▀▀▄ █    █  █ ▄▀▀▀ ▀█▀ █▄  █ ▄▀▀▀ 
# █▀▀  █    █  █ █ ▀█  █  █ ▀▄█  ▀▀▄ 
# ▀    ▀▀▀▀  ▀▀   ▀▀▀ ▀▀▀ ▀   ▀ ▀▀▀  

# No plugins on the TTY: its colors aren't ours.
plugins=/usr/share/zsh/plugins
[ "$TERM" = linux ] && plugins=/nonexistent

# A gray suggestion from the history. Right or End accepts it.
if [ -r "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    source "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Known commands stay plain, unknown ones are gray and underlined. This
# plugin must load last.
if [ -r "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    typeset -A ZSH_HIGHLIGHT_STYLES
    for style in command builtin alias function precommand hashed-command reserved-word arg0; do
        ZSH_HIGHLIGHT_STYLES[$style]='none'
    done
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=8,underline'
fi
unset plugins style

# Show the system info in every new foot window.
if [ "$TERM" = foot ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
