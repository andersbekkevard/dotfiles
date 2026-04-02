theme_to_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

theme_color_from_local_overrides() {
  local theme_line

  if [ ! -r "${HOME}/.zshrc.local" ]; then
    return 1
  fi

  theme_line="$(
    grep -E '^[[:space:]]*(export[[:space:]]+)?THEME_COLOR=' "${HOME}/.zshrc.local" 2>/dev/null \
    | tail -n 1 \
    | sed -E "s/^[^=]+=//; s/[\"']//g; s/[[:space:]]+#.*$//; s/[[:space:]]*$//"
  )"

  [ -n "$theme_line" ] || return 1
  printf '%s\n' "$theme_line"
}

theme_normalize_color() {
  local theme_candidate

  theme_candidate="$(theme_to_lower "${1:-}")"
  case "$theme_candidate" in
    blue|green|orange|purple|red|teal|yellow)
      printf '%s\n' "$theme_candidate"
      ;;
    *)
      printf 'blue\n'
      ;;
  esac
}

theme_effective_color() {
  local theme_candidate

  if [ -n "${1:-}" ]; then
    theme_normalize_color "$1"
    return 0
  fi

  if [ -n "${THEME_COLOR:-}" ]; then
    theme_normalize_color "${THEME_COLOR}"
    return 0
  fi

  theme_candidate="$(theme_color_from_local_overrides 2>/dev/null || true)"
  if [ -n "$theme_candidate" ]; then
    theme_normalize_color "$theme_candidate"
    return 0
  fi

  printf 'blue\n'
}

