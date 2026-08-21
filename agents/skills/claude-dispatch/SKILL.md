---
name: claude-dispatch
description: Run a ready prompt through Claude Code with an explicit access boundary.
disable-model-invocation: true
---

# Claude dispatch

Invoke Claude Code from another harness. This skill owns model execution,
access, lifecycle, and result capture. It accepts a ready prompt file and does
not assemble or improve the prompt.

## Dispatch

Choose the access boundary independently of the prompt:

- `closed` (default): prompt-in/result-out. The runner uses an isolated
  temporary working directory and hard-disables built-in and MCP tools.
- `agentic`: ordinary coding-agent access inside an explicit `--root`, with
  safe mode and normal built-in tools.
- `unrestricted`: default tools plus permission bypass inside an explicit
  `--root`. Use only when Anders directly authorizes unrestricted tool use;
  task size or likely quality benefit is not authorization.

Run the foreground procedure through the script so subscription authentication,
provider-environment isolation, atomic output, and the private run archive stay
consistent:

```sh
SKILL_DIR="<directory containing SKILL.md>"

python3 "$SKILL_DIR/scripts/invoke.py" /absolute/path/prompt.md \
  --output /absolute/path/result.md \
  --access closed \
  --model claude-fable-5 \
  --effort high
```

For `agentic` or `unrestricted`, also pass `--root /absolute/repo`. Honor a
model or effort Anders names; otherwise use the script defaults. The dispatch
is complete when the runner exits successfully and the output file is nonempty.

For a run that must survive the current session or join a multi-run wave, read
[the shared detached lifecycle](../../references/model-dispatch-detached.md).
Prompt construction remains outside this skill in both lifecycles.
