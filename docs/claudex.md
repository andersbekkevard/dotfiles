# Claudex

`claudex` runs the Claude Code harness with a Codex model without changing ordinary `claude` authentication or routing.

## First use on each machine

The full profile installs Claude Code and the correct CLIProxyAPI release, creates a localhost-only configuration and private local API key, and stows the wrapper commands. Authenticate Codex once, then run a safe smoke test:

```bash
./setup.sh full
claudex-proxy login
claudex --safe-mode
```

After the smoke test succeeds, use the normal Claude Code customizations:

```bash
claudex
```

`claudex` starts the proxy when necessary and launches GPT-5.6 Sol at high effort. It explicitly removes `ANTHROPIC_API_KEY` and scopes the proxy URL, token, model, effort, context-compaction boundary, and tool variables to its own process. Running `claude` continues to use the existing Anthropic configuration.

Claude Code owns context management in this harness; Codex CLI settings from `~/.codex/config.toml` do not apply. The wrapper therefore treats the context window as 272,000 tokens and asks Claude Code to auto-compact at 88%, approximately 239,360 tokens. This keeps requests below the 240,000-token billing boundary without depending on Claude Code's classification of the proxied model name.

Do not use `claudex --continue` to resume a conversation created by ordinary Claude Code under a different provider.

## Model overrides

Defaults can be changed for one invocation:

```bash
CLAUDEX_MODEL=gpt-5.6-sol CLAUDEX_EFFORT=high claudex
CLAUDEX_SUBAGENT_MODEL=gpt-5.6-luna claudex
CLAUDEX_CONTEXT_WINDOW=272000 CLAUDEX_AUTOCOMPACT_PCT=88 claudex
CLAUDEX_MAX_TOOL_CONCURRENCY=2 claudex
CLAUDEX_ENABLE_TOOL_SEARCH=true claudex
```

The defaults are Sol high for the main agent, Luna high for Claude Code subagents, a 272,000-token compaction window with an 88% threshold, three concurrent tool calls, and dynamic tool search disabled. Set `CLAUDEX_SUBAGENT_MODEL=gpt-5.6-sol` when a session needs Sol workers instead. Keep any context overrides below the provider's higher-priced long-context boundary.

## Proxy lifecycle

```bash
claudex-proxy start
claudex-proxy status
claudex-proxy logs
claudex-proxy restart
claudex-proxy stop
```

The generated files are deliberately machine-local:

| Path | Purpose |
|---|---|
| `~/.config/cliproxyapi/config.yaml` | Localhost-only proxy configuration |
| `~/.config/cliproxyapi/claudex.env` | Private local endpoint and API key |
| `~/.cli-proxy-api/` | OAuth credentials managed by CLIProxyAPI |
| `~/.local/state/cliproxyapi/` | PID and log files |

Setup creates the configuration and environment files only when both are absent. It never replaces an existing pair. A partial pair is treated as an error so setup cannot silently generate credentials that disagree with an existing configuration.

The proxy must remain bound to `127.0.0.1`; do not expose port 8317 to the network.
