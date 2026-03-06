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

if command -v brew >/dev/null 2>&1; then
  zsh_ai_plugin="$(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh"
  if [[ -f "$zsh_ai_plugin" ]]; then
    export ZSH_AI_PROVIDER='openai'
    export ZSH_AI_MODEL='openai/gpt-5.2'
    export ZSH_AI_PROMPT_EXTEND=$'RECOMMENDED TOOL PREFERENCES:\n- Use '\''rg'\'' (ripgrep) instead of '\''grep'\'' for all text searches.\n- Use '\''fd'\'' instead of '\''find'\'' for finding files and directories.\n- Use '\''bat'\'' instead of '\''cat'\'' for reading files.\n- Use '\''lsd'\'' instead of '\''ls'\'' for listing files.'
    source "$zsh_ai_plugin"
  fi
  unset zsh_ai_plugin
fi

export PAI_DIR="$HOME/.claude"
export DA='Hal'
export DA_COLOR='red'
export ENGINEER_NAME='Anders Bekkevard'
