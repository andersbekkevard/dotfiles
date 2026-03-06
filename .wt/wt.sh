#!/usr/bin/env bash
# wt - Git worktree management CLI
# https://github.com/jorgensandhaug/wt-cli

_WT_VERSION="1.0.0"

_wt_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wt"
_wt_config_file="$_wt_config_dir/config.json"

# Color support
_wt_setup_colors() {
  if [[ -n "$NO_COLOR" ]] || [[ ! -t 1 ]]; then
    _wt_red=""
    _wt_green=""
    _wt_yellow=""
    _wt_reset=""
  else
    _wt_red=$'\033[0;31m'
    _wt_green=$'\033[0;32m'
    _wt_yellow=$'\033[0;33m'
    _wt_reset=$'\033[0m'
  fi
}

_wt_help() {
  cat <<EOF
wt - Git worktree management CLI v$_WT_VERSION

Commands:
  wt new <branch>      Create new worktree with new branch
  wt new -b <branch>   Create worktree from existing branch (auto-fetches)
  wt new -p <pr>       Create worktree from GitHub PR (requires gh CLI)
  wt new -u <branch>   Create worktree and run 'up' commands
  wt ls                List all worktrees with status
  wt cd [name]         cd to worktree (main if no name)
  wt up                Run 'up' commands (spin up dev environment)
  wt down              Run 'down' commands (spin down dev environment)
  wt rm [name]         Remove worktree (current if no name), cd to main
  wt rm -f [name]      Force remove worktree
  wt purge             Interactive cleanup of clean worktrees
  wt prune             Clean up stale worktree references
  wt config            Show path to config file
  wt update            Update wt to latest version
  wt uninstall         Uninstall wt-cli
  wt version           Show version

Config file: $_wt_config_file
EOF
}

_wt_version() {
  echo "wt version $_WT_VERSION"
}

_wt_get_config_command() {
  if [[ -f "$_wt_config_file" ]]; then
    jq -r '.command // empty' "$_wt_config_file" 2>/dev/null
  fi
}

_wt_ensure_config() {
  if [[ ! -f "$_wt_config_file" ]]; then
    mkdir -p "$_wt_config_dir"
    echo '{"command": "claude --dangerously-skip-permissions"}' > "$_wt_config_file"
  fi
}

_wt_config() {
  _wt_ensure_config
  echo "$_wt_config_file"
}

_wt_get_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

_wt_get_main_worktree() {
  # Get the main worktree path (first one listed)
  git worktree list --porcelain | head -1 | sed 's/^worktree //'
}

_wt_get_base_name() {
  local main_wt
  main_wt=$(_wt_get_main_worktree)
  if [[ -n "$main_wt" ]]; then
    basename "$main_wt"
  else
    # Fallback to current repo basename
    basename "$1"
  fi
}

_wt_is_clean() {
  local wt_path="$1"
  local git_status
  git_status=$(git -C "$wt_path" status --porcelain 2>/dev/null)
  [[ -z "$git_status" ]]
}

# Fast combined check - returns "clean" "dirty" "unpushed" or "dirty+unpushed"
_wt_get_status() {
  local wt_path="$1"
  local status_output
  status_output=$(git -C "$wt_path" status -sb 2>/dev/null)

  local is_dirty=false is_unpushed=false

  # Check for uncommitted changes (any line not starting with ##)
  if echo "$status_output" | grep -qv '^##'; then
    is_dirty=true
  fi

  # Check for unpushed commits (ahead in first line)
  if echo "$status_output" | head -1 | grep -q '\[ahead'; then
    is_unpushed=true
  fi

  if [[ "$is_dirty" == true ]] && [[ "$is_unpushed" == true ]]; then
    echo "dirty+unpushed"
  elif [[ "$is_dirty" == true ]]; then
    echo "dirty"
  elif [[ "$is_unpushed" == true ]]; then
    echo "unpushed"
  else
    echo "clean"
  fi
}

_wt_is_pushed() {
  local wt_path="$1"
  local ahead
  ahead=$(git -C "$wt_path" rev-list --count @{u}..HEAD 2>/dev/null)
  [[ "$ahead" == "0" || -z "$ahead" ]]
}

_wt_get_worktree_json() {
  local repo_root="$1"
  local json_file="$repo_root/.cursor/worktrees.json"
  if [[ -f "$json_file" ]]; then
    echo "$json_file"
  fi
}

