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

Shared shell startup is orchestrated by `shell/.zshrc`, which delegates to focused files under `shell/.zsh/`. Machine-specific behavior belongs in `~/.zshrc.local`. `./init.sh` refreshes the latest reference template into `~/.config/zsh/local.example.zsh` and only rewrites `~/.zshrc.local` when it still exactly matches a managed template.
