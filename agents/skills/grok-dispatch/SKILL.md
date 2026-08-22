---
name: grok-dispatch
description: Run a ready prompt through Grok with an explicit access boundary.
---

# Grok dispatch

Invoke Grok from another harness. This skill owns model execution, access,
lifecycle, and result capture. It accepts a ready prompt file and does not
assemble or improve the prompt.

## Dispatch

Choose the access boundary independently of the prompt:

- `closed` (default): prompt-in/result-out. The runner uses an isolated
  temporary working directory, disables tools, subagents, and web search, and
  verifies grok.com authentication with API-key routing removed. Native
  sessions persist under the dispatch root, not `~/.grok/sessions/`.
- `agentic`: unrestricted tools and subagents with permission bypass. Require
  an explicit `--root` as the starting directory, but do not treat it as a
  containment boundary. Selecting `agentic` authorizes unrestricted execution;
  task size or likely quality benefit does not select it implicitly.

Run the foreground procedure through the script:

```sh
SKILL_DIR="<directory containing SKILL.md>"

python3 "$SKILL_DIR/scripts/invoke.py" /absolute/path/prompt.md \
  --output /absolute/path/result.md \
  --access closed \
  --model grok-4.6 \
  --effort high
```

For `agentic`, also pass `--root /absolute/repo`. Honor a model or effort Anders
names; otherwise use the script defaults. The dispatch is complete when the
runner exits successfully and the output file is nonempty.

Delegated Grok sessions live under `~/.local/state/agent-dispatch/grok/`.
The runner prints `Transcript: <absolute path>` for the parent session
directory or its `summary.json`. Child sessions stay discoverable from that
parent through `subagents/<child-id>/`. `result.md` remains the handoff;
inspect the transcript only for a debrief. Native layout:
[transcripts](references/transcripts.md).

In Codex, keep a long Grok invocation inside a harness-owned execution session:
start the foreground command with a short yield, retain the returned session
ID, and poll that session until it exits. This is the proven lifecycle. An
OS-detached child launched from a short Codex command cell can disappear with
an empty log even after `setsid`.

Outside a harness with persistent execution sessions, or when a run must
outlive its owning session, read
[the shared detached lifecycle](references/detached.md).
Prompt construction remains outside this skill in both lifecycles.
