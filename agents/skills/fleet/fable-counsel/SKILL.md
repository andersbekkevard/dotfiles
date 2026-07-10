---
name: fable-counsel
description: Fable counsel as a cold read before Sol chooses direction or plan counsel after Sol forms one, when framing, architecture, tradeoffs, or elegance need independent judgment.
disable-model-invocation: true
disable-codex-model-invocation: false
---

# Fable Counsel

Ask Fable for a considered second opinion. Sol owns the decision; Fable supplies
counsel.

## Choose posture

Orient first, using Terra or Luna where useful, then choose:

- `cold-read`: use while direction itself is the question. Be ready to explain
  the North Star, evidence, constraints, and agreed premises; give Fable no Sol
  proposal or rationale.
- `plan-counsel` (default): use after forming a direction worth testing. Also
  explain the favored direction, compact rationale, strongest live alternative,
  and genuine uncertainties.

Sol's brief may synthesize worker findings without making Sol reread every
source.

For exploration likely to feed counsel, ask the worker to end with a counsel
contribution: a compact synthesis with file and line provenance, plus any source
whose exact wording Fable should see.

## Compose the packet

Write a compact user-intent file that reconstructs the North Star from the whole
task conversation. Use assistant turns as reference-resolution evidence for what
the user refers to and what they accepted, rejected, or corrected. Write from the
user's perspective: why the work exists, the outcome they want, the values or
tensions shaping it, decisive constraints, and unresolved choices.

Write a separate user-anchors file containing only the few verbatim user
passages whose language the reconstruction may flatten, including the latest
operative request. Join passages plainly without message metadata. Keep Sol's
reasoning in the brief.

The pair is complete when an advisor who has never seen the
conversation can explain why the work exists, what outcome the user wants, what
shapes the decision, and what is being decided now.

Write a natural-language brief with the goal, counsel question, decisive
constraints, and genuine uncertainties. For a cold read, add agreed premises.
For plan counsel, add the proposed direction and compact rationale, plus the
strongest live alternative and what would make it win. Match each context item
to the fidelity the decision needs:

- `document`: exact source text whose wording matters, such as a PRD, plan, ADR,
  contract, or short specification;
- `excerpt`: an exact implementation or test range whose behavior matters;
- `redacted-document`: a sanitized copy of source text, headed by its original
  path and the redactions made, when direct inclusion trips secret scanning;
- `digest`: a Terra, Luna, or Sol synthesis of broad material, with provenance
  retained in the digest text.

Choose contents by judgment; token counts are telemetry, not targets. Stop when
another item would not add a constraint, observed behavior, uncertainty, or
plausible alternative.

Use typed authority: user intent owns purpose and desired outcome; Sol's brief
owns Sol's working model, proposed direction, and rationale; live code, data,
runtime observations, and tests own behavior; applicable `AGENTS.md` owns rules;
ADRs and docs explain rationale or prior intent to the extent they remain
current. State known drift or contradiction in the brief instead of silently
resolving it in favor of the written artifact.

Include an item when its absence could change Fable's judgment; preserve it
exactly when paraphrase could distort that judgment. Omit adjacent and duplicate
material. For plan counsel, include the strongest source that cuts against the
proposed direction when one exists.

Use the composer so appended source text goes directly from disk into the prompt
file instead of entering Sol's context:

```sh
COUNSEL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fable-counsel.XXXXXX")
echo "$COUNSEL_DIR"
```

Record the returned directory and write the brief and any worker digests there.
Then compose the packet:

```sh
SKILL_DIR="<directory containing this SKILL.md>"
COUNSEL_DIR="<directory returned by mktemp>"
uv run "$SKILL_DIR/scripts/compose_packet.py" \
  --root "$PWD" \
  --posture plan-counsel \
  --user-intent "$COUNSEL_DIR/user-intent.md" \
  --user-anchors "$COUNSEL_DIR/user-anchors.md" \
  --brief "$COUNSEL_DIR/brief.md" \
  --document docs/prd/feature.md \
  --excerpt src/planner.rs:118-205 \
  --redacted-document "$COUNSEL_DIR/redacted-auth.md" \
  --digest "$COUNSEL_DIR/terra-runtime-digest.md" \
  --output "$COUNSEL_DIR/prompt.md"
```

`plan-counsel` is the default; select `cold-read` when direction is still open.
`--user-intent` is optional when no user-directed intent bears on the decision;
`--user-anchors` is optional and requires it. Repeat context flags as needed.
The command reports paths and token weights without printing packet contents.
The packet is complete when every item earns its fidelity and Fable can form an
informed view without repository access.

## Ask Fable

Use Claude Code subscription authentication, never an Anthropic API key or cloud
provider. Before execution, run the token-free auth check below and require
`authMethod: claude.ai` plus a non-empty `subscriptionType`. If either check
fails, stop instead of invoking Fable:

```sh
env -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_BASE_URL \
  -u CLAUDE_CODE_USE_BEDROCK \
  -u CLAUDE_CODE_USE_VERTEX \
  -u CLAUDE_CODE_USE_FOUNDRY \
  claude auth status | \
  jq -e '.loggedIn == true and .authMethod == "claude.ai" and (.subscriptionType | type == "string" and length > 0)' \
  >/dev/null
```

Run from a neutral directory with the same sanitized environment and with
project customizations and tools disabled. Default to `high`; Codex may set
`FABLE_COUNSEL_EFFORT` to `low`, `medium`, `high`, `xhigh`, or `max` when the
consultation warrants another level:

```sh
COUNSEL_DIR="<directory returned by mktemp>"
FABLE_COUNSEL_EFFORT="${FABLE_COUNSEL_EFFORT:-high}"
(cd "${TMPDIR:-/tmp}" && env \
  -u ANTHROPIC_API_KEY \
  -u ANTHROPIC_AUTH_TOKEN \
  -u ANTHROPIC_BASE_URL \
  -u CLAUDE_CODE_USE_BEDROCK \
  -u CLAUDE_CODE_USE_VERTEX \
  -u CLAUDE_CODE_USE_FOUNDRY \
  claude \
  --safe-mode \
  --strict-mcp-config \
  --disallowedTools 'mcp__*' \
  --tools '' \
  --print \
  --no-session-persistence \
  --output-format text \
  --model claude-fable-5 \
  --effort "$FABLE_COUNSEL_EFFORT" \
  < "$COUNSEL_DIR/prompt.md" \
  > "$COUNSEL_DIR/fable.md")
test -s "$COUNSEL_DIR/fable.md"
```

Read the note, reconsider the direction, and continue with the best view. Mention
the consultation when it materially changed or sharpened the work. When counsel
contradicts a fact you directly observed, recheck the source and keep factual
authority with the evidence; use Fable for judgment. If explicitly requested
counsel fails, surface the failure; preserve Sol's existing work.
