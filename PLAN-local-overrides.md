# Plan: Extend Machine-Local Overrides to All Shell Lifecycle Stages

## Problem statement

Machine-local configuration is currently limited to `~/.zshrc.local`, which only runs in interactive zsh sessions. This creates two problems:

1. **No local override path for non-interactive config.** If a machine needs a specific env var that services or automation must see (set in `.profile` or `.zshenv`), there is no designated place to put it. The only options are editing tracked repo files (polluting the repo) or hacking it into `.zshrc.local` (wrong lifecycle stage — services and non-interactive shells never see it).

2. **Installer scripts dirty the repo.** Tools like `cargo`, `bun`, `fnm`, `gcloud`, and others append PATH/env lines to `~/.profile` or `~/.zshenv` during installation. Since those are symlinks into the repo, the repo gets dirty with machine-specific junk that must be manually cleaned up every time.

## Decision

Add a `.local` sourcing hook to every tracked shell config file, following the same pattern already proven by `~/.zshrc.local`.

### Why this approach (and not the `.shared` stub alternative)

We evaluated an alternative where tracked files are renamed (e.g., `.profile.shared`) and the canonical paths (`~/.profile`, etc.) become untracked stubs that source the shared files. This was rejected because:

- **It breaks stow lifecycle management.** `stow -D shell` would remove `.profile.shared` but leave the untracked `.profile` stub behind, now sourcing a nonexistent file. Stow can no longer fully install or uninstall shell config.
- **It makes debugging harder.** Currently `~/.profile` is a symlink into the repo — `git diff` immediately shows any changes. With untracked stubs, the canonical path is invisible to git, and diagnosing issues requires inspecting two layers.
- **Machine state silently diverges.** Stubs accumulate untracked local additions over time. If a machine dies or a stub is corrupted, there is no record and no way to reconstruct it. Today, the repo IS the source of truth.
- **It solves a rare problem with permanent complexity.** Installer pollution happens a few times per machine setup. It is immediately visible via `git status` and takes seconds to fix. The stub architecture permanently changes the file layout, naming, stow workflow, and setup logic to avoid that occasional cleanup.

The `.local` approach:
- Adds one line per file — minimal change, minimal risk.
- Keeps stow fully in control of canonical paths.
- Keeps `git diff` and `git status` working as expected.
- Is already proven by `.zshrc.local`.
- Preserves one-liner machine setup (`./init.sh`).

## Design

### Pattern

Every tracked shell config file gets a sourcing hook at the end:

```
[if local file exists] → source it
```

The `.local` files are:
- **Untracked** — not in the repo, not stow-managed.
- **Machine-owned** — each machine can have different content or no file at all.
- **Optional** — if the file does not exist, nothing happens.
- **Same shell dialect** as the parent file (POSIX sh for `.profile.local`, zsh for `.zshrc.local`).

### Files affected

| Tracked file (stow symlink) | Local override file | Shell dialect | Lifecycle stage |
|---|---|---|---|
| `shell/.profile` | `~/.profile.local` | POSIX sh | Login shells, automation, services |
| `shell/.zshenv` | `~/.zshenv.local` | zsh | Every zsh invocation (including non-interactive) |
| `shell/.zprofile` | `~/.zprofile.local` | zsh | zsh login shells (before `.zshrc`) |
| `shell/.zshrc` | `~/.zshrc.local` | zsh | Interactive zsh only (already exists) |

### What goes where

Use this decision tree when adding machine-local config:

**Does it only matter for interactive shell ergonomics?**
→ `~/.zshrc.local` (aliases, prompt tweaks, completions, experiments)

**Must it be visible to services, automation, agents, or non-interactive shells?**
→ `~/.profile.local` (env vars, PATH additions, runtime config)

**Must it run in every zsh invocation, even non-interactive scripts?**
→ `~/.zshenv.local` (rare — only for env vars that zsh scripts need before `.profile` runs)

**Is it zsh-login-specific and not covered by `.profile.local`?**
→ `~/.zprofile.local` (very rare — macOS-specific login setup, for example)

### Installer pollution workflow

When an installer appends lines to `~/.profile` (following the symlink):

1. `git status` shows `shell/.profile` modified.
2. Inspect the diff: `git diff shell/.profile`.
3. Move the installer-added lines to `~/.profile.local`.
4. Restore the tracked file: `git checkout shell/.profile`.

This is a one-time task per tool per machine. The `.local` file is the correct permanent home for those additions.

---

## Prerequisites

None. This plan requires no new tooling, no dependency changes, and no stow modifications.

---

## Implementation: file-by-file changes

### 1. `shell/.profile`

**Current state (line 42, end of file):**
```sh
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
```

**Add after the last line:**
```sh
[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"
```