_wt_run_setup_commands() {
  local repo_root="$1"
  local worktree_path="$2"
  local json_file
  json_file=$(_wt_get_worktree_json "$repo_root")

  if [[ -n "$json_file" ]]; then
    local commands
    commands=$(jq -r '."setup-worktree" // [] | .[]' "$json_file" 2>/dev/null)
    if [[ -n "$commands" ]]; then
      echo "Running setup commands..."
      while IFS= read -r cmd; do
        # Replace $ROOT_WORKTREE_PATH with repo root
        cmd="${cmd//\$ROOT_WORKTREE_PATH/$repo_root}"
        echo "  Running: $cmd"
        (cd "$worktree_path" && eval "$cmd")
      done <<< "$commands"
    fi
  fi
}

_wt_run_cleanup_commands() {
  local repo_root="$1"
  local worktree_path="$2"
  local json_file
  json_file=$(_wt_get_worktree_json "$repo_root")

  if [[ -n "$json_file" ]]; then
    local commands
    commands=$(jq -r '."cleanup-worktree" // [] | .[]' "$json_file" 2>/dev/null)
    if [[ -n "$commands" ]]; then
      echo "Running cleanup commands..."
      while IFS= read -r cmd; do
        cmd="${cmd//\$ROOT_WORKTREE_PATH/$repo_root}"
        echo "  Running: $cmd"
        (cd "$worktree_path" && eval "$cmd")
      done <<< "$commands"
    fi
  fi
}

_wt_run_up_commands() {
  local repo_root="$1"
  local worktree_path="$2"
  local json_file
  json_file=$(_wt_get_worktree_json "$repo_root")

  if [[ -n "$json_file" ]]; then
    local commands
    commands=$(jq -r '.up // [] | .[]' "$json_file" 2>/dev/null)
    if [[ -n "$commands" ]]; then
      echo "Running up commands..."
      while IFS= read -r cmd; do
        cmd="${cmd//\$ROOT_WORKTREE_PATH/$repo_root}"
        echo "  Running: $cmd"
        (cd "$worktree_path" && eval "$cmd")
      done <<< "$commands"
    else
      echo "No 'up' commands configured in .cursor/worktrees.json"
    fi
  else
    echo "No .cursor/worktrees.json found"
  fi
}

_wt_run_down_commands() {
  local repo_root="$1"
  local worktree_path="$2"
  local json_file
  json_file=$(_wt_get_worktree_json "$repo_root")

  if [[ -n "$json_file" ]]; then
    local commands
    commands=$(jq -r '.down // [] | .[]' "$json_file" 2>/dev/null)
    if [[ -n "$commands" ]]; then
      echo "Running down commands..."
      while IFS= read -r cmd; do
        cmd="${cmd//\$ROOT_WORKTREE_PATH/$repo_root}"
        echo "  Running: $cmd"
        (cd "$worktree_path" && eval "$cmd")
      done <<< "$commands"
    else
      echo "No 'down' commands configured in .cursor/worktrees.json"
    fi
  else
    echo "No .cursor/worktrees.json found"
  fi
}

