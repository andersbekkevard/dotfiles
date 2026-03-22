[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" 2>/dev/null

alias secrets='cursor ~/.secrets'
alias c.='cursor .'
alias c-a='cursor-agent'


export PAI_DIR="$HOME/.claude"
export DA='Hal'
export DA_COLOR='red'
export ENGINEER_NAME='Anders Bekkevard'
