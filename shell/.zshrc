if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

for config_file in \
  "$HOME/.zsh/core.zsh" \
  "$HOME/.zsh/env.zsh" \
  "$HOME/.zsh/aliases.zsh" \
  "$HOME/.zsh/helpers.zsh" \
  "$HOME/.zsh/languages.zsh"; do
  [[ -r "$config_file" ]] && source "$config_file"
done

if [[ "$OSTYPE" == darwin* ]] && [[ -r "$HOME/.zsh/mac.zsh" ]]; then
  source "$HOME/.zsh/mac.zsh"
fi

if [[ -r "$HOME/.secrets" ]] && LC_ALL=C grep -Iq . "$HOME/.secrets" 2>/dev/null; then
  source "$HOME/.secrets"
fi

[[ -r "$HOME/.zsh/tools.zsh" ]] && source "$HOME/.zsh/tools.zsh"
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
