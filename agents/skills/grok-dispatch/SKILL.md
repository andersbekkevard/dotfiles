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
  temporary working directory and Grok home, disables tools, subagents, and web
  search, and verifies grok.com authentication with API-key routing removed.
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

For a run that must survive the current session or join a multi-run wave, read
[the shared detached lifecycle](references/detached.md).
Prompt construction remains outside this skill in both lifecycles.
