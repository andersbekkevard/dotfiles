---
name: lint
description: Read-only audit of a repo's own policy, routes, current claims, archives, and checkers.
disable-model-invocation: true
---

# Repo Lint

Audit the current checkout against its own documented contract. The repo owns
policy; this skill owns evidence collection and classification.

`/lint` is read-only. Report drift and propose a repair direction. Do not edit
files, update trackers, generate saved reports, or create policy.

## Evidence contract

Every finding needs current evidence, the repository owner it violates, the
consequence, and a proposed repair direction. If no repository rule supports a
concern, label it `review`, not a violation. If owners disagree, report that
disagreement before applying either rule.

## Run

### 1. Establish owners and scope

Read the applicable root and nested instructions, the repository's rule-owner
index, current-work register, planning/tracker contracts, and checker docs.
Build a working table:

`surface | owner | current-state authority | required routes | archive meaning | checker`

Derive every entry from repository files. Exclude human-only areas,
dependencies, generated output, caches, vendored code, and external repos unless
an owner includes them.

### 2. Docs-lint first

Audit the specification before using it against content:

- **ownership collision** — two current surfaces both claim canonical ownership
  of the same rule, fact, behavior, or lifecycle state;
- **checker drift** — a checker, scope, severity, vocabulary, or output contract
  differs from its owner.

A pointer or declared projection is not another owner. When a docs-lint finding
undermines a checker result, report the docs finding and mark the dependent
content result `invalidated`.

### 3. Run deterministic evidence

Discover read-only validators from repo docs, scripts, CI, and local owners. Run
the documented commands and retain structured output when available.

Checker output is authoritative for what the checker implemented, not for
policy. Do not manually re-derive a coherent deterministic check. A tool
exception is a tool finding, not a clean content result.

### 4. Inspect uncovered seams

Check only repository-defined surfaces for:

- **dead pointer** — a required path, link, anchor, identifier, tracker
  reference, owner, or checker citation does not resolve;
- **stale current claim** — present-tense behavior, status, roster, priority, or
  operating guidance is contradicted or has outlived its stated horizon;
- **route incompleteness** — an item is absent from a route its owner requires;
- **archive leakage** — an active surface consumes historical or superseded
  material as current instruction;
- **boundary drift** — implementation crosses a seam assigned to another owner.

Dated history, provenance, and clearly labelled historical links are not stale
claims or archive leakage.

### 5. Preserve repository planning semantics

Discover the repository's live planning root, effort interface, detailed-state
owner, archive boundary, and any paused or historical tracker. Do not assume a
PRD class, issue tracker, or handoff lifecycle exists merely because another
repository uses one.

Test only the transitions and cross-references the current planning owner
states. Verify that active work is reachable from the declared root, detailed
state has one owner, and archived artifacts do not leak into current authority.
Do not infer execution, acceptance, status, or required artifacts from a plan's
existence. Do not require an index to restate ticket bodies. When planning
surfaces disagree, report the exact seam; do not invent or select a lifecycle
model.

### 6. Report in chat

Use one monotonically increasing finding sequence:

```markdown
# Lint Report
Mode: ...
Scope: ...
Owners read: ...
Checks run: ...

## A. Docs Lint
1. [severity][ownership collision | checker drift] Title
   Evidence: path:line
   Rule: path:line
   Consequence: ...
   Proposed direction: ...

## B. Repo Lint
2. [severity][dead pointer | stale current claim | route incompleteness | archive leakage | boundary drift] Title
   Evidence: path:line
   Rule: path:line
   Consequence: ...
   Proposed direction: ...

## Unverified or excluded
...
```

Use repository-defined severity where one exists; otherwise use `review`. If no
finding survives docs-lint invalidation, say so clearly.

Repairs require a separately authorized task. A request to lint and repair still
produces the report first; apply only the repairs the user then selects.
