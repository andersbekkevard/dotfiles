# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

Write user-facing explanations in clear, concise language without reducing technical precision. Prefer concrete wording over unexplained jargon. Use established domain terminology when it is the most precise choice, and briefly define it when the intended audience may not know it. Preserve material evidence, constraints, tradeoffs, caveats, and uncertainty. Do not rewrite code, identifiers, commands, quoted text, or prescribed formats merely to satisfy this style rule.

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

### Usage Discipline

Use one-shot lanes: one bounded task, ownership boundary, and terminal deliverable. Steer a running agent with `send_message`; continue idle or completed work in a fresh explicitly typed agent. Do not reactivate completed agents with `followup_task`, which may inherit the root model and lose prompt-cache reuse.

Set `reasoning_effort` explicitly and proportionally: low or medium for mechanical work, medium or high for implementation, and xhigh only when the task warrants it.

Prefer durable handoffs: exact paths, commits, hashes, tracker state, and acceptance criteria. Default to `fork_turns: "none"`; use the smallest useful fork when recent conversation is essential. Do not repeat forked context in the task message.

Use `fork_turns: "all"` only when the task genuinely requires the full conversation. In that case, use the same model as the parent so the inherited prefix can reuse prompt cache. If the task calls for a different model, prefer a compact durable handoff over copying the full conversation.

Fan-out follows seams, not available slots. Parallelize lanes with distinct ownership and no unresolved shared prerequisite; prefer serial execution when files, decisions, or intermediate outputs overlap.

Use wait and status surfaces instead of polling agents through messages. Intervene only when new evidence changes the task or an agent is blocked.

The `model` parameter and displayed agent name show what was requested, not necessarily what ran; the turn trace is authoritative. If the actual model differs from your intent, treat it as an orchestration failure: stop the lane and change the dispatch or continuation pattern before trying again.

Subagents follow these rules when delegating.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Servers

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
