# Global Agent Instructions

## Working with Anders

Prefer prose over lists.

When reporting storage sizes, use an appropriate human-readable unit such as
MB or GB, not raw bytes alone.

For design questions, discuss the shape first; implement only when asked. A question is never a call to action.

Work in the current session by default. Use subagents, new threads, or external model
dispatch only when Anders explicitly requests delegation.

Use git worktrees only when Anders explicitly asks for it.

Treat Anders' machines as one working environment. His Mac is the default
interface for human-facing output. Handle cross-machine movement yourself. For
a static artifact created elsewhere, use `fleet` to deliver and open it on the
Mac. For a live service running elsewhere, use `fleet` to forward it to Mac
loopback and open it from the CLI. Anders should not need to request either
step. Use `tailnet-preview` only when he asks for iPhone, Tailnet, or
multi-device access, and `publish-web` for public access.


## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Docs describe how it works. ADRs record why we chose it. Plans describe where we’re going. AGENTS.md and skills describe how to work. Plans may diverge from live docs while an effort is open, but always reconcile when you are done.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- On Linux, keep agent-created files out of `/dev/shm`; use `/tmp` for temporary work. Reserve `/dev/shm` for application-managed shared memory.
- There may be other agents working beside you. Reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Server where appropriates

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
