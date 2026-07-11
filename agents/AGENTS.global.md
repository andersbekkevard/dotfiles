# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

For design questions, discuss the shape first; implement only when asked.

## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Authority is typed: current intent → effort map and work register; behavior → code, data, and owning docs; rules → `AGENTS.md`; rationale → ADRs. Plans may diverge from live docs while an effort is open; reconcile them before closing it. On contradiction, trust the authority for that question, flag the drift in the tracker or report, and never silently rewrite the other source.

## Delegation

The root agent retains architecture, direction, judgment, integration, difficult work, and final verification. Delegate proactively through native subagents.

Always set the subagent `model` explicitly:
- `gpt-5.6-terra` for bounded exploration and everyday implementation.
- `gpt-5.6-luna` for repetitive, high-volume, mechanically verifiable work.

GPT agents delegate through native subagent tools and invoke neither `model-routing` nor `codex-dispatch`. Claude and Fable invoke `model-routing` before delegating or setting a `model`. Their local `Agent` tool is the Claude subagent surface; `codex-dispatch` is its Codex counterpoint and owns every Codex dispatch.

Delegation does not transfer ownership. If you delegate or use subagents, you own the outcome: inspect their work, run the final checks, open the artifact, and report only what you verified.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Servers

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
