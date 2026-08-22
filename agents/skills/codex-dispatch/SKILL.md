---
name: codex-dispatch
description: Run a ready prompt through Codex with an explicit access boundary.
disable-codex-model-invocation: true
---

# Codex dispatch

Invoke Codex from another harness. This skill owns model execution, access,
lifecycle, and result capture. It accepts a ready prompt file and does not
assemble or improve the prompt.

## Dispatch

Choose the access boundary independently of the prompt:

- `closed` (default): prompt-in/result-out. Codex exposes no hard tool-off
  switch, so the runner uses an isolated temporary directory, a read-only
  sandbox, ignored local config and rules, and a leading instruction to
  avoid tools. This is best-effort isolation, unlike Claude's hard-disabled
  closed mode. Native rollouts persist under the dispatch root, not
  `~/.codex/sessions/`.
- `agentic`: unrestricted execution with permission and sandbox bypass. Require
  an explicit `--root` as the starting directory, but do not treat it as a
  containment boundary. Selecting `agentic` authorizes unrestricted execution;
  task size or likely quality benefit does not select it implicitly.

Honor a model Anders names. Otherwise use `gpt-5.6-terra` with `high` effort.
When that default is not clearly suitable, read
[model routing](references/model-routing.md). Always pass model and effort
explicitly rather than inheriting them from local configuration.

Run the foreground procedure through the script:

```sh
SKILL_DIR="<directory containing SKILL.md>"

python3 "$SKILL_DIR/scripts/invoke.py" /absolute/path/prompt.md \
  --output /absolute/path/result.md \
  --access closed \
  --model gpt-5.6-terra \
  --effort high
```

For `agentic`, also pass `--root /absolute/repo`. The dispatch is complete when
the runner exits successfully and the output file is nonempty.

Delegated Codex rollouts live under `~/.local/state/agent-dispatch/codex/`.
The runner prints `Transcript: <absolute path>` for the parent rollout. Child
rollouts sit in the same `sessions/YYYY/MM/DD/` tree when Codex creates them.
`result.md` remains the handoff; inspect the transcript only for a debrief.
Native layout: [transcripts](references/transcripts.md).

For a run that must survive the current session or join a multi-run wave, read
[the shared detached lifecycle](references/detached.md).
Prompt construction remains outside this skill in both lifecycles.
