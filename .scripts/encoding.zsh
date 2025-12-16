## Fix common UTF-8 mis-encodings for Norwegian characters in files/directories
# Usage:
#   æøå <file|dir> [more files/dirs]
# This replaces sequences like 'Ã¥' -> 'å', 'Ã¸' -> 'ø', 'Ã¦' -> 'æ' in-place.
fix_aeoa() {
  if [[ $# -lt 1 ]]; then
    echo "usage: æøå <file|dir> [more]"
    return 1
  fi

  local target tmp file
  local processed=0 changed=0

  for target in "$@"; do
    if [[ -f "$target" ]]; then
      tmp="$(mktemp -t fix-aeoa.XXXXXX)" || return 1
      awk '{gsub(/Ã¥/, "å"); gsub(/Ã¸/, "ø"); gsub(/Ã¦/, "æ"); print}' "$target" > "$tmp" || { rm -f "$tmp"; return 1; }
      if cmp -s "$target" "$tmp"; then
        rm -f "$tmp"
      else
        mv "$tmp" "$target"
        ((changed++))
      fi
      ((processed++))
    elif [[ -d "$target" ]]; then
      while IFS= read -r -d '' file; do
        tmp="$(mktemp -t fix-aeoa.XXXXXX)" || exit 1
        awk '{gsub(/Ã¥/, "å"); gsub(/Ã¸/, "ø"); gsub(/Ã¦/, "æ"); print}' "$file" > "$tmp" || { rm -f "$tmp"; exit 1; }
        if cmp -s "$file" "$tmp"; then
          rm -f "$tmp"
        else
          mv "$tmp" "$file"
          ((changed++))
        fi
        ((processed++))
      done < <(find "$target" -type f -print0)
    else
      echo "skip: '$target' not found"
    fi
  done

  echo "✓ æøå: processed ${processed} file(s), changed ${changed}."
}

# Friendly alias with Norwegian name
alias 'æøå'=fix_aeoa

