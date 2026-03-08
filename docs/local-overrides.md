# Local Overrides Contract

This document defines where machine-specific behavior should live, where user-level executable overrides belong, and how shared shell startup should treat them.

## Goals

- Keep the dotfiles repo cross-machine and mostly declarative.
- Make machine-specific tweaks explicit instead of ad hoc.
- Give both humans and agents one stable contract for "what command should I run?"
- Avoid interactive-shell-only fixes that break in services, automation, or remote/headless sessions.

## Layer model

There are three different concerns:

1. **Repository-managed shared config**
   - Lives in stowed packages such as `shell/`, `git/`, `nvim/`, `wt/`, etc.
   - Must stay portable across supported machines.

2. **Machine-local overrides**
   - Lives outside the managed repo when it is specific to one host or one person's local state.
   - Primary shell-local file: `~/.zshrc.local`
   - Use for host-specific aliases, secrets references, prompt tweaks, experiments, or one-off shell ergonomics.

3. **Stable user-level command layer**
   - Lives in `~/.local/bin`
   - This is the canonical place for user-installed binaries, stable wrappers, and executable overrides that must work in:
     - interactive shells
     - login shells
     - non-interactive shells
     - systemd user services
     - automation / agents / OpenClaw / scripts

## Rule of thumb

- If it only matters to your interactive shell experience, `~/.zshrc.local` is fine.
- If it must work for automation, agents, or services, expose it as a real executable in `~/.local/bin`.
- Do not rely on aliases or shell functions as infrastructure.

## `~/.local/bin` contract

Treat `~/.local/bin` as the **public per-user command contract**.

That means:
- commands here should be safe to call from any runtime
- wrappers here may normalize environment, source implementation files, or redirect to language-managed installs
- the path name in `~/.local/bin` is the stable interface; underlying implementation may live elsewhere

Examples:
- `~/.local/bin/wt` can source `~/.wt/wt.sh` and expose `wt` as a real command
- `~/.local/bin/qmd` can delegate to the actual qmd install and normalize runtime behavior

This is preferred over:
- aliases in `.zshrc`
- shell functions only available interactively
- patching language-manager-owned shims directly

## PATH ownership

`~/.local/bin` should win PATH precedence.

Why:
- it is the local override layer
- it provides stable entrypoints independent of fnm/pnpm/bun/other toolchain shims
- it keeps service/runtime behavior aligned with human shell behavior

Current pattern:
- `~/.local/bin/env` is a shared PATH-normalization snippet
- startup files may source it to reassert `~/.local/bin` after toolchains mutate PATH
- services that need deterministic command resolution should also put `~/.local/bin` first in their explicit PATH

`~/.local/bin/env` is **not** a shell primitive. It only applies where startup files explicitly source it.

## What belongs in `~/.zshrc.local`

Use `~/.zshrc.local` for things like:
- host-specific aliases
- local prompt/theme tweaks
- temporary experiments
- machine-only environment variables
- interactive helpers that do not need to work in automation

Do **not** use it as the primary place to make automation-visible commands available.

## What belongs in repo-managed shell files

Use repo-managed shell files for:
- shared startup structure
- portable PATH/bootstrap rules
- cross-machine toolchain initialization
- reapplication of the `~/.local/bin` precedence contract

Do not hardcode one-machine hacks into shared shell files unless they are part of an intentional documented contract.

## Design principle

Separate:
- **implementation location** from
- **public command name**

The implementation may live in:
- `~/.wt/wt.sh`
- fnm-managed Node installs
- pnpm-managed launchers
- tool-specific state directories

But if the command is expected to be generally runnable, the stable entrypoint should live in:
- `~/.local/bin/<name>`

That keeps the system understandable and prevents per-tool ad hoc fixes later.