_wt_new() {
  local use_existing=false
  local use_pr=false
  local run_up=false
  local no_cd=false
  local branch_arg=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -b|--branch)
        use_existing=true
        shift
        ;;
      -p|--pr)
        use_pr=true
        shift
        ;;
      -u|--up)
        run_up=true
        shift
        ;;
      -n|--no-cd)
        no_cd=true
        shift
        ;;
      *)
        branch_arg="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$branch_arg" ]]; then
    echo "Usage: wt new <branch-suffix>"
    echo "       wt new -b <existing-branch>"
    echo "       wt new -p <pr-number>"
    echo "       wt new -u <branch>  (also run 'up' commands)"
    echo "       wt new -n <branch>  (don't cd into worktree)"
    return 1
  fi

  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(_wt_get_main_worktree)
  local base_name
  base_name=$(basename "$main_worktree")
  local parent_dir
  parent_dir=$(dirname "$main_worktree")

  local branch_name
  local worktree_path

  # Worktrees go in ../.worktrees/reponame/branchname
  local worktrees_dir="$parent_dir/.worktrees/$base_name"

  if [[ "$use_pr" == true ]]; then
    # Using PR number - requires gh CLI
    if ! command -v gh &>/dev/null; then
      echo "Error: gh CLI is required for PR checkout"
      echo "  Install: https://cli.github.com/"
      return 1
    fi

    local pr_number="$branch_arg"
    echo "Fetching PR #$pr_number..."

    # Get PR branch name using gh CLI
    branch_name=$(gh pr view "$pr_number" --json headRefName -q '.headRefName' 2>/dev/null)
    if [[ -z "$branch_name" ]]; then
      echo "Error: Could not fetch PR #$pr_number"
      echo "  Make sure the PR exists and you have access"
      return 1
    fi

    # Check if branch exists locally, if not fetch it
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      echo "Branch '$branch_name' already exists locally"
    else
      echo "Fetching branch '$branch_name'..."
      if ! git fetch origin "$branch_name:$branch_name" 2>/dev/null; then
        # Try fetching via PR ref
        if ! git fetch origin "pull/$pr_number/head:$branch_name" 2>/dev/null; then
          echo "Error: Could not fetch PR branch"
          return 1
        fi
      fi
    fi

    mkdir -p "$worktrees_dir"
    worktree_path="$worktrees_dir/$branch_name"

    echo "Creating worktree from PR #$pr_number:"
    echo "  Branch: $branch_name"
    echo "  Path: $worktree_path"

    if ! git worktree add "$worktree_path" "$branch_name"; then
      echo "Error: Failed to create worktree"
      return 1
    fi
  elif [[ "$use_existing" == true ]]; then
    # Using existing branch
    # Strip origin/ prefix if present
    branch_name="${branch_arg#origin/}"

    # Check if branch exists locally
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
      # Try to fetch the branch
      echo "Branch '$branch_name' not found locally, fetching..."
      if ! git fetch origin "$branch_name:$branch_name" 2>/dev/null; then
        echo "Error: Branch '$branch_name' not found locally or on remote"
        return 1
      fi
    fi

    mkdir -p "$worktrees_dir"
    worktree_path="$worktrees_dir/$branch_name"

    echo "Creating worktree from existing branch:"
    echo "  Branch: $branch_name"
    echo "  Path: $worktree_path"

    if ! git worktree add "$worktree_path" "$branch_name"; then
      echo "Error: Failed to create worktree"
      return 1
    fi
  else
    # Creating new branch - use clean branch name (no repo prefix)
    branch_name="$branch_arg"

    mkdir -p "$worktrees_dir"
    worktree_path="$worktrees_dir/$branch_name"

    echo "Creating worktree with new branch:"
    echo "  Branch: $branch_name"
    echo "  Path: $worktree_path"

    if ! git worktree add -b "$branch_name" "$worktree_path"; then
      echo "Error: Failed to create worktree"
      return 1
    fi
  fi

  _wt_run_setup_commands "$main_worktree" "$worktree_path"

  if [[ "$run_up" == true ]]; then
    _wt_run_up_commands "$main_worktree" "$worktree_path"
  fi

  if [[ "$no_cd" == true ]]; then
    echo "Worktree created at: $worktree_path"
    return 0
  fi

  cd "$worktree_path" || return 1

  _wt_ensure_config
  local cmd
  cmd=$(_wt_get_config_command)
  if [[ -n "$cmd" ]]; then
    echo "Running: $cmd"
    eval "$cmd"
  fi
}

_wt_up() {
  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(_wt_get_main_worktree)
  _wt_run_up_commands "$main_worktree" "$repo_root"
}

_wt_down() {
  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(_wt_get_main_worktree)
  _wt_run_down_commands "$main_worktree" "$repo_root"
}

_wt_ls() {
  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  echo "Worktrees:"
  local wt_path="" branch="" is_detached=false is_prunable=false

  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
      branch=""
      is_detached=false
      is_prunable=false
    elif [[ "$line" == branch\ * ]]; then
      branch="${line#branch refs/heads/}"
    elif [[ "$line" == "detached" ]]; then
      is_detached=true
    elif [[ "$line" == prunable\ * ]]; then
      is_prunable=true
    elif [[ -z "$line" && -n "$wt_path" ]]; then
      # Empty line = end of entry, print it
      if [[ "$is_prunable" == true ]]; then
        # Skip prunable/stale worktrees
        wt_path=""
        continue
      fi

      local display_name="$branch"
      if [[ -z "$display_name" ]]; then
        display_name="(detached)"
      fi

      local wt_status=""
      local status_check=""
      status_check="$(_wt_get_status "$wt_path")"

      case "$status_check" in
        clean) wt_status="${_wt_green}ok${_wt_reset}" ;;
        unpushed) wt_status="${_wt_yellow}unpushed${_wt_reset}" ;;
        dirty) wt_status="${_wt_red}dirty${_wt_reset}" ;;
        *) wt_status="${_wt_red}dirty${_wt_reset}" ;;
      esac

      printf "  %-30s %-10s %s\n" "$display_name" "[$wt_status]" "$wt_path"
      wt_path=""
    fi
  done < <(git worktree list --porcelain; echo)
}

