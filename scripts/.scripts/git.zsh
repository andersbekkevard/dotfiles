# GitHub repo publishing helpers

gnew() {
  local visibility="--private"
  local repo_name=""
  local message="Initial commit"
  local repo_root=""
  local -a gh_args
  gh_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --public|--private|--internal)
        visibility="$1"
        ;;
      -m|--message)
        shift
        if [[ -z "${1:-}" ]]; then
          echo "Usage: gnew [--private|--public|--internal] [-m message] [repo-name] [extra gh flags]"
          return 1
        fi
        message="$1"
        ;;
      -h|--help)
        echo "Usage: gnew [--private|--public|--internal] [-m message] [repo-name] [extra gh flags]"
        echo "Creates a GitHub repo from the current Git repo, sets origin, and pushes main with upstream tracking."
        return 0
        ;;
      --*)
        gh_args+=("$1")
        ;;
      *)
        if [[ -n "$repo_name" ]]; then
          echo "gnew: unexpected extra argument: $1"
          echo "Usage: gnew [--private|--public|--internal] [-m message] [repo-name] [extra gh flags]"
          return 1
        fi
        repo_name="$1"
        ;;
    esac
    shift
  done

  if ! command -v gh >/dev/null 2>&1; then
    echo "gnew: GitHub CLI not found on PATH: gh"
    return 127
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_root="$(git rev-parse --show-toplevel)" || return 1
  else
    git init || return 1
    repo_root="$PWD"
  fi

  git -C "$repo_root" add -A || return 1

  if ! git -C "$repo_root" rev-parse --verify HEAD >/dev/null 2>&1; then
    if git -C "$repo_root" diff --cached --quiet; then
      echo "gnew: nothing to commit. Add a file first, then run gnew again."
      return 1
    fi
    git -C "$repo_root" commit -m "$message" || return 1
  fi

  git -C "$repo_root" branch -M main || return 1

  local -a create_cmd
  create_cmd=(gh repo create)
  [[ -n "$repo_name" ]] && create_cmd+=("$repo_name")
  create_cmd+=("$visibility" --source="$repo_root" --remote=origin)
  create_cmd+=("${gh_args[@]}")

  "${create_cmd[@]}" || return 1
  git -C "$repo_root" push -u origin main
}
