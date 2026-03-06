# Function to run pytex and pdflatex
pytex() {
  if [[ -z "$1" ]]; then
    echo "usage: pytex <file[.tex]>"
    return 1
  fi
  local tex="${1%.tex}.tex"
  local dir="${tex:h}"
  local file="${tex:t}"
  local base="${file:r}"

  (
    cd "$dir" || exit 1
    # First pass: do not stop on missing graphics
    pdflatex -shell-escape -interaction=nonstopmode "$file" &&
    pythontex "$file" &&
    # Final pass: stop on real errors
    pdflatex -halt-on-error "$file"
  ) || return $?

  (
    cd "$dir" || exit 1
    rm -f "$base".{aux,log,pytxcode} 2>/dev/null
    rm -rf "pythontex-files-$base"
  )
}

