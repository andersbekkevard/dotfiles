[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" 2>/dev/null

alias secrets='cursor ~/.secrets'
alias c.='cursor .'
alias c-a='cursor-agent'

ghotty() {
  if ! command -v ghostty &>/dev/null && [[ ! -d /Applications/Ghostty.app ]]; then
    echo "ghotty: ghostty not available" >&2
    return 1
  fi
  local dir="${1:-.}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "ghotty: invalid path: $1" >&2; return 1; }
  open -a Ghostty --new --args --working-directory="$dir"
}


export PAI_DIR="$HOME/.claude"
export DA='Hal'
export DA_COLOR='red'
export ENGINEER_NAME='Anders Bekkevard'