_wt_find_worktree() {
  local name="$1"
  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    return 1
  fi

  local main_worktree
  main_worktree=$(_wt_get_main_worktree)
  local base_name
  base_name=$(basename "$main_worktree")

  # Check if name matches main worktree
  if [[ "$name" == "$base_name" ]] || [[ "$name" == "main" ]]; then
    echo "$main_worktree"
    return 0
  fi

  # Check if it's a full path to a valid worktree
  if [[ -d "$name" ]] && git -C "$name" rev-parse --git-dir &>/dev/null; then
    echo "$name"
    return 0
  fi

  # Query git worktree list to find by branch name
  local wt_path=""
  local wt_branch=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
    elif [[ "$line" == branch\ * ]]; then
      wt_branch="${line#branch refs/heads/}"
      if [[ "$wt_branch" == "$name" ]]; then
        echo "$wt_path"
        return 0
      fi
    fi
  done < <(git worktree list --porcelain)

  return 1
}

_wt_cd() {
  local name="$1"

  if [[ -z "$name" ]]; then
    # No name given - cd to main worktree
    local main_worktree
    main_worktree=$(_wt_get_main_worktree)
    if [[ -n "$main_worktree" ]]; then
      cd "$main_worktree" || return 1
      return 0
    else
      echo "Error: Could not find main worktree"
      return 1
    fi
  fi

  local wt_path
  wt_path=$(_wt_find_worktree "$name")
  if [[ -z "$wt_path" ]]; then
    echo "Error: Worktree '$name' not found"
    return 1
  fi

  cd "$wt_path" || return 1
}

_wt_rm() {
  local force=false
  local name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force) force=true; shift ;;
      *) name="$1"; shift ;;
    esac
  done

  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(_wt_get_main_worktree)

  local wt_path
  if [[ -z "$name" ]]; then
    # No name given - remove current worktree
    wt_path="$repo_root"

    # Check if we're in the main worktree
    if [[ "$wt_path" == "$main_worktree" ]]; then
      echo "Error: Cannot remove main worktree"
      return 1
    fi
  else
    wt_path=$(_wt_find_worktree "$name")
    if [[ -z "$wt_path" ]]; then
      echo "Error: Worktree '$name' not found"
      return 1
    fi

    # Check if trying to remove main worktree
    if [[ "$wt_path" == "$main_worktree" ]]; then
      echo "Error: Cannot remove main worktree"
      return 1
    fi
  fi

  # Safety check
  if [[ "$force" != true ]]; then
    if ! _wt_is_clean "$wt_path"; then
      echo "Error: Worktree has uncommitted changes. Use -f to force."
      return 1
    fi
    if ! _wt_is_pushed "$wt_path"; then
      echo "Error: Worktree has unpushed commits. Use -f to force."
      return 1
    fi
  fi

  _wt_run_cleanup_commands "$repo_root" "$wt_path"

  # cd to main worktree before removing (if we're in the worktree being removed)
  if [[ "$PWD" == "$wt_path"* ]]; then
    cd "$main_worktree" || return 1
    echo "Changed to main worktree: $main_worktree"
  fi

  echo "Removing worktree: $wt_path"
  git worktree remove "$wt_path" ${force:+--force}
}

