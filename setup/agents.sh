#!/usr/bin/env bash
# Agent surface: global skills + instructions for Claude Code and Codex.
#
# Canonical content lives in agents/ (skills/, SHARED.global.md,
# AGENTS.global.md, CLAUDE.global.md, skillctl). Optional machine-local
# instruction overlays live under agents/.local/ and are appended after the
# tracked global sources.
# Claude Code and Codex read flat per-skill symlinks at
# ~/.claude/skills/<name> and ~/.codex/skills/<name>. Active tracked skills are
# flat under agents/skills/; candidates under agents/in-progress/ are not
# projected. Codex links are maintained by `skillctl sync` so Codex-managed
# content such as .system/ stays untouched beside them.

agent_mkdir_p() {
  local dir="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "[dry-run] Create directory $dir"
    return 0
  fi
  mkdir -p "$dir"
}

is_locked_git_crypt_file() {
  local file="$1" prefix
  [[ -f "$file" ]] || return 1
  prefix="$(LC_ALL=C od -An -tx1 -N10 "$file" 2>/dev/null | tr -d '[:space:]')"
  [[ "$prefix" == "00474954435259505400" ]]
}

available_agent_skill_dir() {
  local skill_dir="$1" skill_file
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    skill_file="$skill_dir/SKILL.md"
  elif [[ -f "$skill_dir/SKILL.off.md" ]]; then
    skill_file="$skill_dir/SKILL.off.md"
  else
    return 1
  fi
  ! is_locked_git_crypt_file "$skill_file"
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
        [[ -e "$target" && "$link" == "$expected" ]] && \
          available_agent_skill_dir "$target" && continue
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

  # Tracked active skills are flat; ignored machine-local skills keep their
  # skills/.local/<name> namespace.
  for skill_dir in "$managed_skills_dir"/* "$managed_skills_dir"/.local/*; do
    [[ -d "$skill_dir" ]] || continue
    if ! available_agent_skill_dir "$skill_dir"; then
      if is_locked_git_crypt_file "$skill_dir/SKILL.md" || \
         is_locked_git_crypt_file "$skill_dir/SKILL.off.md"; then
        log_info "Skipping locked private Claude skill $(basename "$skill_dir")"
      fi
      continue
    fi
    link_claude_skill "$skill_dir" "$claude_skills_dir"
  done
}

agent_skill_dirs() {
  local managed_skills_dir="$DOTFILES_DIR/agents/skills"
  local skill_dir

  for skill_dir in "$managed_skills_dir"/* "$managed_skills_dir"/.local/*; do
    [[ -d "$skill_dir" ]] || continue
    available_agent_skill_dir "$skill_dir" || continue
    printf '%s\n' "$skill_dir"
  done
}

verify_agent_skill_links() {
  local failures=0 harness skill_dir name link target
  local managed_skills_dir="$DOTFILES_DIR/agents/skills"

  while IFS= read -r skill_dir; do
    [[ -n "$skill_dir" ]] || continue
    name="$(basename "$skill_dir")"
    for harness in claude codex; do
      link="$HOME/.$harness/skills/$name"
      if [[ ! -L "$link" ]]; then
        printf 'missing %s skill link: %s\n' "$harness" "$link"
        failures=1
        continue
      fi
      target="$(readlink "$link")"
      if [[ "$target" != "$skill_dir" ]]; then
        printf 'wrong %s skill link: %s -> %s (expected %s)\n' \
          "$harness" "$link" "$target" "$skill_dir"
        failures=1
      fi
    done
  done < <(agent_skill_dirs)

  for harness in claude codex; do
    [[ -d "$HOME/.$harness/skills" ]] || continue
    while IFS= read -r -d '' link; do
      target="$(readlink "$link")"
      case "$target" in
        "$managed_skills_dir"/*)
          name="$(basename "$target")"
          if [[ "$link" != "$HOME/.$harness/skills/$name" || ! -d "$target" ]] ||
             ! available_agent_skill_dir "$target"; then
            printf 'stale managed %s skill link: %s -> %s\n' "$harness" "$link" "$target"
            failures=1
          fi
          ;;
      esac
    done < <(find "$HOME/.$harness/skills" -type l -print0 2>/dev/null)
  done

  return $failures
}

verify_agent_surface() {
  local agents_dir="$DOTFILES_DIR/agents"
  local failures=0

  verify_agent_skill_links || failures=1

  if [[ -x "$agents_dir/instructionctl" ]]; then
    "$agents_dir/instructionctl" verify || failures=1
  else
    printf 'missing executable: %s\n' "$agents_dir/instructionctl"
    failures=1
  fi

  if command_exists python3; then
    python3 "$agents_dir/skillctl" verify || failures=1
    python3 "$agents_dir/skillpull" validate || failures=1
  else
    printf 'python3 not found; cannot validate the skill source manifest\n'
    failures=1
  fi

  if [[ ! -x "$agents_dir/skill-usage" ]]; then
    printf 'missing executable: %s\n' "$agents_dir/skill-usage"
    failures=1
  fi

  if [[ $failures -eq 0 ]]; then
    printf 'agents verify: ok\n'
    return 0
  fi

  printf 'agents verify: failed\n'
  return 1
}

status_agent_surface() {
  local agents_dir="$DOTFILES_DIR/agents"

  "$agents_dir/instructionctl" status
  printf '\n'
  if command_exists python3; then
    python3 "$agents_dir/skillctl" list
  else
    printf 'python3 not found; cannot inspect skill invocation state\n' >&2
    return 1
  fi
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
    run_cmd "Initialize local skill usage telemetry" \
      python3 "$agents_dir/skill-usage" init
  else
    log_warn "python3 not found; skipping skillctl sync and skill usage initialization"
  fi
  log_ok "agent surface refreshed"
}
