[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" 2>/dev/null

alias secrets='cursor ~/.secrets'
alias c.='cursor .'
alias c-a='cursor-agent'

ghostty() {
  if [[ ! -d /Applications/Ghostty.app ]]; then
    echo "ghostty: Ghostty.app not found" >&2
    return 1
  fi
  local dir="${1:-.}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "ghotty: invalid path: $1" >&2; return 1; }
  osascript -e '
    tell application "Ghostty"
      activate
      tell application "System Events" to keystroke "t" using command down
      delay 0.3
      tell application "System Events"
        keystroke "cd '"'$dir'"' && clear"
        keystroke return
      end tell
    end tell
  '
}


export PAI_DIR="$HOME/.claude"
export DA='Hal'
export DA_COLOR='red'
export ENGINEER_NAME='Anders Bekkevard'
