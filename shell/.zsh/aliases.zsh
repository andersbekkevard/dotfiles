alias src="source ~/.zshrc"
alias zrc="nvim ~/.dotfiles/shell/.zshrc"
alias c="clear"

alias nv="nvim"
alias nv.="nvim."
alias vim="nvim"
alias vim.="nvim ."
alias vi="nvim"
alias vi.="nvim ."
alias v="nvim"
alias v.="nvim ."

alias ..="cd .."
alias cc="claude --dangerously-skip-permissions"
alias co="codex --yolo"
alias sp="sesh picker"

alias nodesize='bash ~/.scripts/nodesize.sh'
alias pysize='bash ~/.scripts/pysize.sh'
alias server-mode='bash ~/.scripts/server-mode.sh'

if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'
  alias l='ls -l --blocks permission,size,date,name'
  alias la='lsd -A'
  alias lla='ls -lA --blocks permission,size,date,name'
  alias lt='lsd --tree --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'
else
  alias ls='ls --color=auto'
  alias l='ls -l'
  alias la='ls -A'
  alias lla='ls -lA'
fi

alias g='git'
alias ga='git add'
alias gb='git branch'
alias gc='git commit -m'
alias gs='git status -sb'
alias gp='git pull'
alias gpo='git push'
alias gbm='git branch -M main'
alias glog='git log --oneline --graph --decorate --all'
alias lg='lazygit'
alias lzd='lazydocker'

alias nrd='pnpm dev'
alias nrt='pnpm test'
alias nrb='pnpm build'
alias nrl='pnpm lint'
alias prd='pnpm dev'

alias ogr='openclaw gateway restart'
alias ogs='openclaw gateway status'
alias olf='openclaw logs --follow'

command -v bat >/dev/null 2>&1 && alias cat='bat'
command -v gh >/dev/null 2>&1 && alias ghc='gh copilot'
command -v cargo >/dev/null 2>&1 && alias cr='cargo run'

if command -v fzf >/dev/null 2>&1 && command -v bat >/dev/null 2>&1; then
  alias fzfc="fzf --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%"
fi

# alias lc='rm -f *.aux *.log *.pytxcode && rm -rf pythontex-files-*/'
alias sql='sqlite3'