**Rationale:** `.profile.local` runs after all shared PATH setup and the final `~/.local/bin/env` precedence assertion. This means local additions can rely on the full shared environment being in place. If `.profile.local` needs to prepend PATH entries that should win over `~/.local/bin`, it can re-source `~/.local/bin/env` at the end — same pattern already used in `.zshrc.local` on this machine.

### 2. `shell/.zshenv`

**Current state (line 4, end of file):**
```sh
. "$HOME/.cargo/env"
```

**Add after the last line:**
```zsh
[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
```

**Rationale:** `.zshenv` runs on every zsh invocation (interactive, non-interactive, login, non-login). Local overrides here affect everything. This is intentionally last so local settings can override shared XDG and cargo env if needed. Use sparingly — most machine-local env belongs in `.profile.local` instead.

### 3. `shell/.zprofile`

**Current state (line 9, end of file):**
```sh
[[ -r "$HOME/.profile" ]] && . "$HOME/.profile"
```

**Add after the last line:**
```zsh
[[ -f "$HOME/.zprofile.local" ]] && source "$HOME/.zprofile.local"
```

**Rationale:** Runs after `.profile` has been sourced, so local additions can see the full login environment. In practice, `.profile.local` covers most login-time needs. `.zprofile.local` exists for completeness and for the rare case where a zsh-specific login override is needed (e.g., macOS-only Homebrew config on one machine but not another).

### 4. `shell/.zshrc`

**Current state (line 23):**
```zsh
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

**No change.** Already implements the pattern. The existing `.zshrc.local` files on all machines continue to work unchanged.

---

## Implementation: setup/template changes

### 5. `setup/lib.sh` — extend `write_local_overrides_template()`

**Current behavior:** Generates and manages `~/.zshrc.local` templates only.

**New behavior:** Additionally generate `~/.profile.local` and `~/.zshenv.local` scaffolds on first run (if they do not already exist). Do not overwrite existing files. Do not use the managed-template-detection logic for these new files — keep them simple.

**`~/.profile.local` scaffold:**
```sh
# Machine-local login environment.
# This file is sourced by ~/.profile after all shared config.
# It is not tracked by the dotfiles repo.
#
# Use for:
# - machine-specific PATH additions that services/automation must see
# - env vars needed outside interactive shells
# - lines moved here from ~/.profile after installer scripts modify it
#
# Shell dialect: POSIX sh (not zsh)
```

**`~/.zshenv.local` scaffold:**
```zsh
# Machine-local zsh environment.
# This file is sourced by ~/.zshenv on every zsh invocation.
# It is not tracked by the dotfiles repo.
#
# Use sparingly — most machine-local config belongs in:
# - ~/.profile.local (login/service env)
# - ~/.zshrc.local (interactive shell)
#
# Only put things here that must be set in non-interactive zsh
# scripts before .profile runs.
```

**`.zprofile.local` does not need a scaffold** — it is a rare edge case. If someone needs it, they create it manually.

### 6. `shell/.zshrc.local.example`

**Update** the header comment to mention the broader local override model:

```sh
# Machine-local interactive shell overrides live here.
# This file is user-owned. Keep host-specific settings here instead of tracked
# dotfiles, and compare against ~/.config/zsh/local.example.zsh after running
# ./init.sh to review the latest template changes safely.
#
# Good candidates:
# - prompt/tmux accent
# - host-specific aliases or completions
# - laptop-only checks
#
# For env vars that services/automation must see, use ~/.profile.local instead.
# For a full overview, see docs/local-overrides.md.
```

---

## Implementation: documentation update

### 7. `docs/local-overrides.md`

Update the layer model section to reflect the expanded local override mechanism. The key changes:

**Replace** the current "Machine-local overrides" section (which only mentions `~/.zshrc.local`) with:

```markdown
## Machine-local overrides

These files live outside the repo and are specific to one machine. They are not tracked, not stow-managed, and optional (if absent, nothing happens).

