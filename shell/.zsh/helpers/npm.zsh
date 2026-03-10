_npm_guard_join() {
  local joined=""
  local arg

  for arg in "$@"; do
    if [[ -n "$joined" ]]; then
      joined+=" "
    fi
    joined+="$arg"
  done

  printf '%s' "$joined"
}

npm() {
  local subcommand="${1:-}"

  if [[ "$subcommand" != "install" && "$subcommand" != "i" ]]; then
    command npm "$@"
    return $?
  fi

  shift

  local -a replacement_args=()
  local is_global=0
  local arg

  for arg in "$@"; do
    case "$arg" in
      -g|--global)
        is_global=1
        ;;
      *)
        replacement_args+=("$arg")
        ;;
    esac
  done

  if (( is_global )); then
    command npm "$subcommand" "$@"
    return $?
  fi

  if (( ${#replacement_args[@]} == 0 )); then
    print -u2 -- "Blocked: use 'pnpm install' instead of 'npm ${subcommand}'."
  else
    print -u2 -- "Blocked: use 'pnpm add $(_npm_guard_join "${replacement_args[@]}")' instead."
  fi
  return 1
}
