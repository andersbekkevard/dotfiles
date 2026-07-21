---
name: model-routing
description: Route Claude/Fable orchestration across the model fleet. Invoke before a Claude or Fable orchestrator spawns any subagent or workflow, chooses a model, or starts delegable bulk or parallel work.
disable-codex-model-invocation: true
---

# Model Routing — fleet economics and delegation policy

Claude/Fable orchestrator-only. GPT agents use their native agent tools
instead.

Fable tokens are scarce: spend them on planning, decomposing, and judging
results. Do small edits and quick answers yourself; delegate bulk work —
clear-spec implementation, broad searches/investigation, data analysis,
migrations, and anything parallelizable.

## Who decides

*You own the architecture.* You have the most taste and intelligence in the
fleet, so all architectural and high-level decisions are yours — never
delegate them, and don't let a worker's framing steer them. Treat subagent
output as evidence to judge, not direction to follow: workers report, you
decide. When a worker's result implies an architectural choice (a boundary,
a dependency direction, a security posture), stop and make that call
yourself before building on it.

## Route

Treat the **Delegation** section in the active global agent instructions as
the routing authority. Keep this executable projection aligned with it:

*Default to the GPT fleet.* Luna, Terra, and Sol run on a separate
subscription that doesn't drain the Claude/Fable pool, so treat them as
cheaper than every Claude model regardless of list price. Route each worker
by work shape:

- `gpt-5.6-luna` with `high` reasoning effort: high-volume, routine, and
  trivial work.
- `gpt-5.6-terra` with `high` reasoning effort: scoped implementation.
- `gpt-5.6-sol` with `medium` reasoning effort: high-judgment work.
- `gpt-5.6-sol` with `high` reasoning effort: difficult high-judgment work.
- Use judgment at the boundary: classify the work before choosing the model,
  and escalate when the result misses the bar.
- If computer use is helpful for completing or verifying work, shell out to
  the GPT model that matches the work shape.

Every Codex dispatch — foreground or detached — follows the `codex-dispatch`
skill, which owns invocation mechanics, lane supervision, and recovery.

Reach for Claude subagents only when codex is a poor fit (needs taste ≥ 7,
needs Claude-specific tools/MCP, or orchestration-internal glue) — opus and
sonnet drain the same Claude pool Fable orchestration runs on, so they are
never "cheap".

## Rankings

Higher = better. Cost reflects what Anders actually pays (OpenAI limits are
very generous; the Claude pool is prioritized for Fable orchestration), not
list price. Intelligence is how hard a problem you can hand the model
unsupervised. Taste is judgment quality: domain and semantic modeling,
analytical prose, API/schema design, code quality, UI/UX.

| model         | cost | intelligence | taste |
|---------------|------|--------------|-------|
| gpt-5.6-luna  | 10   | 5            | 3     |
| gpt-5.6-terra | 9    | 7            | 4     |
| gpt-5.6-sol   | 8    | 9            | 7     |
| sonnet-5      | 5    | 5            | 6     |
| opus-4.8      | 4    | 6            | 7     |
| fable-5       | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. Standing permission to override: if a
  cheaper model's output doesn't meet the bar, rerun or redo the work with
  a smarter model without asking. Judge the output, not the price tag.
  Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships,
  intelligence > taste > cost.
- The taste that matters for user-facing artifacts — domain judgment,
  semantics, prose — lives with you (fable-5). Spec tightly, delegate the
  mechanics to Luna or Terra, use Sol for a judgment-heavy second
  perspective, and author or final-pass the semantics and prose yourself.
- opus-4.8 is not part of the default delegation stack: codex is quicker
  and at least as strong for most implementation work, and opus spends
  Fable-pool tokens. Its remaining niche is true UI work, where it
  implements the presentational layer (iterating with screenshots).
- Reviews of plans/implementations: fable-5 judges; codex review is the
  default independent second perspective.
- Never use Haiku. Never use Fable for subagents unless Anders explicitly
  instructs it; flag a request if you think it would be valuable.

## Delegation policy — any model

- Keep one lead owner responsible for the goal, integration, final
  verification, and closeout. Subagents get bounded questions or work
  packages and return concrete evidence: files touched, commands run,
  findings, risks, remaining uncertainty. Do not parallelize a surface so
  tangled that coordination costs exceed the speedup — simplify it first.
- Actively look for parallelizable work: reading or comparing several
  independent files, auditing multiple modules for the same invariant,
  splitting implementation across clearly separate ownership areas, running
  independent verification while the main thread integrates, or scouting a
  bounded question before an architectural change.

## Mechanics

- Luna, Terra, and Sol are reachable through the Codex CLI. Pass the selected
  model and effort explicitly on every dispatch; never rely on
  `~/.codex/config.toml` defaults. Use `codex exec` for investigation,
  analysis, or implementation and `codex exec review` for the current repo's
  diff. Full access and approvals off are intentional; never pass sandbox
  flags.
- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent/Workflow
  model parameter.
