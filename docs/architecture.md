# Architecture

The repository is split into three categories:

1. Stow packages under top-level package directories such as `shell/`, `git/`, `nvim/`, and `linux-desktop/`.
2. Setup logic under `setup/`, driven by `init.sh`.
3. Documentation under `docs/`.

`init.sh` resolves a profile, expands it into an additive layer chain, installs the required packages for each layer, backs up first-run conflicts, and stows the corresponding packages with `stow --no-folding`.

Profiles are additive:

```text
minimal
  -> full
     -> macos
     -> linux-headless
        -> linux-desktop
```

Shell startup is split by responsibility:

- `shell/.profile` owns runtime-critical, POSIX-safe PATH/bootstrap needed by login and non-interactive shells.
- `shell/.zprofile` handles zsh login-shell setup and sources `~/.profile`.
- `shell/.zshrc` owns interactive zsh behavior and delegates to focused files under `shell/.zsh/`.

Machine-specific behavior belongs in `~/.zshrc.local`. `./init.sh` refreshes the latest reference template into `~/.config/zsh/local.example.zsh` and only rewrites `~/.zshrc.local` when it still exactly matches a managed template.

For the full contract on machine-local shell tweaks vs automation-visible command overrides, see `docs/local-overrides.md`.
