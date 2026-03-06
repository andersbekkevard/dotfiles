# Runtimes

- Neovim: >= 0.11 required. Homebrew on macOS; GitHub release tarball on Linux (`~/.local/share/nvim-install`, symlinked from `~/.local/bin/nvim`). Distro packages are not used as most ship < 0.11. Supports x86_64 and arm64.
- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux

Why these choices:

- Neovim 0.11 is the minimum version supported by the plugin configuration. The bootstrap downloads the latest stable release from GitHub to guarantee this baseline.
- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- Linux avoids Linuxbrew and uses apt plus official binaries/scripts instead.
- All Linux binary downloads are architecture-aware (x86_64 and arm64/aarch64).
- `fnm` node stack is hardened: PATH is re-evaluated after install, and pnpm falls back to `npm install -g pnpm` if corepack is unavailable.
