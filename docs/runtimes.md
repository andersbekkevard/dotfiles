# Runtimes

- Neovim: >= 0.11 required. Homebrew on macOS; GitHub release tarball on Linux (`~/.local/share/nvim-install`, symlinked from `~/.local/bin/nvim`). Distro packages are not used as most ship < 0.11. Supports x86_64 and arm64.
- Tree-sitter CLI: `tree-sitter` is required for full-profile Neovim parser updates. The bootstrap installs it with `cargo install tree-sitter-cli --locked` because current `nvim-treesitter` shells out to `tree-sitter build`, and older distro packages can lag that command surface.
- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- TypeScript LSP: global `typescript` plus `typescript-language-server` for Neovim `ts_ls`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux

Why these choices:

- Neovim >= 0.11 is the minimum floor because the Lua plugin ecosystem and built-in LSP client require it.
- `nvim-treesitter` now shells out to the external `tree-sitter` binary for parser builds, and the distro `tree-sitter-cli` package can be too old to support `tree-sitter build`. Installing from Cargo keeps the CLI compatible with the plugin.
- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- TypeScript buffers rely on an external language server binary; the full-profile runtime bootstrap installs both `typescript` and `typescript-language-server` after the Node toolchain is available.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- All Linux binary downloads are architecture-aware (x86_64 and arm64/aarch64).
- `fnm` node stack is hardened: PATH is re-evaluated after install, and pnpm falls back to `npm install -g pnpm` if corepack is unavailable.
- Runtime-critical PATH/bootstrap for `fnm`, `node`, `pnpm`, `bun`, Go user binaries, repo scripts, and related CLI entrypoints lives in `shell/.profile`. zsh login shells inherit that through `shell/.zprofile`, and interactive non-login zsh shells backfill by sourcing `~/.profile` from `shell/.zshrc` when needed.
- Interactive-only hooks such as `fnm --use-on-cd`, completions, and prompt/theme behavior stay in `shell/.zshrc`.
- `./setup.sh` refreshes `~/.local/bin` symlinks for commands that resolve outside the base system PATH so agents and non-login shells can rely on the same stable command layer.
- The runtime contract is explicit-profile only: `./setup.sh` installs the profile you name and does not auto-select one from the environment.
- Interactive zsh shells reject project-level `npm install` / `npm i` loudly; use `pnpm install` or `pnpm add` instead. Global installs via `npm ... -g` are allowed, though `pnpm add -g` remains the preferred default. The bootstrap may still invoke raw `npm install -g pnpm` internally as a non-interactive fallback when `corepack` is unavailable.
