eval "$(perl -I"$HOME"/perl5/lib/perl5 -Mlocal::lib)" 2>/dev/null

export JAVA_HOME="$(
  /usr/libexec/java_home 2>/dev/null
)"
[[ -n "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"

[[ ":$PATH:" != *":$HOME/.antigravity/antigravity/bin:"* ]] && export PATH="$PATH:$HOME/.antigravity/antigravity/bin"

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" 2>/dev/null

alias secrets='cursor ~/.secrets'
alias c.='cursor .'
alias c-a='cursor-agent'


export PAI_DIR="$HOME/.claude"
export DA='Hal'
export DA_COLOR='red'
export ENGINEER_NAME='Anders Bekkevard'
