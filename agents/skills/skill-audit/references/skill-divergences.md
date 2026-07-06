# Skill Source Divergences

This is the durable ledger for accepted local divergences from tracked upstream
skills. During a skill audit, read this file before classifying drift or
reporting recommendations.

Use this file for decisions Anders has accepted as local policy. Do not add
temporary audit observations, speculative preferences, or one-off diff notes.
If a future upstream change conflicts with an accepted divergence here, report
the conflict against this ledger instead of asking Anders to re-decide the same
baseline issue.

## Audit Handling

- If drift exactly matches a documented local divergence, treat it as accepted
  local behavior and do not report it as material.
- If upstream adds a useful idea near a documented divergence, recommend porting
  the specific idea without replacing the accepted local behavior.
- If upstream removes or contradicts an accepted local behavior, report it as an
  intent conflict only when the conflict is newly relevant to the current diff.
- Keep `agents/skill-sources.toml` as the source map. Use this ledger for the
  durable reason why a local divergence should survive.

## Accepted Divergences

### autoreview

Local policy:

- Codex review is the default closeout path.
- Thermonuclear review is a first-class Anders-facing mode. It uses the same
  helper with `thermo-nuclear-code-quality-review/SKILL.md` as a rubric prompt.
- Additional engines, panels, helper hardening, and upstream review mechanics
  may be ported, but they must not erase the two normal local modes: Codex
  review and thermonuclear review.

Audit handling:

- Ignore upstream drift that only removes local Codex-default or thermonuclear
  mode wording.
- Port upstream helper fixes and safety hardening when they generalize.
- Preserve the local description and `Review Modes` section unless Anders
  explicitly changes the local review policy.

### create-cli

Local policy:

- Reference paths should stay relative to this repo's skill layout.

Audit handling:

- Ignore upstream path changes that point at the upstream source checkout
  layout instead of the local skill directory.
- Port CLI guidance changes only when they improve the local skill without
  breaking local path resolution.

### define-goal

Local policy:

- A private goal is not a durable work tracker.
- In bead-backed work, durable tracker state must be read and claimed before
  creating a private goal.
- Goal-fuzz handoff, false-pass checks, and loaded-term mechanism proof are
  intentional local hardening.

Audit handling:

- Ignore upstream simplifications that remove bead/tracker gating or false-pass
  hardening.
- Port upstream wording only when it sharpens goal definition without weakening
  durable tracker precedence.

### fix-merge-conflicts

Local policy:

- The local skill name is `fix-merge-conflicts`; upstream uses
  `resolving-merge-conflicts`.
- The local version is intentionally condensed and conservative.
- Do not make automatic staging, committing, or rebase continuation a blanket
  rule for local conflict resolution.

Audit handling:

- Ignore upstream drift that only renames the skill or expands it into a less
  conservative finish-the-merge workflow.
- Consider porting narrow ideas such as reading commits, PRs, or issues to
  recover conflict intent.

### humanizer

Local policy:

- Anders-specific trigger phrasing may stay when it is more useful than
  upstream metadata.

Audit handling:

- Keep local trigger wording unless upstream clearly improves invocation.
- Port concrete prose-quality rules when they are generally useful.

### thermo-nuclear-code-quality-review

Local policy:

- The local description may remain terser because this skill is normally
  user-invoked or passed as an autoreview rubric.

Audit handling:

- Ignore upstream description expansion unless it improves local discovery
  without adding noise.
- Port substantive rubric changes.

### wayfinder

Local policy:

- Local wayfinder wording is meaningfully adapted.
- Upstream ideas should be ported semantically, not synchronized wholesale.

Audit handling:

- Do not recommend direct replacement just because upstream has newer tracker
  mechanics or renamed sections.
- Recommend specific upstream concepts only when they fit the local tracker and
  planning conventions.
