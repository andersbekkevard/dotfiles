---
name: claude-dispatch
description: Run a ready prompt through Claude Code with an explicit access boundary.
disable-model-invocation: true
disable-codex-model-invocation: false
---

# Claude dispatch

Invoke Claude Code from another harness. This skill owns model execution,
access, lifecycle, and result capture. It accepts a ready prompt file and does
not assemble or improve the prompt.

## Dispatch

Unset `ANTHROPIC_API_KEY` before checking Claude auth so the Max subscription wins.

Choose the access boundary independently of the prompt:

- `closed` (default): prompt-in/result-out. The runner uses an isolated
  temporary working directory and hard-disables built-in and MCP tools.
  Native sessions persist under the dispatch root, not `~/.claude/projects/`.
- `agentic`: unrestricted built-in tools with permission bypass. Require an
  explicit `--root` as the starting directory, but do not treat it as a
  containment boundary. Selecting `agentic` authorizes unrestricted tool use;
  task size or likely quality benefit does not select it implicitly.

Run the foreground procedure through the script so subscription authentication,
provider-environment isolation, and atomic output stay consistent:

```sh
SKILL_DIR="<directory containing SKILL.md>"

python3 "$SKILL_DIR/scripts/invoke.py" /absolute/path/prompt.md \
  --output /absolute/path/result.md \
  --access closed \
  --model claude-fable-5 \
  --effort high
```

The runner stages only Claude subscription material into its private run home.
On macOS it accepts Claude Code's native Keychain login as well as the legacy
`.credentials.json` file; other platforms use the file-backed login.

For `agentic`, also pass `--root /absolute/repo`. Honor a model or effort Anders
names; otherwise use the script defaults. The dispatch is complete when the
runner exits successfully and the output file is nonempty.

Delegated Claude sessions live under `~/.local/state/agent-dispatch/claude/`.
The runner prints `Transcript: <absolute path>` for the parent session.
Subagent transcripts and `tool-results/` sit beside that parent when Claude
creates them. `result.md` remains the handoff; inspect the transcript only for
a debrief. Native layout: [transcripts](references/transcripts.md).

For a run that must survive the current session or join a multi-run wave, read
[the shared detached lifecycle](references/detached.md).
Prompt construction remains outside this skill in both lifecycles.
