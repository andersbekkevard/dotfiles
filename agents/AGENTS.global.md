# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

Write user-facing explanations in clear, concise language without reducing technical precision. Prefer concrete wording over unexplained jargon. Use established domain terminology when it is the most precise choice, and briefly define it when the intended audience may not know it. Preserve material evidence, constraints, tradeoffs, caveats, and uncertainty. Do not rewrite code, identifiers, commands, quoted text, or prescribed formats merely to satisfy this style rule.

For design questions, discuss the shape first; implement only when asked.


## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Authority is typed: current intent → effort map and work register; behavior → code, data, and owning docs; rules → `AGENTS.md`; rationale → ADRs. Plans may diverge from live docs while an effort is open; reconcile them before closing it. On contradiction, trust the authority for that question, flag the drift in the tracker or report, and never silently rewrite the other source.

## Delegation

Preserve Sol for direction, difficult judgment, integration, and final verification. Spawn Terra for bounded exploration and everyday implementation, and Luna for repetitive, high-volume, mechanically verifiable work; both use `high`, Sol uses `medium` or `high`.

Use subagents as context firewalls. At execution break-even, delegate independent low-signal work to preserve clean Sol context and reduce drift. Give each lane one terminal deliverable; serialize shared files, decisions, and prerequisites.

Every GPT worker turn is typed: use `spawn_agent` with explicit `model`, `reasoning_effort`, `fork_turns: "none"`, and a compact handoff. Steer ongoing turns with `send_message`; continue ended Terra or Luna work with a fresh typed `spawn_agent`. `followup_task` resumes the worker as parent Sol, wasting scarce, higher-usage Sol tokens on work deliberately routed to a worker model.

The turn trace is authoritative. If it shows model drift, orchestration has failed: stop the lane and correct the dispatch or continuation pattern before retrying.

Codex delegates natively; Claude and Fable route model choice through `model-routing`.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Servers

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
