# Usage

Fresh clone:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./dotfiles.sh install macos
```

Explicit profile selection:

- `./dotfiles.sh` is the only root management entrypoint.
- Files under `setup/` are support scripts, not alternate install entrypoints.
- `install` and `verify` never auto-detect a profile.
- Running `./dotfiles.sh` with no command prints the command map and profiles.
- Pick the exact target you want: `minimal`, `full`, `macos`, or `linux-desktop`.

Typical first-run examples:

```bash
./dotfiles.sh install macos
./dotfiles.sh install linux-desktop
```

Common maintenance:

```bash
./dotfiles.sh refresh
./dotfiles.sh refresh linux-desktop
./dotfiles.sh agents sync
./dotfiles.sh agents status
./dotfiles.sh agents verify
./dotfiles.sh verify macos
./dotfiles.sh stow shell nvim
./dotfiles.sh install full --dry-run
./dotfiles.sh install linux-desktop --yes --allow-partial
DOTFILES_ALLOW_PARTIAL=1 ./dotfiles.sh install linux-desktop --yes
./setup/brew-drift
```

Command boundaries:

- `install <profile>` is the only command that invokes package or runtime installers. We cannot prove every third-party installer is idempotent, so a real install says so and asks before starting. Use `--yes` for unattended execution. `--no-input` refuses to prompt and therefore also requires `--yes` unless this is a dry run.
- `refresh [profile]` applies repo-managed configuration without installers. It defaults to the additive `full` profile; name `macos` or `linux-desktop` when platform configuration belongs in the repair.
- `stow <package>...` applies only the named Stow packages and accepts several packages in one call.
- `agents sync` exclusively refreshes global skills and agent instructions. `agents status` and `agents verify` are read-only.
- `verify <profile>` is read-only and checks the profile plus the global agent surface.
- `-n` or `--dry-run` prints planned mutating work without changing the machine. An install dry run never prompts or acquires sudo.
- `--allow-partial` is the install-only CLI equivalent of `DOTFILES_ALLOW_PARTIAL=1`; use it when you intentionally want Linux installation to continue without privileged apt/system steps.

`./dotfiles.sh refresh` is the normal repair command for repo-managed state. It restows the profile packages, repairs the global agent surface, refreshes local templates, and refreshes stable command entrypoints without running package or runtime installers.

For unattended Linux installation, pre-authenticate with `sudo -v` and pass `--yes`. If you intentionally want a rootless pass that skips apt/system setup, make that explicit with `--allow-partial` or `DOTFILES_ALLOW_PARTIAL=1`.

Scope:

- This page documents how to operate the dotfiles repo itself: bootstrap, verify, stow, local overrides, and repo-managed customization points.
- It does not document general usage of installed tools such as tmux, Neovim, `wt`, or other bundled CLIs.

Machine-specific accent color (prompt + tmux):

```bash
# ~/.zshrc.local
export THEME_COLOR="blue"     # system default
# export THEME_COLOR="red"     # alternate palette
# export THEME_COLOR="green"   # alternate palette
# export THEME_COLOR="purple"  # alternate palette
# export THEME_COLOR="yellow"  # alternate palette
# export THEME_COLOR="orange"  # alternate palette
# export THEME_COLOR="teal"    # alternate palette

source ~/.zshrc
tmux source-file ~/.tmux.conf
```

`THEME_COLOR` is normalized through one shared palette map, so prompt, tmux, and tmux helper UIs all stay in sync. Profile-wide `install` and `refresh` operations update `~/.config/zsh/local.example.zsh` so you can diff the latest template guidance without overwriting a customized `~/.zshrc.local`.

Setup-written `~/.zshrc.local` files start with a `# dotfiles-managed: profile=... sha256=...` marker line hashing the rest of the file. While that hash still matches, the file counts as untouched and setup refreshes it in place (with a timestamped backup) when the template or profile changes. Any edit you make breaks the hash, and setup then preserves the file forever; keep or delete the marker line as you like.

Machine-local runtime env and PATH overrides belong in `~/.profile.local`. Use `~/.zshrc.local` only for interactive shell behavior.

Shell bootstrap verification:

```bash
env -i HOME="$HOME" USER="$USER" SHELL=/bin/zsh PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  zsh -lc 'command -v git nvim ngrok cloudflared delta trufflehog fnm node pnpm cargo bun tree-sitter claude codex psql typescript-language-server'
```

Stable non-login command contract verification:

```bash
env -i HOME="$HOME" USER="$USER" PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  sh -lc 'command -v git nvim ngrok cloudflared delta trufflehog fnm node pnpm cargo bun tree-sitter claude codex psql typescript-language-server wt'
```

Use the login-shell check to confirm shared bootstrap does not depend on interactive `~/.zshrc` state. Use the non-login check to confirm agents and scripts can resolve the same commands through the stable `~/.local/bin` contract.

