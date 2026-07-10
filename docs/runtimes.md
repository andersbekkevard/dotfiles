# Runtimes

- Neovim: >= 0.11 required. Homebrew on macOS; GitHub release tarball on Linux (`~/.local/share/nvim-install`, symlinked from `~/.local/bin/nvim`). Distro packages are not used as most ship < 0.11. Supports x86_64 and arm64.
- fzf: Homebrew on macOS; latest upstream GitHub release tarball on Linux, installed to `~/.local/bin/fzf` on every normal bootstrap run. Distro packages are not used on Linux because they can lag the key-binding surface used by tmux helpers.
- Tree-sitter CLI: `tree-sitter` is required for full-profile Neovim parser updates. The bootstrap installs it with `cargo install tree-sitter-cli --locked` because current `nvim-treesitter` shells out to `tree-sitter build`, and older distro packages can lag that command surface.
- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- Codex CLI: global `@openai/codex` package installed with `pnpm` after Node.js
- TypeScript LSP: global `typescript` plus `typescript-language-server` for Neovim `ts_ls`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux
- PostgreSQL client: Homebrew `libpq` on macOS, `postgresql-client` on Linux. On macOS, `setup.sh` exposes Homebrew's keg-only `psql` through `~/.local/bin/psql` for Dadbod and non-interactive command resolution.

Why these choices:

- Neovim >= 0.11 is the minimum floor because the Lua plugin ecosystem and built-in LSP client require it.
- `nvim-treesitter` now shells out to the external `tree-sitter` binary for parser builds, and the distro `tree-sitter-cli` package can be too old to support `tree-sitter build`. Installing from Cargo keeps the CLI compatible with the plugin.
- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- TypeScript buffers rely on an external language server binary; the full-profile runtime bootstrap installs both `typescript` and `typescript-language-server` after the Node toolchain is available.
- SQL buffers that use Dadbod against PostgreSQL require the external `psql` client, so the full profile installs and verifies it.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- All Linux binary downloads are architecture-aware (x86_64 and arm64/aarch64).
- `fnm` node stack is hardened: PATH is re-evaluated after install, pnpm falls back to `npm install -g pnpm` if corepack is unavailable, and the configured pnpm global bin directory is exported into the active bootstrap PATH before global tools are installed.
- pnpm has one OS-aware global-bin contract shared by setup and shell startup: `~/Library/pnpm` on macOS and `~/.local/share/pnpm` elsewhere. Setup configures pnpm to that location, then exposes installed globals in the active run and future login shells.
- The full layer installs the Codex CLI only after Node.js and pnpm are available; npm is the fallback when pnpm is unavailable. This makes `codex login` part of the verified `full`, `macos`, and `linux-desktop` machine contracts.
- Runtime-critical PATH/bootstrap for `fnm`, `node`, `pnpm`, `bun`, Go user binaries, repo scripts, and related CLI entrypoints lives in `shell/.profile`. The shared pnpm default is defined once in `shell/.local/lib/dotfiles/runtime-paths.sh` and consumed by both setup and shell startup. zsh login shells inherit that through `shell/.zprofile`, and interactive non-login zsh shells backfill by sourcing `~/.profile` from `shell/.zshrc` when needed. When an upstream command is a launcher script that depends on its own `$0`, the stable `~/.local/bin` entrypoint targets a generated exec wrapper rather than symlinking that launcher directly.
- Interactive-only hooks such as `fnm --use-on-cd`, completions, and prompt/theme behavior stay in `shell/.zshrc`.
- `./setup.sh` refreshes `~/.local/bin` symlinks for commands that resolve outside the base system PATH so agents and non-login shells can rely on the same stable command layer.
- The runtime contract is explicit-profile only: `./setup.sh` installs the profile you name and does not auto-select one from the environment.
- Interactive zsh shells reject project-level `npm install` / `npm i` loudly; use `pnpm install` or `pnpm add` instead. Global installs via `npm ... -g` are allowed, though `pnpm add -g` remains the preferred default. The bootstrap may still invoke raw `npm install -g pnpm` internally as a non-interactive fallback when `corepack` is unavailable.
