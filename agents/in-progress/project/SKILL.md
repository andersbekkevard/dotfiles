---
name: project
description: Maintain an Anders project as durable context across agents, sessions, harnesses, and machines. Use when work reveals project knowledge, placement, ownership, provenance, or structure that should survive the conversation.
---

# Project

Status: work in progress.

An Anders project is one compounding life or work domain carried by a Git
repository. The agent's intelligence is replaceable; the project's context is
not. Chat is working memory. The repository is continuity.

This skill owns the project's context contract and its gradual improvement. It
does not own the domain work, planning method, source procedure, application
architecture, or conversation style. Use [`create-project`](../create-project/SKILL.md)
to turn a new idea into a repository.

## Steward the project

Read the live repository and its local instructions before changing its shape.
Preserve conventions that have useful work behind them. Keep the repository
self-contained: a capable agent should be able to resume from the repository
without this conversation, Anders's dotfiles, or a particular harness.

Before redesigning anything, outline the project's real information and work
types, the question each answers, its current owner and provenance, and how it
changes. Make architectural changes sequentially so each new owner has real
material and its routes and superseded authority can move with it.

Own the ordinary architectural judgment. Anders supplies intent, preferences,
constraints, and decisions that genuinely require him. Do not ask him to choose
between equivalent filing options. Do ask when a choice changes the project's
purpose, human authority, privacy, publication, or permitted external effects.

Treat the contract as living. When authorized work reveals ambiguous placement,
stale routes, competing owners, missing provenance, or repeated manual recovery,
make the smallest correction that addresses the cause. Aim to require less
architectural maintenance from Anders as the project gains experience.

Keep the smallest useful cold-start contract in the repository's main agent
instructions. It should establish the project, the authoritative reading route,
the placement rules that matter now, and any safety or completion boundaries.
Expose one shared contract to the harnesses the project uses; do not maintain
divergent instructions.

Capture durable context while its meaning is clear: preferences, constraints,
decisions, corrections, results, provenance, and reusable methods. Preserve the
smallest useful fact, not a transcript. A question remains a question; capturing
what it revealed does not authorize unrelated implementation.

When Anders reports a completed event inside the active project's domain and it
could inform future decisions, methods, or progress, the report itself authorizes
recording that event within the project's established privacy and publication
boundary. Do not make Anders request tracking or repeat information he has
already supplied. Preserve his words when useful, or write a faithful
reconstruction without inventing details. Ask only when the target project,
privacy boundary, or meaning is genuinely unclear.

## Place before searching

Placement is the dual of search. Give each question one current owner and make
new material land there predictably. A fact may have many routes, views, or
links, but one physical home. When authorities disagree, state which type wins
for that question: policy, configuration, procedure, current state, evidence,
rationale, or future intent.

Deepen an existing owner before creating another file or folder. A new owner is
earned when different questions, update rhythms, rules, or reading paths begin
to interfere. A small project may keep its map, current knowledge, and next
action together. Split them only when use creates pressure.

`docs/` is referential. It explains how the repository works and routes to
current owners; it should not mirror claims, plans, or behavior owned elsewhere.
Use Obsidian Markdown and wikilinks when the project is an Obsidian knowledge
graph. Otherwise follow the repository's native format. Keep external
references clickable.

When an owner moves, update the current claim and its routes together. Preserve
useful history in Git, dated evidence, or a decision record without leaving two
current authorities. A short claim-free signpost at an old, obvious address is
reasonable when removing it would make retrieval worse.

## Grow through pressure

Do not prebuild a mature repository. Add structure when real use identifies a
missing owner, repeated ambiguity, or a risky recurring operation. Prefer plain
Markdown until structured data or code owns something prose cannot reliably
own.

An ADR is earned when a decision is hard to reverse, surprising without its
context, and contains a real trade-off. All three should hold. Create the first
ADR for the first qualifying decision, not an empty ADR directory in advance.

When sources become important, separate received evidence, faithful derivation,
and interpretation as far as the domain requires. Bronze, Silver, and Gold are
a proven pattern, not universal semantics; if adopted, define their guarantees
inside the project. Keep provenance and uncertainty close to the claim.

Turn a repeated or consequential rule into a check when objective validation is
possible. Keep policy, detection, and repair authority distinct: a checker
provides evidence and does not silently grant itself permission to repair.

Read the [growth patterns](references/growth-patterns.md) when the project has
earned a new layer. Read the [repository casebook](references/repository-cases.md)
for the contexts in which Anders's existing patterns worked, drifted, or remain
untested. They are material for judgment, not a folder template.

## Preserve continuity

Privacy follows the bytes, not the source path. Choose ordinary Git, encryption,
ignore rules, external custody, or manifest-backed custody from the material's
actual constraints. Preserve enough metadata to locate and verify material
without copying restricted content into broader surfaces.

Publish authorized durable changes through the repository's own Git workflow.
A private single-owner project may work directly on `main`; a shared repository
may require branches and review. Never replace local governance with a global
habit.

The project should become easier to resume and maintain through use without
making every agent monitor concepts it has not yet needed. Keep a proposed file,
folder, document type, tracker, or workflow only when it gives real material a
clearer owner, removes repeated confusion, or makes an important operation safer
or reproducible.
