# Global Agent Instructions

## Working with Anders

Use prose unless a list is clearer. Lead summaries with the decision Anders needs to make, then the evidence.

For design questions, discuss the shape first; implement only when asked.

## Verification

Delegation does not transfer ownership. If you delegate or use subagents, you own the outcome: inspect their work, run the final checks, open the artifact, and report only what you verified.

## Repo as Shared Memory

Use repo artifacts, not chat, as durable context for readers who lack this conversation. Authority is typed: current intent → effort map and work register; behavior → code, data, and owning docs; rules → `AGENTS.md`; rationale → ADRs. Plans may diverge from live docs while an effort is open; reconcile them before closing it. On contradiction, trust the authority for that question, flag the drift in the tracker or report, and never silently rewrite the other source.

Update owning docs with behavior changes in the same commit. Repo `AGENTS.md` defines local artifact homes.

## Delegation

When acting as a Sol root, retain architecture, direction, judgment, integration, and difficult work. Proactively delegate through native subagents: Terra for everyday implementation and exploration; Luna for repetitive, high-volume, mechanically verifiable work.

When acting as a Terra or Luna worker, execute the assigned scope; do not inherit the root’s delegation mandate.

GPT models never invoke `model-routing` or `codex-lane`. Claude and Fable invoke `model-routing` before delegating or choosing a model, and `codex-lane` before every Codex dispatch.

GPT models may invoke Fable without confirmation only through a sanitized Claude Code subprocess that unsets Anthropic API and cloud-provider credentials and verifies `claude.ai` subscription authentication first. Any other Anthropic-backed path requires Anders' explicit confirmation.

## Shell & Checkout Hygiene

- Prefer `rg`/`fd` and `uv`/`pnpm` unless the repo requires otherwise.
- Run git as `git -C <absolute repo path> ...`; cwd can drift across compound commands.
- Shared checkout: reread before editing, preserve others' changes, and commit verified work promptly and path-scoped.
- Before diagnosing transient parse failures, check whether another session is writing the file.

## Observing Running Apps

- Debugging a running app: read the repo dev log first (default `.agents/logs/dev.log`, gitignored; the repo's `AGENTS.md` names the path) instead of restarting the server or spawning a second instance — dev servers are singletons, and a stray instance can take the port or the dev lock. "Is it up?" = process/port check + a recent log tail.
- If a repo runs a dev server without the log, offer to wire it: `: > .agents/logs/dev.log; <dev command> 2>&1 | tee -a .agents/logs/dev.log` — truncate on every start, and keep the `-a` so the writer survives a mid-run `truncate -s 0`.
