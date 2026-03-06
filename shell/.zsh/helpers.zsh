for helper_file in "$HOME"/.zsh/helpers/*.zsh; do
  [[ -r "$helper_file" ]] && source "$helper_file"
done
