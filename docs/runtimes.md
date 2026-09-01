# Runtimes

- Neovim: >= 0.11 required. Homebrew on macOS; GitHub release tarball on Linux (`~/.local/share/nvim-install`, symlinked from `~/.local/bin/nvim`). Distro packages are not used as most ship < 0.11. Supports x86_64 and arm64.
- fzf: Homebrew on macOS; upstream GitHub release tarball on Linux, installed to `~/.local/bin/fzf` when missing and replaced only by explicit `update`. Distro packages are not used on Linux because they can lag the key-binding surface used by tmux helpers.
- TruffleHog: Homebrew on macOS; latest upstream GitHub release tarball on Linux, installed to `~/.local/bin/trufflehog`. It is part of the minimal command contract because the global `autoreview` skill fails closed without its credential scan.
- Tree-sitter CLI: `tree-sitter` is required for full-profile Neovim parser updates. The bootstrap installs it with `cargo install tree-sitter-cli --locked` because current `nvim-treesitter` shells out to `tree-sitter build`, and older distro packages can lag that command surface.
- Python: `uv`
- Rust: `rustup`
- Node.js: `fnm` plus `corepack` for `pnpm`
- Claude Code: official standalone installer (`https://claude.ai/install.sh`), installed under `~/.local/share/claude` with a stable `~/.local/bin/claude` entrypoint
- Codex CLI: official standalone installer (`https://chatgpt.com/codex/install.sh`), installed under `~/.codex/packages/standalone` with a stable `~/.local/bin/codex` entrypoint
- agent-browser: latest pnpm global release for the Linux desktop profile. The profile registers its core MCP server with Codex so app-server can host browser tools outside the per-command Linux sandbox. Its stable `~/.local/bin/agent-browser` launcher puts daemon sockets under `/tmp/agent-browser-<uid>` for ordinary shell use.
- CLIProxyAPI: latest checksummed GitHub release for the active OS/architecture, installed under `~/.local/share/cliproxyapi/<version>` with a stable `~/.local/bin/cli-proxy-api` entrypoint. Setup creates a private, localhost-only configuration under `~/.config/cliproxyapi`; Codex OAuth credentials remain machine-local under `~/.cli-proxy-api`.
- TypeScript LSP: global `typescript` plus `typescript-language-server` for Neovim `ts_ls`
- Bun: official install script
- Go: Homebrew on macOS, official tarball on Linux
- PostgreSQL client: Homebrew `libpq` on macOS, `postgresql-client` on Linux. On macOS, profile-wide `dotfiles.sh install` and `refresh` operations expose Homebrew's keg-only `psql` through `~/.local/bin/psql` for Dadbod and non-interactive command resolution.

Why these choices:

- Neovim >= 0.11 is the minimum floor because the Lua plugin ecosystem and built-in LSP client require it.
- `nvim-treesitter` now shells out to the external `tree-sitter` binary for parser builds, and the distro `tree-sitter-cli` package can be too old to support `tree-sitter build`. Installing from Cargo keeps the CLI compatible with the plugin.
- `fnm` keeps shell startup fast and satisfies the PRD hard constraint against `nvm`, `volta`, and `mise`.
- TypeScript buffers rely on an external language server binary; the full-profile runtime bootstrap installs both `typescript` and `typescript-language-server` after the Node toolchain is available.
- SQL buffers that use Dadbod against PostgreSQL require the external `psql` client, so the full profile installs and verifies it.
- `uv` replaces separate Python version, venv, and package tooling.
- `rustup` is the canonical Rust toolchain installer.
- All Linux binary downloads are architecture-aware (x86_64 and arm64/aarch64). Exception: `greenclip` (linux-desktop only) has no upstream aarch64 release, so setup records a clear error instead of installing an x86_64 binary on arm64 machines.
- `fnm` node stack is hardened: PATH is re-evaluated after install, pnpm falls back to `npm install -g pnpm` if corepack is unavailable, and the configured pnpm global bin directory is exported into the active bootstrap PATH before global tools are installed.
- pnpm has one OS-aware global-bin contract shared by setup and shell startup: `~/Library/pnpm` on macOS and `~/.local/share/pnpm` elsewhere. Setup configures pnpm to that location, then exposes installed globals in the active run and future login shells.
- The full layer installs missing Claude Code and Codex CLIs with their official standalone installers. Explicit `update` reruns an installer only when the active command still resolves into that installer's owned directory; external providers are preserved. Setup puts `~/.local/bin` on `PATH` before invoking either installer so they do not write machine-specific PATH blocks through the stowed shell profile.
- The Linux desktop layer installs and updates `agent-browser` through pnpm, registers the pnpm-owned launcher as the `agent_browser` Codex MCP server, and marks that server's core browser tools approved. This lets fresh desktop tasks invoke typed browser tools without a prompt while preserving approval policy for unrelated commands and MCP servers. The command sandbox denies the browser daemon's Unix-socket bind even under `/tmp`, so sandboxed tasks must use the MCP tools instead of starting the CLI daemon themselves. The generated stable shell launcher still defaults `AGENT_BROWSER_SOCKET_DIR` to `/tmp/agent-browser-<uid>` when the caller has not selected one.
- The minimal layer installs TruffleHog before it links the global agent surface. Homebrew owns the macOS binary; the Linux release manifest selects the upstream `amd64` or `arm64` tarball and exposes it through `~/.local/bin`.
- The full layer installs CLIProxyAPI only after the minimal layer has provided `curl` and `jq`. The release checksum is verified before extraction. `claudex` scopes `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, model, effort, Claude Code context-compaction boundary, and tool settings to its own process and explicitly removes `ANTHROPIC_API_KEY`, so ordinary `claude` keeps its existing authentication and settings. Its 272,000-token calculation window and 88% auto-compaction threshold keep the proxied session just below 240,000 tokens without relying on `~/.codex/config.toml`, which the Claude Code harness does not read.
- Runtime-critical PATH/bootstrap for `fnm`, `node`, `pnpm`, `bun`, Go user binaries, repo scripts, and related CLI entrypoints lives in `shell/.profile`. The shared pnpm default is defined once in `shell/.local/lib/dotfiles/runtime-paths.sh` and consumed by both setup and shell startup. zsh login shells inherit that through `shell/.zprofile`, and interactive non-login zsh shells backfill by sourcing `~/.profile` from `shell/.zshrc` when needed. When an upstream command is a launcher script that depends on its own `$0`, the stable `~/.local/bin` entrypoint targets a generated exec wrapper rather than symlinking that launcher directly.
- Interactive-only hooks such as `fnm --use-on-cd`, completions, and prompt/theme behavior stay in `shell/.zshrc`.
- Profile-wide `./dotfiles.sh install`, `update`, and `refresh` operations update `~/.local/bin` symlinks for commands that resolve outside the base system PATH so agents and non-login shells can rely on the same stable command layer.
- The runtime contract is explicit-profile only: `./dotfiles.sh install` installs the profile you name and does not auto-select one from the environment.
- Interactive zsh shells reject project-level `npm install` / `npm i` loudly; use `pnpm install` or `pnpm add` instead. Global installs via `npm ... -g` are allowed, though `pnpm add -g` remains the preferred default. The bootstrap may still invoke raw `npm install -g pnpm` internally as a non-interactive fallback when `corepack` is unavailable.
