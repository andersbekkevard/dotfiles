# Architecture

The repository is split into three categories:

1. Stow packages under top-level package directories such as `shell/`, `git/`, `nvim/`, `tmux/`, `terminals/`, `wt/`, and `linux-desktop/`. A package may materialize more than one target subtree under `$HOME`; for example, the `scripts/` package owns both interactive helper files under `~/.scripts/` and stable executable entrypoints under `~/.local/bin/`.
2. Setup logic under `setup/`, with library modules in `setup/lib/` (core, profiles, packages, runtimes, shell-setup, stow, state, verify), driven by the root `dotfiles.sh` entrypoint.
3. Documentation under `docs/`.
4. The global agent surface under `agents/` contains canonical active skills in the flat `agents/skills/<name>` namespace, candidates under `agents/in-progress/<name>` or `agents/in-progress/<collection>/<name>`, and retired skills under `agents/archive/<name>`. Collection directories under `in-progress/` contain no `SKILL.md` and exist only to organize related experiments. The surface also contains primary shared global instructions in `agents/SHARED.global.md`, harness additions in `agents/AGENTS.global.md` and `agents/CLAUDE.global.md`, and optional Git-ignored machine overlays under `agents/.local/`. This is not a stow package. `setup/agents.sh` owns machine-level wiring, composes tracked shared and harness instructions followed by local shared and harness overlays into `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`, and projects only active skills as flat per-skill symlinks for both harnesses. `agents/instructionctl` inspects and verifies those composed files without writing them. The `skillctl sync` call inside setup refreshes Codex links without touching Codex-managed entries such as `.system/`. Existing same-name skills are not overwritten. See `agents/README.md`.
5. Retired configs and scripts under `archive/`.

The `claudex` integration follows the same tracked/runtime split: `scripts/.local/bin/claudex` and `claudex-proxy` are portable stowed commands; setup installs the versioned CLIProxyAPI binary. The generated proxy configuration, local API key, OAuth credentials, PID, and logs are machine state and never live in the repository. The proxy binds to `127.0.0.1`, and only the `claudex` process receives its endpoint and token.

`dotfiles.sh install` requires an explicit profile, expands it into an additive
layer chain, fills missing prerequisites without upgrading working providers,
and applies the corresponding Stow packages. `update` traverses the same chain
but enables explicit upgrades for owned package/runtime providers. Successful
install and update runs atomically record resolved command paths, provider
classes, and safe version output under the XDG state directory. `refresh`
traverses the profile chain with installers disabled and has a fixed `full`
default. `agents
sync` calls only `ensure_agent_surface`, so it refreshes global skills and
instructions without running a profile layer, restowing dotfiles, refreshing
shell templates, or updating command entrypoints. `stow`, `agents status`,
`agents verify`, and `verify` expose focused maintenance and read-only paths.

Operator entrypoint rule:

- `./dotfiles.sh` is the only root management command.
- Files under `setup/` are implementation details, manifests, or maintenance helpers.
- The repo does not offer a second install entrypoint or an implicit auto-profile mode.
- `install` is missing-only, `update` owns version movement, and `refresh` is installer-free.

Profiles are additive:

```text
minimal
  -> full
     -> macos
     -> linux-desktop
```

The minimal layer installs TruffleHog before linking the global agent surface,
so the exported `autoreview` skill does not start with a missing hard
dependency. macOS gets it from `Brewfile.minimal`; Linux gets the
architecture-matched upstream release through
`linux-binaries.minimal.txt`.

Global instruction ownership is a two-axis matrix. Storage selects tracked or
machine-local policy; the file name selects shared, Codex-only, or Claude-only
policy. Setup is the compiler for this matrix. Generated files in the home
directory are outputs, while `agents/instructionctl verify` checks that they
match their sources. Machine-local sources remain absent until a machine needs
one and never require a tracked placeholder.

## Installation ordering

Each layer script is a dependency-ordered sequence — every line assumes lines above it succeeded. On a blank machine, only base OS packages exist when `dotfiles.sh install` starts.

Rules:
- Steps that download (`curl`, `wget`) must come after those tools are installed via the package manager.
- Steps that add external apt repos must come after `curl` is available and before packages from that repo are requested.
- `apt_update_once` is flag-guarded; any repo added after the first call needs its own `apt-get update`.
- External apt source lines must include `[signed-by=...]` or apt will reject the repo's GPG signature.

When changing layer scripts or package manifests, trace the full sequence on a blank machine and confirm every tool each line uses is already installed by a previous line.

## Shell startup

Shell startup is split by responsibility:

- `shell/.profile` owns runtime-critical, POSIX-safe PATH/bootstrap and is the single shared owner of baseline PATH assembly.
- `shell/.local/lib/dotfiles/runtime-paths.sh` owns the OS-aware pnpm global-bin default consumed by setup and `~/.profile`.
- `shell/.zprofile` handles zsh login-shell setup and sources `~/.profile`.
- `shell/.zshrc` owns interactive zsh behavior, backfills `~/.profile` for interactive non-login zsh when needed, and delegates to focused files under `shell/.zsh/`.
- `shell/.zshenv` is kept minimal for zsh-wide XDG defaults only.

Machine-specific runtime behavior belongs in `~/.profile.local`; interactive-only shell behavior belongs in `~/.zshrc.local`. Profile-wide `install` and `refresh` operations update the latest reference template in `~/.config/zsh/local.example.zsh` and only rewrite `~/.zshrc.local` when it still exactly matches a managed template.

For the full contract on machine-local shell tweaks vs automation-visible command overrides, see `docs/local-overrides.md`.

## XDG Base Directory Specification

This repo follows the [XDG Base Directory Specification](https://xdgbasedirectoryspecification.com/) on a best-effort basis.

**What we do:**

- Export `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME` with spec-correct defaults in `shell/.zshenv`.
- Place tool configs under `~/.config/` via stow (nvim, git ignore, terminals, btop, lsd, lazygit, fd, wt, etc.).
- Place shared data under `~/.local/share/` where tools support it (rofi themes, fnm, pnpm).

**Known deviations:**

| Item | Current location | XDG-correct location | Reason |
|---|---|---|---|
| zsh dotfiles (`.zshrc`, `.zshenv`, …) | `$HOME` | `$XDG_CONFIG_HOME/zsh/` via `ZDOTDIR` | zsh reads `~/.zshenv` before `ZDOTDIR` is set; bootstrapping `ZDOTDIR` requires `/etc/zsh/zshenv` which we don't own on all hosts |
| `.gitconfig` | `$HOME/.gitconfig` | `$XDG_CONFIG_HOME/git/config` | git supports XDG; migration planned |
| `.tmux.conf` | `$HOME/.tmux.conf` | `$XDG_CONFIG_HOME/tmux/tmux.conf` | tmux supports XDG since v3.1; migration planned |
| `HISTFILE` | `$HOME/.zsh_history` | `$XDG_STATE_HOME/zsh/history` | `XDG_STATE_HOME` not yet exported |
| `.oh-my-zsh` | `$HOME/.oh-my-zsh` | — | upstream default, no XDG support |
| `.bun` | `$HOME/.bun` | — | upstream default, no XDG support |
| `.cargo` | `$HOME/.cargo` | — | upstream default (`CARGO_HOME` exists but breaks toolchain assumptions) |

**Policy:** when adding a new tool, prefer its XDG-compliant config path if the tool supports one. Only fall back to `$HOME`-root dotfiles when the tool has no XDG support or when the migration cost outweighs the benefit.
