[[ -o interactive && -z "${DOTFILES_PROFILE_SOURCED:-}" && -r "$HOME/.profile" ]] && source "$HOME/.profile"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

for config_file in \
  "$HOME/.zsh/core.zsh" \
  "$HOME/.zsh/env.zsh" \
  "$HOME/.zsh/aliases.zsh" \
  "$HOME/.zsh/languages.zsh"; do
  [[ -r "$config_file" ]] && source "$config_file"
done

for script_file in "$HOME"/.scripts/*.zsh; do
  [[ -r "$script_file" ]] && source "$script_file"
done

if [[ -r "$HOME/.secrets" ]] && LC_ALL=C grep -Iq . "$HOME/.secrets" 2>/dev/null; then
  source "$HOME/.secrets"
fi

if [[ "$OSTYPE" == darwin* ]] && [[ -r "$HOME/.zsh/mac.zsh" ]]; then
  source "$HOME/.zsh/mac.zsh"
fi

[[ -r "$HOME/.zsh/tools.zsh" ]] && source "$HOME/.zsh/tools.zsh"
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
[[ -r "$HOME/.zsh/theme.zsh" ]] && source "$HOME/.zsh/theme.zsh"

[[ -o interactive && -r "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/tmp/google-cloud-sdk/path.zsh.inc' ]; then . '/tmp/google-cloud-sdk/path.zsh.inc'; fi

