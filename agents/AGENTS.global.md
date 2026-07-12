# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

Write user-facing explanations in clear, concise language without reducing technical precision. Prefer concrete wording over unexplained jargon. Use established domain terminology when it is the most precise choice, and briefly define it when the intended audience may not know it. Preserve material evidence, constraints, tradeoffs, caveats, and uncertainty. Do not rewrite code, identifiers, commands, quoted text, or prescribed formats merely to satisfy this style rule.

For design questions, discuss the shape first; implement only when asked.


## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Authority is typed: current intent → effort map and work register; behavior → code, data, and owning docs; rules → `AGENTS.md`; rationale → ADRs. Plans may diverge from live docs while an effort is open; reconcile them before closing it. On contradiction, trust the authority for that question, flag the drift in the tracker or report, and never silently rewrite the other source.

## Delegation

Token efficiency governs delegation; model continuity is primary. Start every GPT subagent turn with `spawn_agent`, explicitly setting `model` and `reasoning_effort`. Steer only ongoing turns with `send_message`; continue ended work in a fresh typed agent. `followup_task` can resume Terra or Luna as parent Sol, wasting frontier quota, so never use it for continuation.

Sol retains architecture, direction, difficult judgment, integration, and final verification. Terra handles bounded exploration and everyday implementation; Luna handles repetitive, high-volume, mechanically verifiable work. Always use `reasoning_effort: high` for Terra and Luna; Sol uses `medium` or `high`.

Subagents are context firewalls. Delegate when execution and context-preservation benefits meet or exceed handoff and integration costs. At execution break-even, delegate to keep low-signal exploration, logs, and mechanical work out of root Sol context; clean context preserves judgment and reduces drift.

Use one-shot lanes: one bounded task, ownership boundary, and terminal deliverable. Workers complete and return their assigned lane; only agents explicitly assigned orchestration create further lanes. Delegation does not transfer ownership: the delegating agent inspects the work, runs final checks, opens the artifact, and reports only verified results.

Use compact, durable handoffs with exact paths, state, and acceptance criteria. Default to `fork_turns: "none"`; use the smallest useful fork. Full forks require the full conversation and the parent's model for cache reuse; otherwise send a compact handoff.

Fan-out follows independent seams, not available slots. Use serial work when lanes share files, decisions, or prerequisites. Track lanes through wait and status surfaces, and intervene only on new evidence or a blocker.

GPT agents delegate through native subagent tools and invoke neither `model-routing` nor `codex-dispatch`. Claude and Fable invoke `model-routing` before delegating or setting a `model`. Their local `Agent` tool is the Claude subagent surface; `codex-dispatch` is its Codex counterpoint and owns every Codex dispatch.

The requested model and displayed agent name are not proof of what ran; the turn trace is authoritative. A different actual model is an orchestration failure: stop the lane and correct the dispatch pattern before continuing.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.

## Dev Servers

`.dev-server.md` in the project root is the ignored local source of truth. Read it before any server action. After starting, stopping, restarting, or discovering stale state, immediately update its status and `Updated` timestamp; taking the server down must set `Status: stopped`. Record the command, URL/port, PID, and log location when applicable, and ensure Git ignores the file.
