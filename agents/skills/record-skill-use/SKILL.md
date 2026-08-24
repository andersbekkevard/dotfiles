---
name: record-skill-use
description: Record one real skill use, with or without feedback, as durable evidence.
disable-model-invocation: true
---

# Record skill use

Capture one recent skill use for later review. Leave the skill unchanged.

## Identify the use

Infer the primary skill from the current conversation unless Anders names it.
List other skills that affected the result as related skills. If the primary
skill or the relevant use is unclear, ask one question before writing.

Feedback is optional. Text Anders supplies with this invocation is feedback
when it evaluates or corrects the result. When he supplies no feedback, record
an ungraded example. No feedback does not mean approval.

## Prepare the evidence

Write one `evidence.md` containing:

- Anders's skill-invoking message verbatim;
- the smallest reconstruction of earlier history needed to recover his intent,
  with verbatim anchors where wording matters;
- the result and relative links to any copied artifacts;
- Anders's feedback verbatim, or an explicit statement that no feedback was
  provided and the use is ungraded; and
- a labeled note for attribution uncertainty or model interpretation.

A packet is sufficient when a later agent can understand what Anders wanted,
what the skill produced, and why the use was recorded. Include a session or
transcript locator when available. Copy a transient artifact when the evidence
depends on it. For code work, prefer a focused diff or commit reference over a
repository copy.

## Create the packet

Resolve this skill's directory from its `SKILL.md`, then run the packager.
Harness, model, session, and transcript values are optional labels. The script
does not read or sanitize transcripts.

```bash
python3 "$SKILL_DIR/scripts/record_skill_use.py" create \
  --skill <primary-skill> \
  --evidence /absolute/path/evidence.md \
  [--related-skill <skill>] \
  [--harness <name>] [--model <name>] [--session-id <id>] \
  [--source-transcript <locator>] \
  [--feedback-provided] \
  [--artifact /absolute/path/to/file]
```

Pass `--feedback-provided` only when Anders gave explicit feedback. The script
creates `agents/skill-uses/<skill>/<UTC timestamp>/`, copies flat attachments,
writes `metadata.json`, hashes every evidence file, validates the packet, and
prints its absolute path.

## Commit and push now

The evidence root is encrypted with `git-crypt`. Before creating the packet,
check that the current branch has an upstream and that pushing will not publish
pre-existing local commits. Ask Anders if either condition fails.

Once the script returns a valid packet, commit it immediately. Commit only that
timestamp directory, even when unrelated changes are dirty or staged:

```bash
git add -- "$PACKET"
git commit --only -m "skill-use: <skill> @ <UTC timestamp>" -- "$PACKET"
```

Inspect the commit's file list and confirm every path is inside `$PACKET`.
Then push immediately. Do not batch the packet with later work or leave it for
a later push.

Done when the packet validates, its commit contains only that packet, and the
commit is on the upstream remote.
