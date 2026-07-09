#!/usr/bin/env bash
# Agent surface: global skills + instructions for Claude Code and Codex.
#
# Canonical content lives in agents/ (skills/, AGENTS.global.md, skillctl).
# Claude Code reads ~/.claude/skills/<name> per-skill symlinks and ~/.claude/CLAUDE.md.
# Codex reads ~/.codex/AGENTS.md and per-skill symlinks in ~/.codex/skills,
# maintained by `skillctl sync` so Codex-managed content (.system/) stays
# untouched beside them.

agent_mkdir_p() {
  local dir="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Create directory $dir"
    return 0
  fi
  mkdir -p "$dir"
}

link_agent_file() {
  local target="$1" dest="$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$dest" ]]; then
    return 0
  fi
  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Backup pre-existing $target"
    else
      backup_path "$target"
      log_warn "backed up pre-existing $target"
    fi
  fi
  run_cmd "Link $target -> $dest" ln -sfn "$dest" "$target"
}

ensure_claude_skill_dir() {
  local skills_dir="$1" managed_skills_dir="$2"

  if [[ -L "$skills_dir" && "$(readlink "$skills_dir")" == "$managed_skills_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Replace managed whole-dir symlink $skills_dir with per-skill link directory"
      return 0
    fi
    rm "$skills_dir"
    mkdir -p "$skills_dir"
    log_warn "replaced managed whole-dir symlink $skills_dir with per-skill link directory"
    return 0
  fi

  if [[ -L "$skills_dir" && ! -e "$skills_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Backup broken Claude skills symlink $skills_dir"
    else
      backup_path "$skills_dir"
      log_warn "backed up broken Claude skills symlink $skills_dir"
    fi
  fi

  if [[ -e "$skills_dir" && ! -d "$skills_dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "[dry-run] Backup non-directory $skills_dir"
    else
      backup_path "$skills_dir"
      log_warn "backed up non-directory $skills_dir"
    fi
  fi

  agent_mkdir_p "$skills_dir"
}

link_claude_skill() {
  local skill_dir="$1" claude_skills_dir="$2"
  local name link

  name="$(basename "$skill_dir")"
  link="$claude_skills_dir/$name"

  if [[ -L "$link" ]]; then
    if [[ "$(readlink "$link")" == "$skill_dir" ]]; then
      return 0
    fi
    log_warn "skipping Claude skill '$name': $link already points elsewhere"
    return 0
  fi

  if [[ -e "$link" ]]; then
    log_warn "skipping Claude skill '$name': $link already exists"
    return 0
  fi

  run_cmd "Link Claude skill $name" ln -s "$skill_dir" "$link"
}

prune_stale_claude_skill_links() {
  local claude_skills_dir="$1" managed_skills_dir="$2"
  local link target

  [[ -d "$claude_skills_dir" ]] || return 0

  for link in "$claude_skills_dir"/*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    case "$target" in
      "$managed_skills_dir"/*)
        [[ -e "$target" ]] && continue
        if [[ "$DRY_RUN" -eq 1 ]]; then
          log_info "[dry-run] Prune stale Claude skill link $link"
        else
          rm "$link"
          log_warn "pruned stale Claude skill link $link"
        fi
        ;;
    esac
  done
}

sync_claude_skill_links() {
  local managed_skills_dir="$1"
  local claude_skills_dir="$HOME/.claude/skills"
  local skill_dir

  ensure_claude_skill_dir "$claude_skills_dir" "$managed_skills_dir"
  prune_stale_claude_skill_links "$claude_skills_dir" "$managed_skills_dir"

  # Skills live one level below category folders (skills/<category>/<name>);
  # the harness link namespace stays flat, keyed by the skill dir's basename.
  for skill_dir in "$managed_skills_dir"/*/*; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" || -f "$skill_dir/SKILL.off.md" ]] || continue
    link_claude_skill "$skill_dir" "$claude_skills_dir"
  done
}

ensure_agent_surface() {
  log_info "Agent surface: global skills + instructions"
  local agents_dir="$DOTFILES_DIR/agents"

  if [[ ! -f "$agents_dir/AGENTS.global.md" || ! -x "$agents_dir/skillctl" || ! -d "$agents_dir/skills" ]]; then
    record_error "Agent surface source is incomplete under $agents_dir"
    return 0
  fi

  agent_mkdir_p "$HOME/.claude"
  agent_mkdir_p "$HOME/.codex"
  sync_claude_skill_links "$agents_dir/skills"
  link_agent_file "$HOME/.claude/CLAUDE.md" "$agents_dir/AGENTS.global.md"
  link_agent_file "$HOME/.codex/AGENTS.md" "$agents_dir/AGENTS.global.md"

  if command_exists python3; then
    run_cmd "Sync Codex skill links + yaml" python3 "$agents_dir/skillctl" sync
  else
    log_warn "python3 not found; skipping skillctl sync (Codex skill links + yaml)"
  fi
  log_ok "agent surface linked"
}
