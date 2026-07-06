#!/usr/bin/env bash
# Agent surface: global skills + instructions for Claude Code and Codex.
#
# Canonical content lives in agents/ (skills/, AGENTS.global.md, skillctl).
# Claude Code reads ~/.claude/skills (whole-dir symlink) and ~/.claude/CLAUDE.md.
# Codex reads ~/.codex/AGENTS.md and per-skill symlinks in ~/.codex/skills,
# maintained by `skillctl sync` so Codex-managed content (.system/) stays
# untouched beside them.

link_agent_file() {
  local target="$1" dest="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$dest" ]]; then
    return 0
  fi
  if [[ -e "$target" && ! -L "$target" ]]; then
    backup_path "$target"
    log_warn "backed up pre-existing $target"
  fi
  run_cmd ln -sfn "$dest" "$target"
}

ensure_agent_surface() {
  log_info "Agent surface: global skills + instructions"
  local agents_dir="$DOTFILES_DIR/agents"

  mkdir -p "$HOME/.claude" "$HOME/.codex"
  link_agent_file "$HOME/.claude/skills" "$agents_dir/skills"
  link_agent_file "$HOME/.claude/CLAUDE.md" "$agents_dir/AGENTS.global.md"
  link_agent_file "$HOME/.codex/AGENTS.md" "$agents_dir/AGENTS.global.md"

  if command_exists python3; then
    run_cmd python3 "$agents_dir/skillctl" sync
  else
    log_warn "python3 not found; skipping skillctl sync (Codex skill links + yaml)"
  fi
  log_ok "agent surface linked"
}
