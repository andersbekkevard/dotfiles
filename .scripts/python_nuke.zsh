# Python clean install script (uv-based)
python_nuke() {
  # Styles
  local BOLD=$'\033[1m'
  local RED=$'\033[0;31m'
  local GREEN=$'\033[0;32m'
  local YELLOW=$'\033[0;33m'
  local BLUE=$'\033[0;34m'
  local CYAN=$'\033[0;36m'
  local MAGENTA=$'\033[0;35m'
  local DIM=$'\033[2m'
  local RESET=$'\033[0m'

  echo -e "${BOLD}${BLUE}Python Cleanup & UV Migration${RESET}"

  # 1) Check for Python project indicators
  local project_file=""
  if [[ -f pyproject.toml ]]; then
    project_file="pyproject.toml"
  elif [[ -f requirements.txt ]]; then
    project_file="requirements.txt"
  elif [[ -f setup.py ]]; then
    project_file="setup.py"
  elif [[ -f Pipfile ]]; then
    project_file="Pipfile"
  fi

  if [[ -z "$project_file" ]]; then
    echo -e "${RED}Error: No Python project files (pyproject.toml, requirements.txt, setup.py, Pipfile) found.${RESET}"
    return 1
  fi

  # 2) Check if uv is installed
  if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: 'uv' is not installed. Please install it first: https://github.com/astral-sh/uv${RESET}"
    return 1
  fi

  # 3) Detect existing venvs and lockfiles
  local venv_patterns=(".venv" "venv" ".env" "env")
  local existing_venvs=()
  for p in "${venv_patterns[@]}"; do
    [[ -d "$p" ]] && existing_venvs+=("$p")
  done

  local lockfiles=("poetry.lock" "Pipfile.lock" "uv.lock" "pdm.lock")
  local existing_locks=()
  for lock in "${lockfiles[@]}"; do
    [[ -f "$lock" ]] && existing_locks+=("$lock")
  done

  # 4) Tree View / Project Context
  local current_dir="${PWD##*/}"
  echo -e "${BOLD}${BLUE} ${current_dir}${RESET} ${DIM}(via uv)${RESET}"

  local -a items
  # Get all files/dirs, dotfiles included, sorted by name
  items=( *(D) )
  # Filter out git folder and .DS_Store to reduce noise
  items=( ${items:#.git} )
  items=( ${items:#.DS_Store} )

  local total=${#items}
  local i=0

  for item in $items; do
    ((i++))
    local prefix="├──"
    [[ $i -eq $total ]] && prefix="└──"

    local color="$RESET"
    local icon="" # default file icon
    local suffix=""

    if [[ -d "$item" ]]; then
      color="$BLUE"
      icon="" # directory icon
    fi

    # Check if it's a venv
    local is_venv=0
    if [[ -d "$item" && -f "$item/pyvenv.cfg" ]]; then
      is_venv=1
    else
      for v in "${existing_venvs[@]}"; do
        if [[ "$item" == "$v" ]]; then
          is_venv=1
          break
        fi
      done
    fi

    # Check if it's a lockfile
    local is_lock=0
    for l in "${existing_locks[@]}"; do
      if [[ "$item" == "$l" ]]; then
        is_lock=1
        break
      fi
    done

    # Specific coloring/icons for relevant files (Nerd Font icons)
    if [[ $is_venv -eq 1 ]]; then
      color="${RED}"
      icon=""
      suffix=" ${DIM}(will remove venv)${RESET}"
    elif [[ $is_lock -eq 1 ]]; then
      color="${RED}"
      icon=""
      suffix=" ${DIM}(will remove)${RESET}"
    elif [[ "$item" == "pyproject.toml" ]]; then
      color="${GREEN}"
      icon=""
    elif [[ "$item" == "requirements.txt" || "$item" == "requirements-dev.txt" ]]; then
      color="${YELLOW}"
      icon=""
    elif [[ "$item" == ".python-version" ]]; then
      color="${MAGENTA}"
      icon=""
    elif [[ "$item" =~ \.py$ ]]; then
      color="${CYAN}"
      icon=""
    elif [[ "$item" =~ \.json$ ]]; then
      color="${YELLOW}"
      icon=""
    elif [[ "$item" =~ \.md$ ]]; then
      color="${BLUE}"
      icon=""
    elif [[ "$item" =~ ^\..* ]]; then # dotfiles
      color="${DIM}"
      icon=""
    fi

    echo -e "${DIM}${prefix}${RESET} ${color}${icon} ${item}${RESET}${suffix}"
  done

  # Confirmation
  echo ""
  read -q "REPLY?${BOLD}Proceed with uv cleanup and sync? [y/N] ${RESET}"
  echo "" # Newline after read -q
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${DIM}Aborted.${RESET}"
    return 0
  fi

  local start_time=$SECONDS

  # 5) Clean and reinstall
  echo -e "\n${BOLD}${CYAN}Phase 1: Cleanup${RESET}"

  for v in "${existing_venvs[@]}"; do
    echo -ne "  ${RED}rm${RESET} $v"
    if ! rm -rf "$v"; then
      echo -e " ${RED}FAILED${RESET}"
      echo -e "${RED}Error: Could not remove $v. Aborting.${RESET}"
      return 1
    fi
    echo -e " ${GREEN}✓${RESET}"
  done

  if [[ ${#existing_locks[@]} -gt 0 ]]; then
      echo -ne "  ${RED}rm${RESET} lockfiles"
      if ! rm -f "${existing_locks[@]}"; then
        echo -e "    ${RED}FAILED${RESET}"
        echo -e "${RED}Error: Could not remove lockfiles. Aborting.${RESET}"
        return 1
      fi
      echo -e "    ${GREEN}✓${RESET}"
  fi

  echo -e "\n${BOLD}${CYAN}Phase 2: Setup${RESET}"

  # If no pyproject.toml, create one
  if [[ ! -f pyproject.toml ]]; then
    echo -e "${DIM}No pyproject.toml found. Initializing...${RESET}"
    
    # Check if boilerplate targets exist before init to avoid deleting user files
    local hello_exists_before=0
    [[ -f hello.py ]] && hello_exists_before=1
    local main_exists_before=0
    [[ -f main.py ]] && main_exists_before=1

    uv init --no-readme
    
    # Only remove if they were created by uv init (didn't exist before)
    [[ $hello_exists_before -eq 0 && -f hello.py ]] && rm hello.py
    [[ $main_exists_before -eq 0 && -f main.py ]] && rm main.py

    if [[ -f requirements.txt ]]; then
      echo -e "${DIM}Migrating dependencies from requirements.txt...${RESET}"
      uv add -r requirements.txt
    fi
  fi

  echo -e "${DIM}Running uv lock & sync...${RESET}"
  echo -e "${DIM}----------------------------------------${RESET}"

  # Ensure python version is available if .python-version exists
  if [[ -f .python-version ]]; then
    local py_ver=$(cat .python-version)
    echo -e "${DIM}Ensuring Python ${py_ver} is installed...${RESET}"
    uv python install "$py_ver"
  fi

  # Run uv lock and sync
  uv lock && uv sync
  local ret=$?

  echo -e "${DIM}----------------------------------------${RESET}"

  local duration=$(( SECONDS - start_time ))

  if [ $ret -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}Done in ${duration}s${RESET}"
  else
    echo -e "\n${BOLD}${RED}Failed (${duration}s)${RESET}"
    return $ret
  fi
}

alias pnuke='python_nuke'

