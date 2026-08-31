---
name: project
description: Create, maintain, or audit an Anders project repository so its context survives agents, sessions, and machines. Use when shaping a project's durable context, ownership, placement, and growth.
---

# Project

Status: work in progress.

An Anders project is one compounding life or work domain carried by a Git
repository. Chat is working memory. The repository is the project. Its files
must let a capable agent continue without the previous agent, harness, machine,
or conversation.

This skill owns the project's context contract. It does not own the domain
work, planning method, source-ingestion procedure, application architecture, or
conversation style.

Own the architecture while this skill is active. Anders supplies project
intent, constraints, and the judgments that genuinely require him. You are
responsible for keeping the repository current, easy for later agents to
resume, and able to expose or repair routine drift with as little owner effort
as possible. Improve the contract through use. When work reveals ambiguous
placement, stale routes, competing owners, missing provenance, or repeated
manual recovery, make the smallest authorized correction that addresses the
cause. The target is a self-managing repository that improves the work later
agents can do without asking Anders to reconstruct its architecture. This
stewardship does not authorize unrelated domain work.

## Shape the contract

Inspect the live repository and its local instructions before proposing a
structure. Preserve conventions that already have real use behind them.

Outline the project's actual information and work types before choosing a
structure. For each type, identify the question it answers, its current owner,
its provenance, its routes, and how often it changes. Then decide sequentially
what can remain combined and what has earned a separate owner. Own that
judgment. Ask Anders when a choice changes project intent, human authority,
privacy, or permitted external effects, not merely because several reasonable
filing choices exist.

Make the project self-contained. Put the small contract needed on ordinary
turns in one repository-owned instruction body, normally `AGENTS.md`. Expose
that same body through any harness-specific entrypoints the project uses
without maintaining divergent copies. A future agent must not need this global
skill or Anders's dotfiles to understand the repository.

Establish only what current work needs:

- a short cold-start route;
- one current owner for each question, with links or indexes as routes rather
  than competing copies;
- a home for durable preferences, constraints, decisions, results, and
  corrections revealed during work;
- explicit privacy and Git-publication boundaries; and
- enough provenance and uncertainty to distinguish evidence, reports, and
  inference.

Placement is the dual of search. Define placement precisely enough that the
same item, given the same known facts, lands with the same owner. Give it one
physical home and as many routes as readers need. An inbox may quarantine
material whose owner is genuinely unknown, but it is not a permanent owner.

Use Obsidian-compatible Markdown and wikilinks for project knowledge and
routing. Keep source URLs and other external references clickable. A `docs/`
folder is referential: it explains the repository's structure and mechanisms
and routes to current owners. It should not mirror current claims, plans, or
behavior already owned elsewhere.

Prefer plain Markdown for durable context. Add structured data, code, or an
application only when the work needs behavior that prose cannot own reliably.

Do not turn these distinctions into folders before real material needs them.
A new location earns its place when the first concrete item lacks an owner. A
new category earns its place when repeated items reveal a stable organizing
concept. Split an existing owner when different questions, update rhythms, or
reading paths have begun to interfere with one another.

When a new owner supersedes an old one, move the current claims and routes in
the same change. Keep useful history in Git, dated evidence, or an earned
decision record rather than leaving two current authorities.

Use an ADR when a choice is hard to reverse, surprising without its context,
and contains a real trade-off. All three conditions should hold. Create the
first ADR when the first qualifying decision appears, not an empty directory in
anticipation.

Read the [architecture pattern catalogue](references/growth-patterns.md) when
deciding whether the project has earned more routing, planning, evidence,
automation, state, or decision structure. It records patterns from Anders's
existing repositories as a playbook to copy, combine, adapt, or reject, not as
a template.

## Preserve continuity

Capture the durable part of a turn while its meaning is still clear. Preserve
the preference, limiter, decision, result, correction, or reusable method, not
a transcript of the conversation. A question remains a question; durable
capture does not authorize unrelated implementation.

Let the repository choose its synchronization mode. A clean personal project
may pull and push `main` every changed turn. A collaborative repository may
require branches, reviews, or protection of concurrent work. In either case,
finish with the durable change published through the authorized workflow or
state exactly why it remains local.

Keep secrets and restricted material outside ordinary tracked context. Choose
ignored, encrypted, external, or manifest-backed custody from the actual
privacy, size, licensing, and recovery needs rather than copying another
project's mechanism.

## Review the result

The project should be easier for a cold agent to resume without making every
agent monitor concepts the project has not yet used. Treat any proposed new
file, folder, document type, tracker, or workflow as a cost. Keep it only when
it gives a real item one clearer owner, removes repeated confusion, or makes an
important operation safer or reproducible.
