# Decision counsel

Use this procedure when a stronger model should give guidance, form a
direction, or test one, rather than merely process a file bundle.

## Reconstruct intent

Write `user-intent.md` from Anders's perspective. Reconstruct it from the whole
relevant conversation, not only the latest message. Use assistant turns to
resolve what Anders refers to and which proposals he accepted, rejected, or
corrected. The file should explain:

- why the work exists and what outcome Anders wants;
- the preferences or tensions shaping the decision;
- fixed constraints and settled choices; and
- the question or uncertainty that remains open.

Do not turn a topic into a final question Anders has not asked. Keep the
assembling agent's preferred direction and reasoning out of the intent file.

Write `user-anchors.md` as the evidence for that reconstruction. Include the
latest operative request, then add verbatim passages that carry the purpose,
constraints, corrections, rejections, uncertainty, or unusually meaningful
wording. Join passages plainly without message metadata. Include enough for the
receiving model to refine or reject the reconstruction, but omit repetition and
operational asides that do not affect the judgment.

The pair is complete when a model that has never seen the conversation can
explain why the work exists, what Anders wants, what shaped the current
question, and which parts are interpretation rather than his exact words.

## Compare both directions

When both views could materially change a consequential decision, freeze the
shared intent and evidence, then compose separate `propose` and `challenge`
prompts. Keep the requesting agent's direction inside the challenge prompt
only. This is two consultations, not another mode.

## Build the brief

Write a compact `brief.md` with the counsel question, decisive constraints,
and genuine uncertainties.

For `propose`, add only agreed premises. Keep the requesting agent's preferred
direction outside the packet.

For `challenge`, add:

- the proposed direction;
- a causal case separating observed facts, assumptions, mechanism, expected
  consequences, verification signals, and falsifiers;
- the strongest live alternative, why it currently loses, and what would make
  it win; and
- the strongest contrary evidence.

The challenge brief is complete when every link in the causal case is explicit
enough for the receiving model to reject independently.

Add only the evidence the judgment needs:

- `repo-model.md`: a decision-local map of relevant modules, interfaces,
  invariants, current behavior, verification state, and known drift, with
  provenance for material claims.
- `document`: exact source text whose wording matters.
- `excerpt`: exact implementation or test lines whose behavior matters.
- `redacted-document`: a sanitized authored copy of sensitive source text,
  labeled with its origin and redactions.
- `digest`: a provenance-rich synthesis of broad material.

Use typed authority. User intent owns purpose and desired outcome. The brief
owns the requesting agent's working model, proposed direction, and causal case.
Live code, data, runtime observations, and tests own behavior. Applicable agent
instructions own rules. ADRs and docs explain rationale or prior intent to the
extent they remain current. State drift instead of silently resolving it.

Include evidence when its absence could change the receiving model's judgment.
Preserve it exactly when paraphrase could distort that judgment. In `challenge`
mode, include the strongest source that cuts against the proposed direction
when one exists.

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
