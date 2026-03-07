# Runtimes

- Neovim: >= 0.11 required. Homebrew on macOS; GitHub release tarball on Linux (`~/.local/share/nvim-install`, symlinked from `~/.local/bin/nvim`). Distro packages are not used as most ship < 0.11. Supports x86_64 and arm64.
- Tree-sitter CLI: `tree-sitter` is required for full-profile Neovim parser updates. The bootstrap installs it with `cargo install tree-sitter-cli --locked` because current `nvim-treesitter` shells out to `tree-sitter build`, and older distro packages can lag that command surface.
- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux

Why these choices:

- Neovim 0.12
- `nvim-treesitter` now shells out to the external `tree-sitter` binary for parser builds, and the distro `tree-sitter-cli` package can be too old to support `tree-sitter build`. Installing from Cargo keeps the CLI compatible with the plugin.
- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- Linux avoids Linuxbrew and uses apt plus official binaries/scripts instead.
- All Linux binary downloads are architecture-aware (x86_64 and arm64/aarch64).
- `fnm` node stack is hardened: PATH is re-evaluated after install, and pnpm falls back to `npm install -g pnpm` if corepack is unavailable.
- Interactive zsh shells reject `npm install` / `npm i` and `npm ... -g` loudly; use `pnpm install`, `pnpm add`, or `pnpm add -g` instead. The bootstrap may still invoke raw `npm install -g pnpm` internally as a non-interactive fallback when `corepack` is unavailable.
