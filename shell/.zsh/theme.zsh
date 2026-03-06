# Machine-specific accent color for prompt/tmux identity.
# Set HAL_THEME_COLOR in ~/.zshrc.local (red|blue|green, extend as needed).
: "${HAL_THEME_COLOR:=red}"
export HAL_THEME_COLOR

case "${HAL_THEME_COLOR:l}" in
  blue)
    _hal_dir_bg=25
    _hal_direnv_bg=25
    _hal_vcs_loading_bg=24
    _hal_prompt_ok_fg=39
    ;;
  green)
    _hal_dir_bg=28
    _hal_direnv_bg=28
    _hal_vcs_loading_bg=22
    _hal_prompt_ok_fg=42
    ;;
  red|*)
    _hal_dir_bg=52
    _hal_direnv_bg=52
    _hal_vcs_loading_bg=88
    _hal_prompt_ok_fg=196
    ;;
esac

typeset -g POWERLEVEL9K_DIR_BACKGROUND="$_hal_dir_bg"
typeset -g POWERLEVEL9K_DIRENV_BACKGROUND="$_hal_direnv_bg"
typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND="$_hal_vcs_loading_bg"
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="$_hal_prompt_ok_fg"

if (( ${+functions[p10k]} )); then
  p10k reload
fi

unset _hal_dir_bg _hal_direnv_bg _hal_vcs_loading_bg _hal_prompt_ok_fg
