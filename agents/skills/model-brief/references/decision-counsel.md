# Decision counsel

Use this procedure when a stronger model should form or test judgment, rather
than merely answer from a file bundle.

## Mode

- `guidance`: answer a bounded question directly.
- `propose`: direction remains open. Supply the North Star, evidence,
  constraints, and agreed premises while withholding the requesting agent's
  preferred direction.
- `challenge`: a direction exists. Supply it with its causal case, strongest
  live alternative, contrary evidence, verification signals, and falsifiers.

When no mode is named, ask whether the current agent would proceed with a
specific direction if the consultation were unavailable. A yes means
`challenge`; a no means `propose`. Loose options or ambiguity remain
`propose`.

## Surfaces

Write a compact `brief.md` with the counsel question, decisive constraints,
genuine uncertainties, and the mode-specific material above.

Add only the surfaces the judgment needs:

- `user-intent.md`: the purpose and desired outcome reconstructed from the
  whole conversation, written from the user's perspective.
- `user-anchors.md`: a few verbatim user passages whose wording the
  reconstruction may flatten. Use only with `user-intent.md`.
- `repo-model.md`: a decision-local map of relevant modules, interfaces,
  invariants, current behavior, verification state, and known drift, with
  provenance for material claims.
- `document`: exact source text whose wording matters.
- `excerpt`: exact implementation or test lines whose behavior matters.
- `redacted-document`: a sanitized authored copy of sensitive source text,
  labeled with its origin and redactions.
- `digest`: a provenance-rich synthesis of broad material.

Typed authority matters: user intent owns purpose; live code, data, runtime
observations, and tests own behavior; applicable agent instructions own rules;
ADRs and docs explain rationale or prior intent to the extent they remain
current. State drift instead of silently resolving it.

## Compose

```sh
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/model-brief.XXXXXX")
SKILL_DIR="<directory containing SKILL.md>"

uv run "$SKILL_DIR/scripts/compose_prompt.py" \
  --root . \
  --mode challenge \
  --brief "$WORK_DIR/brief.md" \
  --user-intent "$WORK_DIR/user-intent.md" \
  --user-anchors "$WORK_DIR/user-anchors.md" \
  --repository-model "$WORK_DIR/repo-model.md" \
  --document docs/decision.md \
  --excerpt src/planner.rs:118-205 \
  --digest "$WORK_DIR/runtime-digest.md" \
  --output "$WORK_DIR/prompt.md" \
  --metadata-output "$WORK_DIR/prompt.json"
```

Omit unused flags. Repeat evidence flags as needed. Token counts are telemetry,
not a target; stop when another item would add no constraint, observed behavior,
uncertainty, or plausible alternative.
