---
name: fable-counsel
description: Propose an independent direction with Fable while direction is open, or challenge a formed direction, when framing, architecture, tradeoffs, or elegance need second judgment.
disable-model-invocation: true
disable-codex-model-invocation: false
---

# Fable Counsel

Ask Fable for a considered second opinion. Sol owns the decision; Fable supplies
counsel.

## Choose mode

Orient first, using Terra or Luna where useful, then choose:

- `propose`: use while direction remains open. Give Fable the North Star,
  evidence, constraints, and agreed premises; Sol's candidate direction and
  rationale remain outside the packet. The counsel is complete when Fable has
  recommended an independent direction, named the decisive premise, and stated
  what would change its judgment.
- `challenge`: use after Sol forms a direction. Also give Fable the favored
  direction, compact rationale, strongest live alternative, genuine
  uncertainties, and strongest contrary evidence. The counsel is complete when
  Fable has given a verdict, surfaced the strongest correction or alternative,
  and said why when the direction remains strongest.

Honor a mode Anders requests explicitly or in ordinary language. Otherwise ask:
if Fable were unavailable, would Sol proceed with a specific direction now? A
yes selects `challenge`; a no selects `propose`. Options, loose ideas, and
uncommitted leanings leave direction open. Ambiguity selects `propose`, because
`challenge` requires a target. Treat decisions Anders has fixed as constraints;
apply counsel to the open direction beneath them.

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
constraints, and genuine uncertainties. For `propose`, add agreed premises. For
`challenge`, add the proposed direction and compact rationale, plus the
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
material. For `challenge`, include the strongest source that cuts against the
proposed direction when one exists.

## Run counsel

Use a fresh work directory so source text goes from disk into the packet without
entering Sol's context:

```sh
COUNSEL_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fable-counsel.XXXXXX")
echo "$COUNSEL_DIR"
```

Write `brief.md` there. Add `user-intent.md` when user-directed intent bears on
the decision, and `user-anchors.md` only with it. The runner discovers those
names and writes `prompt.md` and `fable.md` in the same directory:

Run from the repository root with repo-relative evidence paths. This section is
the complete invocation contract. Treat the runner as opaque during counsel;
open `scripts/` only to change or audit the runner itself.

```sh
SKILL_DIR="<directory containing this SKILL.md>"
COUNSEL_DIR="<directory returned by mktemp>"
uv run "$SKILL_DIR/scripts/counsel.py" "$COUNSEL_DIR" \
  --mode propose \
  --doc docs/prd/feature.md \
  --excerpt src/planner.rs:118-205 \
  --redacted "$COUNSEL_DIR/redacted-auth.md" \
  --digest "$COUNSEL_DIR/terra-runtime-digest.md"
```

Pass the selected mode explicitly as `--mode propose` or `--mode challenge`;
the runner has no mode default. Repeat evidence flags as needed. `high` effort
is the default; use `--effort low|medium|high|xhigh|max` when warranted. The
runner reports token telemetry without printing packet contents, requires
Claude Code subscription authentication, strips API and cloud-provider routing,
and invokes Fable from an isolated neutral directory with tools disabled. The
packet is complete when every item earns its fidelity and Fable can form an
informed view without repository access.

When both views could materially change a consequential decision, freeze the
shared evidence and run two consultations in separate work directories. Keep
Sol's direction and rationale inside the `challenge` packet only, run `propose`
and `challenge` concurrently, then integrate both notes. This is two isolated
consultations, not a third mode.

Read the note, reconsider the direction, and continue with the best view. Mention
the consultation when it materially changed or sharpened the work. When counsel
contradicts a fact you directly observed, recheck the source and keep factual
authority with the evidence; use Fable for judgment. If explicitly requested
counsel fails, surface the failure; preserve Sol's existing work.
