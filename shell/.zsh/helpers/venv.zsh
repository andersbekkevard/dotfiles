# Script to activate nearest venv
av() {
    local found=()
    local activate_script=""
    
    # Common venv directory patterns (priority order)
    local patterns=(".venv" "venv" ".env" "env" "*venv*" "*env*" "virtualenv")
    
    # First, try common patterns in current directory
    for pattern in "${patterns[@]}"; do
        for dir in $pattern(N/); do
            if [[ -f "$dir/bin/activate" ]]; then
                found+=("$dir/bin/activate")
            fi
        done
        # Stop if we found matches for this pattern
        [[ ${#found[@]} -gt 0 ]] && break
    done
    
    # Fallback: search recursively for any bin/activate (max depth 3)
    if [[ ${#found[@]} -eq 0 ]]; then
        while IFS= read -r script; do
            found+=("$script")
        done < <(find . -maxdepth 4 -path "*/bin/activate" -type f 2>/dev/null | head -5)
    fi
    
    # Handle results
    if [[ ${#found[@]} -eq 0 ]]; then
        echo "✗ No virtual environment found"
        return 1
    elif [[ ${#found[@]} -eq 1 ]]; then
        activate_script="${found[1]}"
    else
        # Multiple venvs found - let user choose
        echo "Multiple venvs found:"
        local i=1
        for script in "${found[@]}"; do
            local venv_name=$(dirname $(dirname "$script"))
            echo "  $i) $venv_name"
            ((i++))
        done
        echo -n "Select [1-${#found[@]}]: "
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#found[@]} )); then
            activate_script="${found[$choice]}"
        else
            echo "✗ Invalid selection"
            return 1
        fi
    fi
    
    # Activate the venv
    source "$activate_script"
    local venv_name=$(basename $(dirname $(dirname "$activate_script")))
    echo "✓ Activated: $venv_name"
}

