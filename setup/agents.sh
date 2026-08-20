#!/usr/bin/env bash
# Agent surface: global skills + instructions for Claude Code and Codex.
#
# Canonical content lives in agents/ (skills/, SHARED.global.md,
# AGENTS.global.md, CLAUDE.global.md, skillctl). Optional machine-local
# instruction overlays live under agents/.local/ and are appended after the
# tracked global sources.
# Claude Code and Codex read flat per-skill symlinks at
# ~/.claude/skills/<name> and ~/.codex/skills/<name>. The canonical category
# hierarchy stays in the repo. Codex links are maintained by `skillctl sync`
# so Codex-managed content such as .system/ stays untouched beside them.

agent_mkdir_p() {
  local dir="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Create directory $dir"
    return 0
  fi
  mkdir -p "$dir"
}

render_agent_file() {
  local shared_source="$1" harness_source="$2"
  local shared_local_source="${3:-}" harness_local_source="${4:-}"
  local local_source

  printf '%s\n' '<!-- dotfiles-managed: composed global agent instructions -->'
  cat "$shared_source"
  printf '\n'
  cat "$harness_source"

  for local_source in "$shared_local_source" "$harness_local_source"; do
    [[ -n "$local_source" && -s "$local_source" ]] || continue
    printf '\n'
    cat "$local_source"
  done
}

compose_agent_file() {
  local target="$1" shared_source="$2" harness_source="$3" legacy_source="$4"
  local shared_local_source="${5:-}" harness_local_source="${6:-}"
  local first_line temp_file source_summary

  source_summary="$(basename "$shared_source") + $(basename "$harness_source")"
  if [[ -n "$shared_local_source" && -s "$shared_local_source" ]]; then
    source_summary="$source_summary + .local/$(basename "$shared_local_source")"
  fi
  if [[ -n "$harness_local_source" && -s "$harness_local_source" ]]; then
    source_summary="$source_summary + .local/$(basename "$harness_local_source")"
  fi

  if [[ -f "$target" ]] && cmp -s "$target" <(render_agent_file \
      "$shared_source" "$harness_source" "$shared_local_source" "$harness_local_source"); then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Compose $target from $source_summary"
    return 0
  fi

  temp_file="$(mktemp "${target}.tmp.XXXXXX")" || {
    record_error "Could not create temporary file for $target"
    return 1
  }
  if ! render_agent_file \
      "$shared_source" "$harness_source" "$shared_local_source" "$harness_local_source" \
      > "$temp_file"; then
    rm -f "$temp_file"
    record_error "Could not compose $target"
    return 1
  fi
  if ! chmod 0644 "$temp_file"; then
    rm -f "$temp_file"
    record_error "Could not set permissions on composed agent file $target"
    return 1
  fi

  if [[ -L "$target" && "$(readlink "$target")" == "$legacy_source" ]]; then
    if ! rm "$target"; then
      rm -f "$temp_file"
      record_error "Could not replace legacy managed link $target"
      return 1
    fi
    log_warn "replaced legacy managed link $target"
  elif [[ -e "$target" || -L "$target" ]]; then
    first_line=""
    if [[ -f "$target" ]]; then
      IFS= read -r first_line < "$target" || true
    fi
    if [[ "$first_line" != '<!-- dotfiles-managed: composed global agent instructions -->' ]]; then
      if ! backup_path "$target"; then
        rm -f "$temp_file"
        record_error "Could not back up pre-existing $target"
        return 1
      fi
      log_warn "backed up pre-existing $target"
    fi
  fi

  if ! mv "$temp_file" "$target"; then
    rm -f "$temp_file"
    record_error "Could not install composed agent file $target"
    return 1
  fi
  log_info "Composed $target from $source_summary"
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
  local link target expected name parent

  [[ -d "$claude_skills_dir" ]] || return 0

  while IFS= read -r -d '' link; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    case "$target" in
      "$managed_skills_dir"/*)
        name="$(basename "$target")"
        expected="$claude_skills_dir/$name"
        [[ -e "$target" && "$link" == "$expected" ]] && continue
        if [[ "$DRY_RUN" -eq 1 ]]; then
          log_info "[dry-run] Prune stale Claude skill link $link"
        else
          rm "$link"
          log_warn "pruned stale Claude skill link $link"
          parent="$(dirname "$link")"
          if [[ "$parent" != "$claude_skills_dir" ]]; then
            rmdir "$parent" 2>/dev/null || true
          fi
        fi
        ;;
    esac
  done < <(find "$claude_skills_dir" -mindepth 1 -maxdepth 2 -type l -print0)
}

sync_claude_skill_links() {
  local managed_skills_dir="$1"
  local claude_skills_dir="$HOME/.claude/skills"
  local skill_dir

  ensure_claude_skill_dir "$claude_skills_dir" "$managed_skills_dir"
  prune_stale_claude_skill_links "$claude_skills_dir" "$managed_skills_dir"

  # Flatten the canonical skills/<category>/<name> structure for Claude Code.
  # Skill names are globally unique, while the categorized source tree remains
  # authoritative for humans.
  for skill_dir in "$managed_skills_dir"/*/* "$managed_skills_dir"/.local/*; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" || -f "$skill_dir/SKILL.off.md" ]] || continue
    link_claude_skill "$skill_dir" "$claude_skills_dir"
  done
}

ensure_agent_surface() {
  log_info "Agent surface: global skills + instructions"
  local agents_dir="$DOTFILES_DIR/agents"
  local shared_source="$agents_dir/SHARED.global.md"
  local codex_source="$agents_dir/AGENTS.global.md"
  local claude_source="$agents_dir/CLAUDE.global.md"
  local shared_local_source="$agents_dir/.local/SHARED.md"
  local codex_local_source="$agents_dir/.local/AGENTS.md"
  local claude_local_source="$agents_dir/.local/CLAUDE.md"

  if [[ ! -f "$shared_source" || ! -f "$codex_source" || ! -f "$claude_source" || ! -x "$agents_dir/skillctl" || ! -d "$agents_dir/skills" ]]; then
    record_error "Agent surface source is incomplete under $agents_dir"
    return 0
  fi

  agent_mkdir_p "$HOME/.claude"
  agent_mkdir_p "$HOME/.codex"
  sync_claude_skill_links "$agents_dir/skills"
  compose_agent_file \
    "$HOME/.claude/CLAUDE.md" "$shared_source" "$claude_source" "$codex_source" \
    "$shared_local_source" "$claude_local_source"
  compose_agent_file \
    "$HOME/.codex/AGENTS.md" "$shared_source" "$codex_source" "$codex_source" \
    "$shared_local_source" "$codex_local_source"

  if command_exists python3; then
    run_cmd "Sync Codex skill links + yaml" python3 "$agents_dir/skillctl" sync
  else
    log_warn "python3 not found; skipping skillctl sync (Codex skill links + yaml)"
  fi
  log_ok "agent surface refreshed"
}
