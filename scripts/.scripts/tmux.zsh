ts() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed"
    return 1
  fi

  if ! tmux start-server >/dev/null 2>&1; then
    echo "unable to start tmux server"
    return 1
  fi

  local in_tmux current_session prompt_label
  in_tmux=0
  current_session=""
  prompt_label='tmux> '
  if [[ -n "${TMUX:-}" ]]; then
    in_tmux=1
    current_session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"
    prompt_label='swap> '
  fi

  local raw_sessions
  raw_sessions="$(tmux list-sessions -F '#{session_name}__TS__#{session_attached}__TS__#{session_activity}__TS__#{session_activity_flag}__TS__#{session_active}' 2>/dev/null)"
  if [[ -z "$raw_sessions" ]]; then
    echo "no tmux sessions found"
    return 1
  fi

  local now live_threshold recent_threshold stale_threshold
  now="$(date +%s)"
  live_threshold=15
  recent_threshold=300
  stale_threshold=3600

  local accent_color current_color attached_color quiet_color neutral_color reset_color bold_on
  case "${HAL_THEME_COLOR:-}" in
    red) accent_color=$'\033[1;31m' ;;
    blue) accent_color=$'\033[1;34m' ;;
    green) accent_color=$'\033[1;32m' ;;
    *) accent_color=$'\033[1;36m' ;;
  esac
  current_color=$'\033[38;5;152m'
  attached_color=$'\033[38;5;110m'
  quiet_color=$'\033[38;5;245m'
  neutral_color=$'\033[97m'
  reset_color=$'\033[0m'
  bold_on=$'\033[1m'

  _ts_age_label() {
    local delta="$1"
    if (( delta < 60 )); then
      printf '%ss' "$delta"
    elif (( delta < 3600 )); then
      printf '%sm' "$(( delta / 60 ))"
    elif (( delta < 86400 )); then
      printf '%sh' "$(( delta / 3600 ))"
    else
      printf '%sd' "$(( delta / 86400 ))"
    fi
  }

  local formatted_sessions
  formatted_sessions="$(
    local line session_name attached session_activity activity_flag session_active age is_live is_current_session sort_live sort_current sort_attached sort_here name_color badge badge_color
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      session_name="${line%%__TS__*}"
      line="${line#*__TS__}"
      attached="${line%%__TS__*}"
      line="${line#*__TS__}"
      session_activity="${line%%__TS__*}"
      line="${line#*__TS__}"
      activity_flag="${line%%__TS__*}"
      session_active="${line#*__TS__}"

      [[ "$session_activity" == "$line" ]] && session_active=""
      [[ -z "$session_activity" ]] && session_activity=0

      age=$(( now - session_activity ))
      (( age < 0 )) && age=0

      is_live=0
      if [[ "$activity_flag" == "1" ]] || (( age <= live_threshold )); then
        is_live=1
      fi

      is_current_session=0
      if (( in_tmux == 1 )) && [[ "$session_name" == "$current_session" ]]; then
        is_current_session=1
      fi

      sort_live="$is_live"
      sort_current="$is_current_session"
      sort_here="$is_current_session"
      sort_attached=0
      [[ "$attached" == "1" ]] && sort_attached=1

      badge="$(_ts_age_label "$age")"
      badge_color="$quiet_color"
      name_color="$neutral_color"

      if (( is_current_session == 1 )); then
        badge="here"
        badge_color="$current_color"
        name_color="$bold_on$current_color"
      elif (( is_live == 1 )); then
        badge="live"
        badge_color="$accent_color"
        name_color="$accent_color"
      elif [[ "$attached" == "1" ]]; then
        badge="attached"
        badge_color="$attached_color"
        name_color="$attached_color"
      elif (( age > stale_threshold )); then
        badge="$(_ts_age_label "$age")"
        badge_color="$quiet_color"
        name_color="$quiet_color"
      elif (( age <= recent_threshold )); then
        badge="$(_ts_age_label "$age")"
        badge_color="$neutral_color"
        name_color="$neutral_color"
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%b%-36s%b %b%s%b\n' \
        "$sort_live" \
        "$sort_current" \
        "$sort_here" \
        "$sort_attached" \
        "$session_activity" \
        "$session_name" \
        "$name_color" "$session_name" "$reset_color" \
        "$badge_color" "$badge" "$reset_color"
    done <<< "$raw_sessions"
  )"

  local selection session_name
  selection="$(printf '%s\n' "$formatted_sessions" |
    sort -t $'\t' -k1,1nr -k2,2nr -k3,3nr -k4,4n -k5,5nr |
    fzf \
      --ansi \
      --no-sort \
      --prompt="$prompt_label" \
      --height=40% \
      --reverse \
      --border \
      --delimiter=$'\t' \
      --with-nth=7 \
      --preview-window='right:60%:wrap' \
      --preview='tmux list-windows -t {6} -F "#I #W#{?window_active, *,}" 2>/dev/null')"

  if [[ -z "$selection" ]]; then
    return 0
  fi

  session_name="$(printf '%s' "$selection" | cut -f6)"
  if [[ -z "$session_name" ]]; then
    echo "no tmux session selected"
    return 1
  fi

  if (( in_tmux == 1 )) && [[ "$session_name" == "$current_session" ]]; then
    return 0
  fi

  if (( in_tmux == 1 )); then
    tmux switch-client -t "$session_name"
  else
    tmux attach-session -t "$session_name"
  fi
}

