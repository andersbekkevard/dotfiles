# Architecture

The repository is split into three categories:

1. Stow packages under top-level package directories such as `shell/`, `git/`, `nvim/`, and `linux-desktop/`.
2. Setup logic under `setup/`, with library modules in `setup/lib/` (core, profiles, packages, runtimes, shell-setup, stow, verify), driven by `setup.sh`.
3. Documentation under `docs/`.
4. Retired configs and scripts under `archive/`.

`setup.sh` requires an explicit profile, expands it into an additive layer chain, installs the required packages for each layer, backs up first-run conflicts, and stows the corresponding packages with `stow --no-folding`.

Operator entrypoint rule:

- `./setup.sh` is the only root bootstrap command.
- Files under `setup/` are implementation details, manifests, or maintenance helpers.
- The repo does not offer a second install entrypoint or an implicit auto-profile mode.

Profiles are additive:

```text
minimal
  -> full
     -> macos
     -> linux-desktop
```

## Installation ordering

Each layer script is a dependency-ordered sequence — every line assumes lines above it succeeded. On a blank machine, only base OS packages exist when `setup.sh` starts.

Rules:
- Steps that download (`curl`, `wget`) must come after those tools are installed via the package manager.
- Steps that add external apt repos must come after `curl` is available and before packages from that repo are requested.
- `apt_update_once` is flag-guarded; any repo added after the first call needs its own `apt-get update`.
- External apt source lines must include `[signed-by=...]` or apt will reject the repo's GPG signature.

When changing layer scripts or package manifests, trace the full sequence on a blank machine and confirm every tool each line uses is already installed by a previous line.

## Shell startup

Shell startup is split by responsibility:

- `shell/.profile` owns runtime-critical, POSIX-safe PATH/bootstrap and is the single shared owner of baseline PATH assembly.
- `shell/.zprofile` handles zsh login-shell setup and sources `~/.profile`.
- `shell/.zshrc` owns interactive zsh behavior, backfills `~/.profile` for interactive non-login zsh when needed, and delegates to focused files under `shell/.zsh/`.
- `shell/.zshenv` is kept minimal for zsh-wide XDG defaults only.

Machine-specific runtime behavior belongs in `~/.profile.local`; interactive-only shell behavior belongs in `~/.zshrc.local`. `./setup.sh` refreshes the latest reference template into `~/.config/zsh/local.example.zsh` and only rewrites `~/.zshrc.local` when it still exactly matches a managed template.

For the full contract on machine-local shell tweaks vs automation-visible command overrides, see `docs/local-overrides.md`.
