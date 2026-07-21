---
name: lint
description: Read-only repo hygiene lint against local docs, contracts, and ubiquitous language.
disable-model-invocation: true
---

# Repo Lint

Check the current repo for drift from its own documented contract. This skill
does not create policy. It reads the rule-owning files, gathers evidence, and
reports only findings that can be tied to a cited rule or clearly marked as a
heuristic observation.

Ubiquitous language is a repo invariant. Wrong terms steer agents into wrong
mental models and wrong code paths, so language drift should be treated like
architecture drift when it contradicts glossaries, PRDs, ADRs, or boot files.

Keep the lint pass proportionate: read the rule-owning files, inspect the
relevant repo surfaces, run documented read-only validators where they exist,
and return concise numbered findings in chat.

## BCNF Boundary

Keep this skill normalized. Do not duplicate detailed repo rules here when a
doc, boot file, context file, or local `AGENTS.md` owns them. The skill owns the
lint workflow; the repo's files own the rules. If a rule appears to be missing,
report a doc gap rather than inventing policy inside `/lint`.

## Build the Rule-Owner Map

The rules live in the repo, not in this skill. Before checking any kind of
drift, build a map of which file owns which rules, starting from:

1. Root boot files: `AGENTS.md`, `CLAUDE.md` if distinct, root `README.md`.
2. The repo's meta-docs (`docs/**/*.md` or equivalent): operating rules,
   authorship/write permissions, placement, work tracking, ADR conventions,
   planning-material conventions, workflow.
3. Domain-language surfaces: a root context map, glossary or `CONTEXT.md`
   files, and the ADRs they reference.
4. Nested `AGENTS.md` and local READMEs for app/package-local behavior.
5. Repo-local skills that own a surface (e.g. an ingest skill owning parse
   validation) — their rules bind the surfaces they own.

When two rules conflict, cite both and classify it as doc drift or an ambiguous
rule. Do not pick a winner unless the owner hierarchy already says which file
has precedence.

## Default Behavior

`/lint` means a read-only hygiene pass over the current checkout.

Lint is the garbage collector of the repo's shared memory: filesystem
persistence without scheduled invalidation always rots, so lint runs
recurringly (a scheduled routine per repo where wired), not only on request.

## Standing Mandates

Beyond rules the repo documents, these checks always apply — each is a
structural rot mode of a shared-memory repo:

- **Register exhaustiveness.** Where the repo has a work register, every PRD,
  effort map, and open epic must be reachable from it (register + tracker
  query answers "what are we working on?" exhaustively). Unreachable planning
  material is drift.
- **Supersession.** A planning doc whose intent has been pivoted past must say
  so — superseded docs that still read as current, registry rows pointing at
  archived plans, and two docs both claiming to be the current approach to the
  same surface are all findings.
- **Unreconciled close.** Intent-vs-state divergence (map says future, docs
  say present) is licensed while an effort is open and forbidden after it
  closes: a *closed* effort whose decision lines still contradict the live
  docs they invalidated is a finding.
- **Paraphrase.** Boot files and constitutions may carry a one-line gist plus
  pointer for a convention; text that restates a skill's or rule-owner's
  protocol in place is doc drift (two homes for one meaning).
- **Posture staleness.** Hand-authored posture/priority blocks carry a date;
  a posture older than its stated horizon (or visibly overtaken by events) is
  a finding.

## Non-Negotiables

- **Read-only by default.** Do not edit, move, rename, delete, or generate files
  while auditing.
- **Chat-first.** Return the lint result in chat. Write `lint-report.md` or any
  other report file only when Anders explicitly asks for a saved report.
- **Fixes require explicit selection.** If Anders replies `fix 1, 2, 5`, apply
  only those numbered findings. If a fix is ambiguous, ask first.
- **Docs are the rule source.** Cite the doc, boot file, context file, local
  instruction, or rule-owner file behind each finding. If no rule can be cited,
  classify the item as a heuristic note or omit it.
- **Do not invent missing policy.** The absence of a lint checklist, validator,
  or spec is not itself a finding unless the repo docs already promised one.
- **Human-only/private areas stay out.** If the repo designates a human-only
  area (e.g. a personal annex), do not lint or fix it.
- **Generated and dependency artifacts stay out.** Exclude dependency folders,
  caches, generated artifacts, and vendored/external repos unless Anders
  explicitly asks or a rule-owning file puts them in scope.

## Audit Procedure

### 1. Establish Scope

Identify the repo root and state the practical scope in the chat result.

Include the rule-owner files and ordinary active repo surfaces relevant to the
request. Exclude at least: `.git/`, human-only areas, dependency folders
(`.venv/`, `node_modules/`, package caches), build/test caches, generated
artifacts, and vendored/third-party code unless specifically requested.

### 2. Read Governance Context

Before inspecting for drift, read the instruction surface needed for the scope.
For a repo-wide `/lint`, read the full rule-owner map you built. The purpose is
to catch drift from the current docs, not to enforce old memory or generic
preferences. The whole point is to catch misconceptions hiding in the docs, so
do not skip the meta-docs just because the repo looks small.

**Docs-lint runs first**: audit the spec itself — ambiguity, contradiction,
completeness, spec⇄tooling coherence — before checking reality against it. A
broken rule invalidates every content finding that cites it, so `tool drift`
and `ambiguous rule` findings belong to docs-lint, and the report presents
docs-lint before content findings.

### 3. Read Domain Language

Read the domain-language surface before gathering drift evidence: the root
context map if present, every relevant glossary/`CONTEXT.md`, and the ADRs that
govern the context. Build a working lexicon: canonical terms, definitions,
avoided terms, known aliases and legacy terms, context boundaries.

