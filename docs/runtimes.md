# Runtimes

- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux

Why these choices:

- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- Linux avoids Linuxbrew and uses apt plus official binaries/scripts instead.