tk() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf is not installed"
    return 1
  fi

  if ! tmux start-server >/dev/null 2>&1; then
    echo "unable to start tmux server"
    return 1
  fi

  local in_tmux current_session
  in_tmux=0
  current_session=""
  if [[ -n "${TMUX:-}" ]]; then
    in_tmux=1
    current_session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"
  fi

  local now live_threshold recent_threshold stale_threshold
  now="$(date +%s)"
  live_threshold=15
  recent_threshold=300
  stale_threshold=3600

  local accent_color current_color attached_color quiet_color neutral_color reset_color bold_on
  case "${HAL_THEME_COLOR:-}" in
    red) accent_color=$'\033[1;31m' ;;
    blue) accent_color=$'\033[1;34m' ;;
    green) accent_color=$'\033[1;32m' ;;
    *) accent_color=$'\033[1;36m' ;;
  esac
  current_color=$'\033[38;5;152m'
  attached_color=$'\033[38;5;110m'
  quiet_color=$'\033[38;5;245m'
  neutral_color=$'\033[97m'
  reset_color=$'\033[0m'
  bold_on=$'\033[1m'
  _tk_age_label() {
    local delta="$1"
    if (( delta < 60 )); then
      printf '%ss' "$delta"
    elif (( delta < 3600 )); then
      printf '%sm' "$(( delta / 60 ))"
    elif (( delta < 86400 )); then
      printf '%sh' "$(( delta / 3600 ))"
    else
      printf '%sd' "$(( delta / 86400 ))"
    fi
  }

  local raw_sessions
  raw_sessions="$(tmux list-sessions -F '#{session_name}__TK__#{session_attached}__TK__#{session_activity}__TK__#{session_activity_flag}' 2>/dev/null)"
  if [[ -z "$raw_sessions" ]]; then
    echo "no tmux sessions found"
    return 1
  fi

  local entries
  entries="$(
    local line session_name attached activity activity_flag age is_live is_here sort_live sort_here sort_attached badge badge_color name_color display
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      session_name="${line%%__TK__*}"
      line="${line#*__TK__}"
      attached="${line%%__TK__*}"
      line="${line#*__TK__}"
      activity="${line%%__TK__*}"
      activity_flag="${line#*__TK__}"

      [[ -z "$activity" ]] && activity=0
      age=$(( now - activity ))
      (( age < 0 )) && age=0

      is_live=0
      if [[ "$activity_flag" == "1" ]] || (( age <= live_threshold )); then
        is_live=1
      fi

      is_here=0
      if (( in_tmux == 1 )) && [[ "$session_name" == "$current_session" ]]; then
        is_here=1
      fi

      badge="$(_tk_age_label "$age")"
      badge_color="$quiet_color"
      name_color="$neutral_color"
      if (( is_here == 1 )); then
        badge="here"
        badge_color="$current_color"
        name_color="$bold_on$current_color"
      elif (( is_live == 1 )); then
        badge="live"
        badge_color="$accent_color"
        name_color="$accent_color"
      elif [[ "$attached" == "1" ]]; then
        badge="attached"
        badge_color="$attached_color"
        name_color="$attached_color"
      elif (( age > stale_threshold )); then
        badge="$(_tk_age_label "$age")"
        badge_color="$quiet_color"
        name_color="$quiet_color"
      elif (( age <= recent_threshold )); then
        badge="$(_tk_age_label "$age")"
        badge_color="$neutral_color"
        name_color="$neutral_color"
      fi

      display="${name_color}${session_name}${reset_color} ${badge_color}${badge}${reset_color}"
      printf '%s\t%s\t%s\t%s\t%s\t%b\n' \
        "$is_live" \
        "$is_here" \
        "$attached" \
        "$activity" \
        "$session_name" \
        "$display"
    done <<< "$raw_sessions"
  )"

  local selection target_id target_label
  selection="$(printf '%s\n' "$entries" |
    sort -t $'\t' -k1,1nr -k2,2nr -k3,3n -k4,4nr |
    fzf \
      --ansi \
      --no-sort \
      --prompt='kill> ' \
      --height=40% \
      --reverse \
      --border \
      --delimiter=$'\t' \
      --with-nth=6 \
      --preview-window='right:60%:wrap' \
      --preview='tmux list-windows -t {5} -F "#I #W#{?window_active, *,}" 2>/dev/null')"

  if [[ -z "$selection" ]]; then
    return 0
  fi

  target_id="$(printf '%s' "$selection" | cut -f5)"
  target_label="$(printf '%s' "$selection" | cut -f6 | sed -E 's/\x1B\[[0-9;]*m//g')"

  local reply
  printf 'Kill session %s? [y/N] ' "$target_label" > /dev/tty
  read -r reply < /dev/tty
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    return 0
  fi

  tmux kill-session -t "$target_id"
}

td() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed"
    return 1
  fi

  if tmux has-session -t dev 2>/dev/null; then
    if [[ -n "${TMUX:-}" ]]; then
      tmux switch-client -t dev
    else
      tmux attach-session -t dev
    fi
  else
    tmux new-session -s dev
  fi
}
