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

*Default to Codex.* gpt-5.6-sol runs on a separate subscription that doesn't
drain the Claude/Fable pool, so treat it as cheaper than every Claude model
regardless of list price:

- Quick read-only tasks — exploration, "what does this file/repo do", state
  checks, log digging, runbook extraction: codex.
- Scoped, well-specified implementation: codex.
- If computer use is helpful for completing or verifying work, shell out to
  gpt-5.6-sol with Codex for it.

Every Codex dispatch — foreground or detached — follows the `codex-dispatch`
skill, which owns invocation mechanics, reasoning-effort levels, lane
supervision, and recovery.

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

| model    | cost | intelligence | taste |
|----------|------|--------------|-------|
| gpt-5.6-sol | 9 | 8            | 5     |
| sonnet-5 | 5    | 5            | 7     |
| opus-4.8 | 4    | 7            | 8     |
| fable-5  | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. Standing permission to override: if a
  cheaper model's output doesn't meet the bar, rerun or redo the work with
  a smarter model without asking. Judge the output, not the price tag.
  Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships,
  intelligence > taste > cost.
- The taste that matters for user-facing artifacts — domain judgment,
  semantics, prose — lives with you (fable-5). Spec tightly, delegate the
  mechanics to gpt-5.6-sol, and author or final-pass the judgment-heavy
  semantics and prose yourself.
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

- gpt-5.6-sol is only reachable through the Codex CLI (`~/.codex/config.toml`
  defaults to gpt-5.6-sol @ high, full access, approvals off — intentional,
  never pass sandbox flags): `codex exec` for investigation, analysis, or
  implementation; `codex review` for the current repo's diff.
- Claude models (sonnet-5, opus-4.8, fable-5) run via the Agent/Workflow
  model parameter.
