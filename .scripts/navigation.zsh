mcd() {
  mkdir -p "$1" && cd "$1"
}

# yazi wrapper to cd
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Open directory in Warp terminal
warp() {
  local target_path="${1:-.}"
  
  # Resolve to absolute path
  if [[ "$target_path" == "." ]]; then
    target_path="$PWD"
  elif [[ "$target_path" == ".."* ]]; then
    target_path="$(cd "$target_path" 2>/dev/null && pwd)"
  elif [[ "$target_path" != /* ]]; then
    target_path="$PWD/$target_path"
  fi
  
  # Verify path exists
  if [[ ! -d "$target_path" ]]; then
    echo "Error: Directory does not exist: $target_path"
    return 1
  fi
  
  # Open in Warp
  open -a "Warp" "$target_path"
}


# Create a directory and cd into it (alternative to mcd)
take() {
  mkdir -p "$1" && cd "$1"
}
