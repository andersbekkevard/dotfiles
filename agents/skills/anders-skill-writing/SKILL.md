---
name: anders-skill-writing
description: Anders's evolving preferences for designing, importing, splitting, and revising agent skills. Use when creating or materially revising a skill in Anders's system.
---

# Anders skill writing

Status: work in progress.

This skill records Anders's current preferences and working hypotheses. They
are design guidance to apply and test, not universal rules or a finished
method. A newer explicit choice from Anders takes precedence. When these notes
do not settle a design question, keep the choice visible rather than turning an
assumption into policy.

## Preferred writing mechanics

When creating or materially revising a skill, also read
[`writing-for-agents`](../writing-for-agents/SKILL.md). It remains Anders's
preferred reference for context pointers, information hierarchy, invocation,
completion criteria, and pruning.

Calibrate its prescriptive tools to the skill's maturity. In an early,
exploratory skill, use them to organize what Anders currently understands. Do
not fill unresolved parts with a fixed sequence, branching model, or completion
criteria merely because the reference offers those tools. A reference-shaped
skill with clear direction and visible uncertainty may be the better first
version.

As use establishes the workflow's mental model, add stronger process
instructions more specifically. Safety, permission boundaries, and proven fragile
procedures can justify precision earlier. `writing-for-agents` governs the
writing mechanics; this skill governs how much commitment those mechanics
should encode at the current stage.

Anders currently sees the skill collection as a toolbox rather than a single
prescribed workflow. The way the tools combine belongs to Anders. Borrowing one
skill or suite does not imply adopting its author's complete way of interacting
with agents.

## Current Unix preference

The leading preference is one skill, one coherent responsibility. Use this as
design pressure, not a file-count rule. A promising boundary normally has one
reason to invoke it, one main reason to change it, and a replacement that does
not require redesigning unrelated skills.

Anders currently prefers explicit invocation and reference boundaries between
skills. Behavior may stay together when separating it would duplicate
essential state, split one invariant across owners, or require constant
coordination. Recording that coupling lets a later editor test whether it still
holds.

Replaceability is the current practical test. Anders should usually be able to
swap a procedure, adopt a better implementation, or borrow one focused idea
without redesigning the rest of the collection.

## Preference or procedure

Anders's current mental model is that a skill mainly records a preference or a
procedure. This distinction is useful because the two kinds earn confidence in
different ways.

A preference skill records what Anders wants: taste, defaults, trade-offs, and
decision rules. Its basis comes from Anders's explicit choices and stable
patterns observed through use. Other people's preferences are useful evidence
because human-agent mismatches often recur, but each remains a proposal until
Anders adopts it.

A procedure skill records how to do a job. Its confidence comes from task
performance, iteration, failure recovery, and verification. Its useful content
is the part that saves future agents from repeating expensive discovery. A
procedure can contain a task-specific preference. When a preference governs
several procedures, Anders currently prefers one owner with the procedures
deferring to it.

Treat this classification as a starting question. If real use reveals a better
model, revise the model instead of forcing the skill into it.

## Let specificity trail understanding

Skill instructions shape future behavior and can freeze a workflow before
Anders understands what he wants. Start a new skill with its general direction,
purpose, and known boundaries. Leave unsettled implementation choices open.

Use the skill on real work and observe where the agent needs more guidance.
When Anders has a clearer mental model, encode the stable choices more
specifically. Add strict sequences, fixed formats, and narrow decision rules
when repeated use, safety, or a genuinely fragile procedure justifies them.

Specificity should trail understanding, not lead it. An early skill can be
useful while incomplete. Its next version should become narrower because of
evidence, not because a finished-looking document feels more credible.

## Intellectual juice

Intellectual juice is the thought, experiments, failures, and judgment that a
person compresses into reusable agent behavior. This is the valuable part of a
good external skill. A strong procedure skill is a compressed investment, not
merely a prompt. Borrow that work without importing the author's surrounding
system by default.

Prefer an adapter to a rewrite. Make the smallest change that fits the skill to
Anders's preferences, closer to LoRA than retraining: preserve the creator's
procedure, structure, and intellectual juice, and change only the assumptions
or coupling Anders has chosen differently. Rewrite more broadly only when the
original structure prevents a clean boundary.

The current defaults when adapting an external skill are:

- Isolate the smallest coherent responsibility that carries the useful work.
- Inspect its assumptions and dependencies. Keep only the coupling the job
  needs.
- Preserve provenance and the ability to compare later upstream changes.
- Port specific improvements deliberately instead of treating byte-level sync
  as the goal.
- Test procedures against realistic local work. Ask Anders to adopt borrowed
  preferences rather than silently treating them as his.

## Compound through use

Treat skills as maintained behavior rather than finished essays. What real use
teaches can be written back at different confidence levels:

- Record an explicit Anders preference as a current preference, without
  presenting it as a law for everyone.
- Turn repeated friction or a corrected failure into the narrowest durable
  rule that addresses its cause.
- Preserve a successful procedure when it is reusable and non-obvious.
- Keep a one-off anomaly as evidence or an open hypothesis until it supports a
  general rule.

When Anders identifies a durable preference or reusable correction during real
work, update its owning skill in the same session when that maintenance is in
scope. Otherwise, surface the exact candidate so Anders can choose whether to
record it. Keep the evidence close to the edit instead of waiting for a large
future cleanup.

Revise the existing source of truth instead of stacking a new rule beside an
old one. Remove guidance that a later decision supersedes. The collection
compounds when each edit increases useful judgment without increasing
entanglement.

## Review questions

Use these questions when reviewing a new or materially revised skill. They are
prompts for judgment, not a mechanical gate.

- Can its current responsibility and primary kind fit in one clear sentence?
- Does its invocation boundary reach the intended work without claiming a
  complete interaction system?
- Which statements are current preferences, tested procedures, and open
  hypotheses?
- Has each precise instruction earned its precision through understanding,
  evidence, safety, or necessary coupling?
- Could another skill replace it without unrelated redesign? If not, is the
  coupling understood?
- Does borrowed content retain its provenance and only the dependencies Anders
  chose?

For the global collection in the dotfiles repo, register provenance in
`agents/skill-sources.toml`, validate with `agents/skillpull validate`, inspect
effective invocation with `agents/skillctl list`, check context cost with
`agents/skilltokens`, and refresh the installed agent context with
`./dotfiles.sh agents sync`.
