# Codex dispatch transcripts

`$XDG_STATE_HOME/agent-dispatch/codex/<run-id>/` is the isolated `CODEX_HOME`
for one run (`~/.local/state/agent-dispatch/codex/` when `XDG_STATE_HOME` is
unset). Only subscription auth is staged into it.

The parent rollout is:

```text
sessions/YYYY/MM/DD/rollout-<timestamp>-<session-id>.jsonl
```

The runner resolves that file from this run home by native `session_meta`
(`thread_source` is not `subagent`). It does not pick the newest file under
`~/.codex/sessions/`.

Child rollouts are sibling `rollout-*.jsonl` files whose `session_meta.source`
is a `subagent` spawn and whose `parent_thread_id` is the parent session id.
