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
[[ -r "$HOME/.zsh/theme.zsh" ]] && source "$HOME/.zsh/theme.zsh"

. "$HOME/.local/bin/env"

# bun completions
[ -s "/home/anders/.bun/_bun" ] && source "/home/anders/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# fnm
FNM_PATH="/home/anders/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

# pnpm
export PNPM_HOME="/home/anders/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
