# Clean install script for JS/TS projects
clean_install() {
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

  echo -e "${BOLD}${BLUE}Cleanup & Reinstall${RESET}"

  # 1) Must look like a JS/TS project root: package.json exists
  if [[ ! -f package.json ]]; then
    echo -e "${RED}Error: No package.json in current directory.${RESET}"
    return 1
  fi

  # 2) Detect Package Manager & Force pnpm for centralized storage
  local pm="pnpm"
  local install_cmd="pnpm install"
  
  # Check what WAS being used just for the notice
  local original_pm="npm"
  if [[ -f pnpm-lock.yaml ]]; then
    original_pm="pnpm"
  elif [[ -f bun.lockb ]]; then
    original_pm="bun"
  elif [[ -f yarn.lock ]]; then
    original_pm="yarn"
  fi

  if [[ "$original_pm" != "pnpm" ]]; then
    echo -e "${YELLOW}Notice: Converting from ${original_pm} to pnpm for centralized storage...${RESET}"
  fi

  # 3) Verification: must contain at least one node_modules directory or a lockfile
  local nm_count
  nm_count="$(find . -type d -name node_modules -prune 2>/dev/null | wc -l | tr -d '[:space:]')"

  if [[ "$nm_count" == "0" ]] && [[ ! -f pnpm-lock.yaml ]] && [[ ! -f bun.lockb ]] && [[ ! -f yarn.lock ]] && [[ ! -f package-lock.json ]]; then
    echo -e "${RED}Error: No node_modules or lockfile found.${RESET}"
    echo -e "${DIM}Refusing to run in a folder that doesn't look like an installed project.${RESET}"
    return 1
  fi

  if [[ "$nm_count" -gt "1" ]]; then
     echo -e "${YELLOW}Warning: Found ${nm_count} node_modules directories.${RESET}"
     echo -e "${DIM}This script will only remove the one in the current directory.${RESET}"
  fi
  
  # Tree View / Project Context
  local current_dir="${PWD##*/}"
  echo -e "${BOLD}${BLUE} ${current_dir}${RESET} ${DIM}(via ${pm})${RESET}"
  
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
    
    # Specific coloring/icons for relevant files (Nerd Font icons)
    if [[ "$item" == "node_modules" ]]; then
      color="${RED}"
      icon=""
      suffix=" ${DIM}(will remove)${RESET}"
    elif [[ "$item" == ".pnpm-store" ]]; then
      color="${RED}"
      icon=""
      suffix=" ${DIM}(will remove)${RESET}"
    elif [[ "$item" == "package.json" ]]; then
      color="${GREEN}"
      icon=""
    elif [[ "$item" =~ \.json$ ]]; then
      color="${YELLOW}"
      icon=""
    elif [[ "$item" =~ \.ts$ ]]; then
      color="${CYAN}"
      icon=""
    elif [[ "$item" =~ \.js$ ]]; then
      color="${YELLOW}"
      icon=""
    elif [[ "$item" =~ \.md$ ]]; then
      color="${BLUE}"
      icon=""
    elif [[ "$item" =~ ^\..* ]]; then # dotfiles
      color="${DIM}"
      icon=""
    elif [[ "$item" =~ ^(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb|npm-shrinkwrap\.json)$ ]]; then
      color="${RED}"
      icon=""
      suffix=" ${DIM}(will remove)${RESET}"
    fi
    
    echo -e "${DIM}${prefix}${RESET} ${color}${icon} ${item}${RESET}${suffix}"
  done
  
  # Confirmation
  echo ""
  read -q "REPLY?${BOLD}Proceed with clean install using ${pm}? [y/N] ${RESET}"
  echo "" # Newline after read -q
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${DIM}Aborted.${RESET}"
    return 0
  fi

  local start_time=$SECONDS

  # 4) Clean and reinstall
  echo -e "\n${BOLD}${CYAN}Phase 1: Cleanup${RESET}"
  
  if [[ -d node_modules ]]; then
    echo -ne "  ${RED}rm${RESET} node_modules"
    if ! rm -rf ./node_modules; then
      echo -e " ${RED}FAILED${RESET}"
      echo -e "${RED}Error: Could not remove node_modules. Aborting.${RESET}"
      return 1
    fi
    echo -e " ${GREEN}✓${RESET}"
  fi

  if [[ -d .pnpm-store ]]; then
    echo -ne "  ${RED}rm${RESET} .pnpm-store"
    if ! rm -rf ./.pnpm-store; then
      echo -e " ${RED}FAILED${RESET}"
      echo -e "${RED}Error: Could not remove .pnpm-store. Aborting.${RESET}"
      return 1
    fi
    echo -e " ${GREEN}✓${RESET}"
  fi

  # Check if any lockfiles exist before trying to remove them to avoid empty output
  local lockfiles=(./package-lock.json ./npm-shrinkwrap.json ./yarn.lock ./pnpm-lock.yaml ./bun.lockb)
  local existing_locks=()
  for lock in "${lockfiles[@]}"; do
    [[ -f "$lock" ]] && existing_locks+=("$lock")
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

  echo -e "\n${BOLD}${CYAN}Phase 2: Install${RESET}"
  echo -e "${DIM}Using ${BOLD}${pm}${RESET}${DIM}...${RESET}"
  echo -e "${DIM}----------------------------------------${RESET}"
  
  # Run install command and show output
  eval "$install_cmd"
  local install_status=$?
  
  echo -e "${DIM}----------------------------------------${RESET}"

  local duration=$(( SECONDS - start_time ))
  
  if [ $install_status -eq 0 ]; then
    echo -e "\n${BOLD}${GREEN}Done in ${duration}s${RESET}"
  else
    echo -e "\n${BOLD}${RED}Failed (${duration}s)${RESET}"
    return $install_status
  fi
}

alias nuke='clean_install'
