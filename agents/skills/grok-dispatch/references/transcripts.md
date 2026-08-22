# Grok dispatch transcripts

`$XDG_STATE_HOME/agent-dispatch/grok/` is the persistent dispatch `GROK_HOME`
for closed and agentic runs (`~/.local/state/agent-dispatch/grok/` when
`XDG_STATE_HOME` is unset). Only subscription auth is staged into it.

The runner assigns `--session-id`. The parent session is:

```text
sessions/<urlencoded-cwd>/<session-id>/
sessions/<urlencoded-cwd>/<session-id>/summary.json
```

The printed path is `summary.json` when that file exists, otherwise the session
directory. Child sessions live in the same `sessions/<urlencoded-cwd>/` tree.
The parent records each child under `subagents/<child-id>/`, with
`meta.json` naming `parent_session_id` and `child_session_id`.
