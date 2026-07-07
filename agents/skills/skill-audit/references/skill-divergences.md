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

### wayfinder

Accepted 2026-07-06: keep the remote tracker-backed wayfinding concepts, but preserve the local/project rule that trackers hold coordination and short indexes, not fleshed-out ideas. For project/beads specifically, do not use upstream `wayfinder:*` labels; keep project's workstream label policy and store wayfinder type/mode as body fields. Long answers should live in linked repo artifacts, with concise bead comments and close reasons.
