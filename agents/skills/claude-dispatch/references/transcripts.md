# Claude dispatch transcripts

`$XDG_STATE_HOME/agent-dispatch/claude/<run-id>/` is the isolated
`CLAUDE_CONFIG_DIR` for one run (`~/.local/state/agent-dispatch/claude/` when
`XDG_STATE_HOME` is unset). Only subscription material is staged into it.

The runner assigns `--session-id` and resolves the parent as the unique file

```text
projects/<cwd-slug>/<session-id>.jsonl
```

inside that run home. Claude sanitizes the working directory into `<cwd-slug>`;
the dispatcher does not guess the slug or pick the newest session. Subagent
transcripts live in `projects/<cwd-slug>/<session-id>/subagents/`. Tool payloads
live in `projects/<cwd-slug>/<session-id>/tool-results/`.
