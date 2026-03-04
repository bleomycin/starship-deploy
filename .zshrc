# ╔══════════════════════════════════════════════════════════════════╗
# ║  .zshrc — ZSH-specific config                                  ║
# ║  Loads shared config from .shellrc.common, then adds            ║
# ║  ZSH plugins and options on top.                                ║
# ╚══════════════════════════════════════════════════════════════════╝

# ─── Shared config (aliases, functions, tool init) ────────────────
[ -f ~/.shellrc.common ] && source ~/.shellrc.common

# ─── History ──────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# ─── General ZSH options ─────────────────────────────────────────
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt CORRECT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# ─── Completion system ───────────────────────────────────────────
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}── %d ──%f'
zstyle ':completion:*:warnings' format '%F{red}No matches%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# SSH host completion from config
zstyle ':completion:*:ssh:*' hosts $(
    [ -f ~/.ssh/config ] && grep -i '^Host ' ~/.ssh/config | awk '{print $2}' | grep -v '[*?]'
)
zstyle ':completion:*:scp:*' hosts $(
    [ -f ~/.ssh/config ] && grep -i '^Host ' ~/.ssh/config | awk '{print $2}' | grep -v '[*?]'
)
zstyle ':completion:*:rsync:*' hosts $(
    [ -f ~/.ssh/config ] && grep -i '^Host ' ~/.ssh/config | awk '{print $2}' | grep -v '[*?]'
)

# ─── Key bindings ─────────────────────────────────────────────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# ─── fzf shell integration (ZSH-specific keybindings) ────────────
if command -v fzf &>/dev/null; then
    if [[ "$IS_MACOS" == true ]]; then
        source <(fzf --zsh 2>/dev/null)
    else
        if fzf --zsh &>/dev/null 2>&1; then
            source <(fzf --zsh)
        elif [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
            source /usr/share/fzf/key-bindings.zsh
            source /usr/share/fzf/completion.zsh
        elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
            source /usr/share/doc/fzf/examples/key-bindings.zsh
            source /usr/share/doc/fzf/examples/completion.zsh
        fi
    fi
fi

# ─── ZSH Plugins ─────────────────────────────────────────────────

# fzf-tab: fuzzy completion on Tab (must load after compinit)
if [[ -f ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]]; then
    source ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
    zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border=rounded
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --icons --color=always --group-directories-first $realpath 2>/dev/null || ls --color=always $realpath'
    zstyle ':fzf-tab:complete:(vim|nvim|nano|cat|bat|less|head|tail):*' fzf-preview 'bat --color=always --style=numbers --line-range=:50 $realpath 2>/dev/null || cat $realpath'
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,stat,start,command 2>/dev/null'
    zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word 2>/dev/null'
    zstyle ':fzf-tab:complete:docker-*:*' fzf-preview 'docker inspect $word 2>/dev/null | head -50'
fi

# zsh-autosuggestions: ghost text completions from history
if [[ -f ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
fi

# zsh-completions: additional completion definitions
if [[ -d ~/.zsh/plugins/zsh-completions/src ]]; then
    fpath=(~/.zsh/plugins/zsh-completions/src $fpath)
fi

# zsh-syntax-highlighting: MUST be sourced last
if [[ -f ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ─── Starship prompt (must be after everything else) ──────────────
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