The full profile also installs the isolated `claudex` harness and its localhost CLIProxyAPI runtime. Each machine requires one Codex OAuth login after setup; see `docs/claudex.md` for the command and isolation contract.

On macOS, setup loads Homebrew's `shellenv` into its own process immediately after a first install, so the same run can apply Brewfiles on either Apple Silicon (`/opt/homebrew`) or Intel (`/usr/local`). Login shells retain that behavior through `~/.zprofile`.

## Agent skills and instructions

Global agent skills and instructions live under `agents/` and are linked into `~/.claude` and `~/.codex` by the minimal layer (`setup/agents.sh`).

Set up or repair the machine-level agent surface with setup:

```bash
./dotfiles.sh agents sync
```

This mode runs only the repo-managed agent work: flat per-skill links under
`~/.claude/skills/` and `~/.codex/skills/`, composed
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` files, and generated Codex skill
policy. It does not install packages, restow dotfiles, refresh local shell
templates, or update stable command entrypoints. The global instruction files
are composed from primary `agents/SHARED.global.md` content followed by
`agents/CLAUDE.global.md` or `agents/AGENTS.global.md`. On a fresh machine that
still needs packages, run the normal explicit profile instead.

Optional machine instructions live in the Git-ignored `agents/.local/`
directory. Use `SHARED.md` for both harnesses, `AGENTS.md` for Codex, and
`CLAUDE.md` for Claude. Setup appends shared local rules and then harness-local
rules after the tracked global files. Run `./dotfiles.sh agents sync` after adding,
changing, or removing an overlay. Start from one of the tracked files under
`agents/templates/local-instructions/`; copy only the shared or harness-specific
file the machine needs.

```bash
mkdir -p agents/.local
cp agents/templates/local-instructions/SHARED.md agents/.local/SHARED.md
$EDITOR agents/.local/SHARED.md
./dotfiles.sh agents sync
./dotfiles.sh agents verify
```

The local files are additive machine facts and rules, not a second copy of the
tracked instructions. Promote a rule to `SHARED.global.md`, `AGENTS.global.md`,
or `CLAUDE.global.md` when it should follow the repository to every machine.
See `agents/README.md` for the full source matrix and composition order.

Day-to-day invocation-mode work goes through `skillctl`:

```bash
agents/skillctl list                    # effective Claude + Codex invocation modes
agents/skillctl disable-model <skill> codex
agents/skillctl enable-model <skill> claude
agents/skillctl disable-model <skill>   # omit harness to change both
agents/skillctl off <skill>             # hide a skill from every harness (git keeps it)
agents/skillctl sync                    # regenerate Codex yaml + symlinks only; idempotent
agents/skillctl verify                  # read-only generated Codex policy/link check
agents/skilltokens                      # exact token budget report for global skills
agents/skilltokens --harness codex      # report Codex's effective context load
agents/skillpull list                   # show remote/local provenance for skills
agents/skillpull check --all            # read-only upstream drift audit
agents/instructionctl status            # show instruction sources and generated state
agents/instructionctl verify            # focused composed-instruction check
```

Invariants: `setup/agents.sh` is the machine-level owner for global agent links and composed instruction files; direct `agents/skillctl sync` is not a substitute for setup because it does not create Claude per-skill links or compose top-level harness instructions; `agents/SHARED.global.md` is the primary tracked source for cross-harness rules, while `agents/AGENTS.global.md` and `agents/CLAUDE.global.md` contain only tracked harness-specific additions; Git-ignored files under `agents/.local/` are optional machine-specific overlays; active global skills live in the flat `agents/skills/<name>` namespace; candidates under `agents/in-progress/<name>` are not installed; SKILL.md frontmatter is the single source of truth for per-harness invocation mode; Claude reads `disable-model-invocation`, while `disable-codex-model-invocation` optionally overrides the generated Codex policy; `agents/openai.yaml` policy blocks and flat `~/.codex/skills/<name>` symlinks are generated by `sync` and never hand-edited; root-level user or third-party skills can coexist, and same-name conflicts are skipped with a warning rather than overwritten; `agents/skill-sources.toml` is the single source of truth for active and in-progress global skill provenance and upstream drift checks; repo-specific skills live in each repo's `.agents/skills/`, not here. Details: `agents/README.md`.

## Architecture handling

Both x86_64 and arm64/aarch64 Linux machines are supported. Architecture is detected automatically via `uname -m` at startup. GitHub release binaries such as `fzf`, `sesh`, `gum`, `lazygit`, `yazi`, and `lsd`, plus Go, use architecture-specific download URLs. No manual configuration is needed.

## One-hit runtime guarantees

After a successful `./dotfiles.sh install <profile>` run, all required commands for the active profile are verified in two ways: from a clean login shell and from a non-login shell with `~/.local/bin` plus the base system PATH only. If any required tool is missing in either view, installation exits with a hard error. This keeps human shells and agent/script entrypoints aligned.
