# Symlink CLAUDE.md -> AGENTS.md in the current directory
agentmd() {
  if [[ ! -f "AGENTS.md" ]]; then
    echo "No AGENTS.md found in current directory"
    return 1
  fi
  if [[ -e "CLAUDE.md" ]]; then
    echo "CLAUDE.md already exists"
    return 1
  fi
  ln -s AGENTS.md CLAUDE.md
  echo "CLAUDE.md -> AGENTS.md"
}