| File | Sourced by | Lifecycle | Use for |
|---|---|---|---|
| `~/.profile.local` | `~/.profile` | Login shells, services, automation | Machine-specific PATH, env vars that must be visible everywhere |
| `~/.zshenv.local` | `~/.zshenv` | Every zsh invocation | Rare — env vars needed in non-interactive zsh scripts |
| `~/.zprofile.local` | `~/.zprofile` | zsh login shells | Rare — zsh-specific login overrides not covered by .profile.local |
| `~/.zshrc.local` | `~/.zshrc` | Interactive zsh | Aliases, prompt tweaks, completions, experiments |
```

**Add** the installer pollution workflow (as described above) as a subsection.

**Keep** the existing `~/.local/bin` contract and PATH ownership sections unchanged — they are complementary to this work, not replaced by it.

---

## Implementation: existing local file migration

### 8. Audit `~/.zshrc.local` on each machine

Some content currently in `~/.zshrc.local` may belong in `~/.profile.local` instead. After implementing the new hooks, review each machine's `.zshrc.local` and move anything that needs to be visible to services/automation.

**Example from the current linux-headless `~/.zshrc.local`:**

```zsh
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
```

These env vars are needed by systemd user services, not just interactive shells. They should move to `~/.profile.local`.

Similarly, the Homebrew re-evaluation block:

```zsh
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew && -z "${HOMEBREW_PREFIX:-}" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
    [[ -r "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
fi
```

This is a POSIX-safe operation that should run at login time for all contexts, not just interactive zsh. It should move to `~/.profile.local` (adapted to POSIX sh syntax).

**This is a per-machine task, not a repo change.** Each machine's `.zshrc.local` and new `.profile.local` are untracked.

---

## Implementation: cleanup of redundant PATH sourcing

### 9. Reduce redundant `~/.local/bin/env` sourcing (optional, separate PR)

This is not required for the local override work but is the natural follow-up. Currently `~/.local/bin/env` is sourced in four places:

1. `shell/.profile` (line 2, line 41)
2. `shell/.zsh/languages.zsh` (line 25)
3. `shell/.zsh/tools.zsh` (line 12)

The double-source in `.profile` (lines 2 and 41) is intentional: once early for baseline, once at the end to reassert after toolchain PATH mutations. The sources in `languages.zsh` and `tools.zsh` serve the same "reassert after mutation" purpose for interactive zsh.

This is functional but noisy. A future cleanup could:
- Remove the line-2 early source in `.profile` (the line-41 final source is sufficient).
- Remove the `tools.zsh` source (it runs after `languages.zsh` which already reasserts).
- Keep `languages.zsh` line 25 (reasserts after fnm/bun/pnpm mutations).
- Keep `.profile` line 41 (reasserts after brew/fnm/pnpm/bun mutations).

**Do not combine this with the local override work.** These are independent changes and should be validated separately.

### 10. Reduce redundant `~/.local/bin` prepending in `env.zsh` (optional, separate PR)

`shell/.zsh/env.zsh` line 4 unconditionally prepends `~/.local/bin` to PATH:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

This duplicates what `~/.local/bin/env` does more carefully (with dedup). Since `languages.zsh` runs after `env.zsh` and ends by sourcing `~/.local/bin/env`, this raw prepend is redundant and contributes to duplicate PATH entries.

It could be removed, leaving `~/.local/bin/env` as the sole owner of that responsibility. But validate on all machines first — if any context sources `env.zsh` without later sourcing `languages.zsh`, removing it would break PATH.

**Do not combine this with the local override work.**

---

## What this plan does NOT change

- **Stow setup** — no changes to stow packages, no renames, no new packages.
- **`~/.local/bin` contract** — unchanged, still the stable command layer.
- **`~/.local/bin/env`** — unchanged, still the PATH normalization snippet.
- **Profile system** — `./init.sh` profiles work exactly as before.
- **`.secrets`** — unchanged, still git-crypt managed.
- **Systemd service PATH** — unchanged, services still declare explicit PATH.
- **One-liner install** — `./init.sh` still sets up a complete machine.

## Execution order

1. Add sourcing hooks to `shell/.profile`, `shell/.zshenv`, `shell/.zprofile` (steps 1–3).
2. Update `shell/.zshrc.local.example` header (step 6).
3. Update `docs/local-overrides.md` (step 7).
4. Update `setup/lib.sh` to scaffold `.profile.local` and `.zshenv.local` (step 5).
5. On each machine: audit `.zshrc.local` and move misplaced config to `.profile.local` (step 8).
6. Optionally: clean up redundant PATH sourcing in a separate PR (steps 9–10).

Steps 1–4 are a single commit in the dotfiles repo.
Step 5 is machine-local and untracked.
Steps 9–10 are independent follow-ups.

---

## Verification

After implementing steps 1–4, verify on each machine:

```sh
# Repo is clean
git -C ~/dotfiles status

# Shared shell config still works
zsh -l -c 'echo $PATH' | tr : '\n' | head -5   # ~/.local/bin should be first

# .profile.local is sourced in login context
echo 'export __PROFILE_LOCAL_TEST=1' >> ~/.profile.local
zsh -l -c 'echo $__PROFILE_LOCAL_TEST'           # should print 1
sed -i '/^export __PROFILE_LOCAL_TEST/d' ~/.profile.local

# .zshenv.local is sourced in non-interactive context
echo 'export __ZSHENV_LOCAL_TEST=1' >> ~/.zshenv.local
zsh -c 'echo $__ZSHENV_LOCAL_TEST'               # should print 1
sed -i '/^export __ZSHENV_LOCAL_TEST/d' ~/.zshenv.local

# Existing .zshrc.local still works
zsh -i -c 'echo $HAL_THEME_COLOR'                # should print machine color
```
