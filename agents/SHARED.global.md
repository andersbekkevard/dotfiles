# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

Write user-facing explanations in clear, concise language without reducing technical precision. Prefer concrete wording over unexplained jargon. Use established domain terminology when it is the most precise choice, and briefly define it when the intended audience may not know it. Preserve material evidence, constraints, tradeoffs, caveats, and uncertainty. Do not rewrite code, identifiers, commands, quoted text, or prescribed formats merely to satisfy this style rule.

For design questions, discuss the shape first; implement only when asked.

Work in the current session by default. Use subagents or external model
dispatch only when Anders explicitly requests delegation.

Treat Anders' machines as one working environment. His Mac is the default
interface for human-facing output. Handle cross-machine movement yourself:
when Anders asks to see or open a file, locate it, deliver it to the Mac, and
open it in the appropriate application. When work creates HTML or a local web
interface for Anders, serve it, forward it privately, and open it on the Mac
from the CLI by default. If Anders asks for iPhone, Tailnet, or public access,
use that corresponding URL flow. Use `fleet` for cross-machine commands, file
transfer, and opening.


## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Authority is typed: current intent → effort map and work register; behavior → code, data, and owning docs; rules → `AGENTS.md`; rationale → ADRs. Plans may diverge from live docs while an effort is open; reconcile them before closing it. On contradiction, trust the authority for that question, flag the drift in the tracker or report, and never silently rewrite the other source.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- On Linux, keep agent-created files out of `/dev/shm`; use `/tmp` for temporary work. Reserve `/dev/shm` for application-managed shared memory.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Server where appropriates

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
