# ASCII : https://patorjk.com/software/taag/#p=display&f=Linguaholic+Mini+Block&t=SHH-DOTFILES&x=none&v=4&h=4&w=80&we=false

#  ▄       ▄▀   ▄▄▄▄  ▄▄▄ █▄▄  ▄ ▄▄  ▄▄▄ 
# ▀ ▀▄▀  ▄▀      ▄▀  ▀▀▄▄ █  █ █▀   █    
#       ▀     ▀ ▀▀▀▀ ▀▀▀  ▀  ▀ ▀     ▀▀▀   
# Zsh configuration.  


# █▀▀▄ █▀▀▄ ▄▀▀▄ █▄ ▄█ █▀▀▄ ▀▀█▀▀ 
# █▀▀  █▀█  █  █ █ ▀ █ █▀▀    █   
# ▀    ▀  ▀  ▀▀  ▀   ▀ ▀      ▀   
                                
if [ "$TERM" = linux ]; then
    PROMPT=$'\n%F{15}%~%f\n%(?.%F{15}.%F{1}):%f '
else
    PROMPT=$'\n%F{15}%~%f\n%F{15}%f %(?.%F{15}.%F{1}):%f '
fi

# ▄▀▀▀ █  █ █▀▀▀ █    █    
#  ▀▀▄ █▀▀█ █▀▀  █    █    
# ▀▀▀  ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀          

# HISTORY
mkdir -p ~/.local/state/zsh
HISTFILE=~/.local/state/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

# COMPLETION                                                    
mkdir -p ~/.cache/zsh
autoload -Uz compinit
compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# KEYBINDS                                   
bindkey -e

# Ctrl+Left / Ctrl+Right: by words
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Home / End / Delete
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char

# Up / Down: history, only commands that start like the typed text
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# br: broot that can cd into the folder you pick (Alt+Enter)
if command -v broot >/dev/null; then
    eval "$(broot --print-shell-function zsh)"
fi

# █▀▀▄ █    █  █ ▄▀▀▀ ▀█▀ █▄  █ ▄▀▀▀ 
# █▀▀  █    █  █ █ ▀█  █  █ ▀▄█  ▀▀▄ 
# ▀    ▀▀▀▀  ▀▀   ▀▀▀ ▀▀▀ ▀   ▀ ▀▀▀  

# (packages/common.csv); not on the TTY, its colors aren't ours
plugins=/usr/share/zsh/plugins
[ "$TERM" = linux ] && plugins=/nonexistent

# gray suggestion from the history while typing, Right or End accepts it
if [ -r "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
    source "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# highlighting: known commands plain white, unknown ones gray + underlined.
# must be loaded last
if [ -r "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    typeset -A ZSH_HIGHLIGHT_STYLES
    for style in command builtin alias function precommand hashed-command reserved-word arg0; do
        ZSH_HIGHLIGHT_STYLES[$style]='none'
    done
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=8,underline'
fi
unset plugins style

# Fastfetch
# Show system info when a new terminal window opens.
if [ "$TERM" = foot ] && command -v fastfetch >/dev/null; then
    fastfetch
fi