Treat glossaries as glossaries, not specs. Do not invent new glossary terms
during lint. If a durable term appears in active docs or code without a
glossary entry, classify it as a **glossary gap**.

### 4. Gather Evidence

Run the repo's deterministic checkers first and treat their output as the
authoritative record for everything they cover; the semantic pass consumes
that envelope and does **not** re-derive what a checker already decided —
re-deriving wastes tokens and invites disagreement with the authoritative
record. Discover checkers from project docs and tool READMEs, `package.json`
scripts, `tools/**` validators, CI/pipeline definitions, and package-local
`check`/`test`/`validate` commands.

Then use fast, read-only checks for what no checker covers:

- `rg` / `rg --files` for search and inventories.
- Documented check commands and validators only when they are read-only and
  relevant; repo-local skills often own the authoritative validator for their
  surface — use theirs, don't re-derive.
- `uv` for Python and `pnpm` for Node unless a nested instruction says
  otherwise.

Tool output is evidence, not policy. If a checker encodes stale policy, cite
the rule-owning file and classify the result as tool drift. The same goes for a
tracker's built-in linter: when it flags something the repo docs scope more
narrowly (e.g. a required section demanded on an item type the docs exempt),
verify against the rule owner before surfacing the warning as a finding.

Planning-material staleness is in scope when the repo tracks it: a planning doc
marked active whose linked tracker items are all closed, or that no open item
references, is a staleness finding under the repo's planning conventions; a
planning doc missing its required status metadata is a smaller finding of the
same kind.

Keep the pass proportionate to repo size: inspect directly by default. When
the surface is genuinely large, parallelize inspection and centralize
judgment: workers gather semantic evidence — claim-vs-source faithfulness,
contradictions, duplicates, stale live state, undefined terms, convention
drift, boundary violations — while the parent merges, dedupes, classifies,
ranks, and numbers findings. Workers never re-run structural checks; the
deterministic envelope is authoritative. Up to six workers per batch; merge
findings before launching another batch.

### 5. Audit Ubiquitous Language

Search active repo surfaces for domain-language drift:

- docs, PRDs, ADRs, and boot files;
- repo-local skills;
- open and in-progress tracker items, plus closed ones when current docs or
  active work still point to them as guidance;
- code comments and public identifiers when they carry domain meaning;
- filenames for active source/docs modules.

This audit is semantic, not string-only. Do not flag every occurrence of an
avoided word. Flag occurrences where the surrounding sentence, success
criterion, filename, code comment, or identifier instructs agents or code
toward the wrong domain concept.

Use these language-specific classifications:

- **canonical conflict**: an avoided or legacy term is used as if it were the
  canonical concept.
- **active-language drift**: active docs, tracker items, skills, boot files,
  filenames, or code comments point agents toward an obsolete mental model.
- **glossary gap**: an active PRD, tracker item, skill, or public code surface
  introduces a durable domain term not defined in the relevant glossary.
- **legacy alias**: an old term remains for search, history, frontmatter, or
  explicit anti-pattern explanation and does not instruct behavior. Usually do
  not report this unless it creates ambiguity.

For example, a PRD sentence warning against an old wrong model is valid; an
active tracker item instructing an owner in the avoided term as if canonical is
language drift.

### 6. Classify Findings

Use these categories:

- **repo drift**: the repo violates a cited rule.
- **doc drift**: docs contradict each other, describe a shape that no longer
  exists, or send agents toward the wrong behavior.
- **tool drift**: a checker encodes stale policy not backed by current docs.
- **ambiguous rule**: a rule is too unclear to enforce safely.
- **language drift**: active repo language contradicts the relevant glossary,
  uses avoided terms as canonical concepts, or introduces durable terms without
  a glossary entry.
- **heuristic note**: useful observation without a binding rule; keep these
  sparse.

Err toward fewer, stronger findings. Do not report style preferences,
speculative architecture ideas, or "nice to have" cleanup as lint failures.

### 7. Report In Chat

Return a compact numbered list. Number findings in one monotonically increasing
sequence across every report section; do not restart at `1` for Docs-Lint,
Findings, or Ubiquitous Language. Include severity (error/warning/note),
category, title, evidence path:line, cited rule path:line, and a proposed fix
direction. Use this shape:

```markdown
Mode: repo lint
Scope included: ...
Scope excluded: ...
Governance read: ...

## Docs-Lint
1. [warning][ambiguous rule] Title
   Evidence: path:line ...
   Proposed fix: ...

## Findings
2. [warning][doc drift] Title
   Evidence: path:line ...
   Rule: path:line ...
   Proposed fix: ...

## Ubiquitous Language
3. [warning][language drift] Title
   Evidence: path:line ...
   Rule: glossary path:line ...
   Proposed fix: ...

## Next Step
Reply `fix 1, 3`, `explain 2`, or `save report`.
```

If there are no findings, say so clearly and mention any areas not inspected.

## Optional Fix Phase

Only enter this phase after Anders explicitly selects numbered findings to fix.

Two fix classes with different latitude: **mechanical** fixes (repair a broken
link, backfill missing status metadata) are safe to apply directly once
selected; **semantic** fixes (rewriting a claim to match its source,
reconciling a contradiction, re-homing content) are always proposed with the
exact edit and confirmed before applying, even when selected by number.

Rules:

- Re-read the selected finding and affected files first.
- Apply only selected numbers.
- Keep edits small and in the ownership boundary of the finding.
- If the fix touches change-controlled files (`docs/`, `AGENTS.md`,
  `CLAUDE.md`), follow the repo's change-control rules.
- Report every non-trivial file write, move, or deletion.
- Run targeted verification for the changed area when useful.
- Do not automatically re-run a full lint unless Anders asks.

Ambiguous fixes require a question. Human-only/private areas are never guessed.
