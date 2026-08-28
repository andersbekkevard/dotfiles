export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Ghostty sets its own terminal capabilities. Do not preserve a GUI launcher's
# request for monochrome output in commands started inside the terminal.
[[ "${TERM_PROGRAM:-}" == "ghostty" ]] && unset NO_COLOR

# Bun completions (must be in fpath before compinit)
[[ -d "$HOME/.bun" ]] && fpath=("$HOME/.bun" $fpath)
