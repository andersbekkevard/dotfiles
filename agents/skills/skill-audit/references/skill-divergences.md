# Skill Source Divergences

This is the durable ledger for accepted local divergences from tracked upstream
skills. During a skill audit, read this file before classifying drift or
reporting recommendations.

Use this file only for decisions Anders has explicitly accepted as local
policy. Do not promote `agents/skill-sources.toml` preserve notes, prior audit
recommendations, temporary observations, inferred preferences, or one-off diff
notes into this ledger. An entry belongs here only after Anders says to durably
ignore, keep, or prefer a divergence.

## Audit Handling

- If drift exactly matches a documented local divergence, treat it as accepted
  local behavior and do not report it as material.
- If upstream adds a useful idea near a documented divergence, recommend porting
  the specific idea without replacing the accepted local behavior.
- If upstream removes or contradicts an accepted local behavior, report it as an
  intent conflict only when the conflict is newly relevant to the current diff.
- Keep `agents/skill-sources.toml` as the source map. Use this ledger for the
  durable reason why a local divergence should survive.
- If this file has no entry for a skill, do not infer one. Report drift using
  the normal semantic audit rubric.

## Accepted Divergences

### autoreview

Accepted 2026-07-25: keep the upstream autoreview runner, security hardening,
engine-isolation rules, tests, and normal P0-only closeout default current.
Preserve thermonuclear review as an Anders-facing mode by composing the local
`thermo-nuclear-code-quality-review` rubric with the upstream helper and
explicitly widening that mode to `--max-priority P3`. Keep the local hardening
fixes that reject lexically repo-local output paths before symlink resolution
and enforce `--require-finding` against the final priority-filtered report.
Also inspect same-name secret-assignment call arguments before granting the
self-reference exemption so literal arguments remain detectable without
rejecting empty or reference-only calls. Retain these fixes until upstream
incorporates equivalent behavior. Keep credentialed URI test fixtures split
across source literals so the imported hardening corpus preserves its runtime
coverage without blocking autoreview's own TruffleHog preflight.

### visual-plan

Accepted 2026-07-25: preserve the installed local-files mode signal and evaluate
it before hosted connector discovery. A local-only installation must not upload
plan content merely because the environment variable is absent.

### wayfinder

Accepted 2026-07-06: keep the remote tracker-backed wayfinding concepts, but preserve the local/project rule that trackers hold coordination and short indexes, not fleshed-out ideas. For project/beads specifically, do not use upstream `wayfinder:*` labels; keep project's workstream label policy and store wayfinder type/mode as body fields. Long answers should live in linked repo artifacts, with concise bead comments and close reasons.

### mattpocock/skills — beads-port family (2026-07-07)

Anders explicitly decided to port the upstream engineering flow onto beads as
the tracker substrate. For `to-prd`, `to-issues`, `implement`, and
`review-changes` (upstream `code-review`), every issue-tracker touchpoint
(GitHub/`docs/agents/issue-tracker.md`/triage labels) is intentionally replaced
with beads (`br`) mechanics, and `setup-matt-pocock-skills` references are
removed. Upstream changes to those tracker touchpoints are accepted local
divergence; port upstream changes to the surrounding method (seam sketching,
slicing rules, review axes) normally.

`review-changes` is deliberately renamed from upstream `code-review` (collides
with the Claude Code builtin) and deliberately user-invoked.

Update 2026-07-09: `review-changes` is archived to `agents/archive/` and no
longer tracked — builtin /code-review, codex review, and autoreview cover
review; the port over-encoded it. Do not report upstream `code-review` as a
gap in future audits.

Update 2026-07-11: upstream `to-prd`/`to-issues` were replaced locally by the
current `to-spec`/`to-tickets` pair. Preserve upstream wording and behavior
except for the beads substrate adaptations: `to-spec` publishes its full
Markdown with high-level `## Success Criteria` as an organizational umbrella
epic description; `to-tickets` publishes child epics with native
parent/blocking edges and executable `## Success Criteria`; tracker
setup/triage assumptions and the `/implement` pointer are removed. Upstream
test-seam negotiation and fresh-context sizing are expressly retained.

### mattpocock/skills — deliberate non-adoptions (2026-07-07)

Anders explicitly decided NOT to adopt the following upstream skills. Do not
report them as gaps in future audits; revisit only if Anders asks.

- `engineering/triage`, `engineering/ask-matt`,
  `engineering/setup-matt-pocock-skills` — built for external
  reporters/PRs and Matt's tracker scaffolding; solo repos + beads make them
  moot.
- `engineering/research` — overlaps deep-research and codex-dispatch delegation.
- `productivity/grill-me` — local `grilling` is already directly invocable.
- `productivity/teach`, `misc/*` (git-guardrails, setup-pre-commit,
  migrate-to-shoehorn, scaffold-exercises), `in-progress/claude-handoff`,
  `in-progress/loop-me`, `in-progress/wizard`, `personal/*`, `deprecated/*` —
  reviewed 2026-07-07 and declined (wrong fit, environment plumbing we do
  differently, or superseded by local skills).

Watch (no local copy): `in-progress/writing-beats`, `writing-fragments`,
`writing-shape` — a tasteful explore/exploit prose trio, still in-progress
upstream. Revisit if Anders starts writing articles with agents.