_wt_purge() {
  local repo_root
  repo_root=$(_wt_get_repo_root)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(git worktree list --porcelain | grep -A2 "^worktree " | head -1)
  main_worktree="${main_worktree#worktree }"

  echo "Checking worktrees for cleanup..."
  echo ""

  local dirty_count=0
  local removed_count=0

  git worktree list --porcelain | while read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      local wt_path="${line#worktree }"

      # Read HEAD line
      read -r _

      # Read branch line
      local branch=""
      read -r branch_line
      if [[ "$branch_line" == branch\ * ]]; then
        branch="${branch_line#branch refs/heads/}"
      fi

      # Read empty line between entries
      read -r _ || true

      # Skip main worktree
      if [[ "$wt_path" == "$main_worktree" ]]; then
        continue
      fi

      # Single git command to check status
      local wt_status
      wt_status=$(_wt_get_status "$wt_path")

      if [[ "$wt_status" == "clean" ]]; then
        printf "Remove %s (%s)? [y/N] " "$branch" "$wt_path"
        read -r response </dev/tty
        if [[ "$response" =~ ^[Yy]$ ]]; then
          _wt_run_cleanup_commands "$repo_root" "$wt_path"
          git worktree remove "$wt_path"
          echo "  Removed."
          ((removed_count++))
        fi
      else
        case "$wt_status" in
          dirty) echo "SKIP: $branch - uncommitted changes" ;;
          unpushed) echo "SKIP: $branch - unpushed commits" ;;
          *) echo "SKIP: $branch - uncommitted changes + unpushed commits" ;;
        esac
        ((dirty_count++))
      fi
    fi
  done

  echo ""
  echo "Done."
}

_wt_prune() {
  echo "Pruning stale worktree references..."
  git worktree prune -v
}

_wt_uninstall() {
  echo "Uninstalling wt-cli..."

  local WT_DIR="$HOME/.wt"
  local WT_SH="$WT_DIR/wt.sh"

  # Remove source lines from shell configs
  for file in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$file" ]] && grep -qF "source \"$WT_SH\"" "$file"; then
      grep -v "# wt-cli" "$file" | grep -v "source \"$WT_SH\"" | grep -v "fpath=" | grep -v "autoload -Uz compinit" > "$file.tmp"
      mv "$file.tmp" "$file"
      echo "Removed wt-cli from $file"
    fi
  done

  # Handle fish config separately (multi-line block)
  local fish_config="$HOME/.config/fish/config.fish"
  if [[ -f "$fish_config" ]] && grep -qF "# wt-cli" "$fish_config"; then
    sed '/# wt-cli/,/^end$/d' "$fish_config" > "$fish_config.tmp"
    mv "$fish_config.tmp" "$fish_config"
    echo "Removed wt-cli from $fish_config"
  fi

  # Remove wt directory
  if [[ -d "$WT_DIR" ]]; then
    rm -rf "$WT_DIR"
    echo "Removed $WT_DIR"
  fi

  echo ""
  echo "wt-cli uninstalled."
  echo "Config at ~/.config/wt/ preserved (remove manually if desired)."
}

_wt_update() {
  local current_version="$_WT_VERSION"
  local wt_file="$HOME/.wt/wt.sh"
  local backup_file="$HOME/.wt/wt.sh.backup"
  local url="https://raw.githubusercontent.com/jorgensandhaug/wt-cli/main/wt.sh"

  echo "Checking for updates..."

  # Backup current version
  if [[ -f "$wt_file" ]]; then
    cp "$wt_file" "$backup_file"
  fi

  # Download new version
  if curl -sSL "$url" -o "$wt_file.new"; then
    local new_version
    new_version=$(grep -m1 '_WT_VERSION=' "$wt_file.new" | cut -d'"' -f2)

    if [[ "$new_version" == "$current_version" ]]; then
      echo "Already at latest version ($current_version)"
      rm -f "$wt_file.new"
    else
      mv "$wt_file.new" "$wt_file"
      echo "Updated from $current_version to $new_version"
      echo "Backup saved to $backup_file"
    fi
  else
    echo "Error: Failed to download update"
    return 1
  fi
}

_wt_main() {
  _wt_setup_colors
  case "$1" in
    new) shift; _wt_new "$@" ;;
    ls) _wt_ls ;;
    cd) shift; _wt_cd "$@" ;;
    up) _wt_up ;;
    down) _wt_down ;;
    rm) shift; _wt_rm "$@" ;;
    purge) _wt_purge ;;
    prune) _wt_prune ;;
    config) _wt_config ;;
    update) _wt_update ;;
    uninstall) _wt_uninstall ;;
    version|-v|--version) _wt_version ;;
    ""|help|-h|--help) _wt_help ;;
    *)
      echo "Error: Unknown command '$1'"
      echo ""
      _wt_help
      return 1
      ;;
  esac
}

wt() {
  if ! type _wt_new &>/dev/null; then
    source "$HOME/.wt/wt.sh"
  fi
  _wt_main "$@"
}