theme_hex_to_ansi() {
  local theme_hex theme_r theme_g theme_b theme_mid

  theme_hex="${1#\#}"
  theme_r="$(printf '%d' "0x${theme_hex%????}")"
  theme_mid="${theme_hex#??}"
  theme_mid="${theme_mid%??}"
  theme_g="$(printf '%d' "0x${theme_mid}")"
  theme_b="$(printf '%d' "0x${theme_hex##????}")"
  printf '\033[38;2;%d;%d;%dm' "$theme_r" "$theme_g" "$theme_b"
}

theme_load_palette() {
  THEME_COLOR="$(theme_effective_color "${1:-}")"
  export THEME_COLOR
  unset HAL_THEME_COLOR

  case "$THEME_COLOR" in
    blue)
      DOTFILES_THEME_DIR_BG=25
      DOTFILES_THEME_DIRENV_BG=25
      DOTFILES_THEME_VCS_LOADING_BG=24
      DOTFILES_THEME_PROMPT_OK_FG=39
      DOTFILES_THEME_TMUX_ACCENT_BG='colour25'
      DOTFILES_THEME_TMUX_MODE_BG='colour117'
      DOTFILES_THEME_TMUX_CLOCK='colour117'
      DOTFILES_THEME_HEX_ACCENT='#60a5fa'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#93c5fd'
      DOTFILES_THEME_HEX_BORDER='#1d4ed8'
      ;;
    green)
      DOTFILES_THEME_DIR_BG=28
      DOTFILES_THEME_DIRENV_BG=28
      DOTFILES_THEME_VCS_LOADING_BG=22
      DOTFILES_THEME_PROMPT_OK_FG=42
      DOTFILES_THEME_TMUX_ACCENT_BG='colour28'
      DOTFILES_THEME_TMUX_MODE_BG='colour119'
      DOTFILES_THEME_TMUX_CLOCK='colour119'
      DOTFILES_THEME_HEX_ACCENT='#4ade80'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#86efac'
      DOTFILES_THEME_HEX_BORDER='#166534'
      ;;
    orange)
      DOTFILES_THEME_DIR_BG=130
      DOTFILES_THEME_DIRENV_BG=130
      DOTFILES_THEME_VCS_LOADING_BG=166
      DOTFILES_THEME_PROMPT_OK_FG=208
      DOTFILES_THEME_TMUX_ACCENT_BG='colour130'
      DOTFILES_THEME_TMUX_MODE_BG='colour215'
      DOTFILES_THEME_TMUX_CLOCK='colour215'
      DOTFILES_THEME_HEX_ACCENT='#fb923c'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#fdba74'
      DOTFILES_THEME_HEX_BORDER='#c2410c'
      ;;
    purple)
      DOTFILES_THEME_DIR_BG=54
      DOTFILES_THEME_DIRENV_BG=54
      DOTFILES_THEME_VCS_LOADING_BG=55
      DOTFILES_THEME_PROMPT_OK_FG=141
      DOTFILES_THEME_TMUX_ACCENT_BG='colour55'
      DOTFILES_THEME_TMUX_MODE_BG='colour141'
      DOTFILES_THEME_TMUX_CLOCK='colour141'
      DOTFILES_THEME_HEX_ACCENT='#c084fc'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#d8b4fe'
      DOTFILES_THEME_HEX_BORDER='#6b21a8'
      ;;
    teal)
      DOTFILES_THEME_DIR_BG=30
      DOTFILES_THEME_DIRENV_BG=30
      DOTFILES_THEME_VCS_LOADING_BG=23
      DOTFILES_THEME_PROMPT_OK_FG=44
      DOTFILES_THEME_TMUX_ACCENT_BG='colour30'
      DOTFILES_THEME_TMUX_MODE_BG='colour80'
      DOTFILES_THEME_TMUX_CLOCK='colour80'
      DOTFILES_THEME_HEX_ACCENT='#2dd4bf'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#5eead4'
      DOTFILES_THEME_HEX_BORDER='#0f766e'
      ;;
    yellow)
      DOTFILES_THEME_DIR_BG=136
      DOTFILES_THEME_DIRENV_BG=136
      DOTFILES_THEME_VCS_LOADING_BG=178
      DOTFILES_THEME_PROMPT_OK_FG=220
      DOTFILES_THEME_TMUX_ACCENT_BG='colour136'
      DOTFILES_THEME_TMUX_MODE_BG='colour221'
      DOTFILES_THEME_TMUX_CLOCK='colour221'
      DOTFILES_THEME_HEX_ACCENT='#facc15'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#fde047'
      DOTFILES_THEME_HEX_BORDER='#a16207'
      ;;
    red|*)
      DOTFILES_THEME_DIR_BG=52
      DOTFILES_THEME_DIRENV_BG=52
      DOTFILES_THEME_VCS_LOADING_BG=88
      DOTFILES_THEME_PROMPT_OK_FG=196
      DOTFILES_THEME_TMUX_ACCENT_BG='colour52'
      DOTFILES_THEME_TMUX_MODE_BG='colour220'
      DOTFILES_THEME_TMUX_CLOCK='colour220'
      DOTFILES_THEME_HEX_ACCENT='#f87171'
      DOTFILES_THEME_HEX_ACCENT_SOFT='#fca5a5'
      DOTFILES_THEME_HEX_BORDER='#7f1d1d'
      ;;
  esac

  DOTFILES_THEME_ANSI_ACCENT="$(theme_hex_to_ansi "$DOTFILES_THEME_HEX_ACCENT")"
}

theme_apply_tmux() {
  theme_load_palette "${1:-}"

  tmux set-environment -gu HAL_THEME_COLOR 2>/dev/null || true
  tmux set-environment -g THEME_COLOR "$THEME_COLOR"
  tmux set-option -gq @dotfiles_theme_color "$THEME_COLOR"
  tmux set-option -gq @dotfiles_theme_accent_bg "$DOTFILES_THEME_TMUX_ACCENT_BG"
  tmux set-option -gq @dotfiles_theme_mode_bg "$DOTFILES_THEME_TMUX_MODE_BG"
  tmux set-option -gq window-status-current-style "fg=colour15,bg=${DOTFILES_THEME_TMUX_ACCENT_BG},bold"
  tmux set-option -gq message-style "fg=colour15,bg=${DOTFILES_THEME_TMUX_ACCENT_BG},bold"
  tmux set-option -gq message-command-style "fg=colour15,bg=${DOTFILES_THEME_TMUX_ACCENT_BG},bold"
  tmux set-option -gq mode-style "fg=colour0,bg=${DOTFILES_THEME_TMUX_MODE_BG},bold"
  tmux set-option -gq status-right "#[fg=colour15,bg=${DOTFILES_THEME_TMUX_ACCENT_BG}] #H #[fg=colour0,bg=colour244] %a %b %d %H:%M:%S #[default]"
  tmux set-window-option -gq clock-mode-colour "$DOTFILES_THEME_TMUX_CLOCK"
}
