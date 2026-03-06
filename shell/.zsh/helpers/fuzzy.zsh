# Custom fuzzy finder function (not exact)
ff() {
  fd --type f --follow \
    --exclude "*.photoslibrary" \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    --exclude '*.log' \
    --exclude .DS_Store \
    --exclude .venv \
    --exclude OfficeFileCache \
  . | fzf --preview 'bat --style=numbers --color=always --line-range :100 {}' \
         --bind "enter:execute(cursor "{}")+abort"
}

# (exact match only)
ffe() {
  fd --type f --follow \
    --exclude "*.photoslibrary" \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    --exclude '*.log' \
    --exclude .DS_Store \
    --exclude .venv \
    --exclude OfficeFileCache \
  . | fzf --exact --preview 'bat --style=numbers --color=always --line-range :100 {}' \
         --bind "enter:execute(code "{}")+abort"
}

# Fuzzy finder for zsh history - puts selection in command line for editing
fh() {
  local cmd=$(fc -l 1 | fzf --tac --no-sort --exact --height=40% --reverse | sed 's/^ *[0-9]*[ *]*//; s/[[:space:]]*$//')
  if [[ -n $cmd ]]; then
    print -z "$cmd"
  fi
}

# Custom fuzzy finder for directories
fdir() {
  local dir
  dir=$(fd --type d . \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude .venv \
    --exclude target \
  | fzf --preview 'lsd --color=always --icon=always --tree --depth=6 {} | head -200' \
        --preview-window=right:65%:wrap) && cd "$dir"
}

