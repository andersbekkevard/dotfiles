# Detached model dispatch

This is the shared lifecycle for `claude-dispatch` and `codex-dispatch`. Use it
when a run must survive the current session, joins a multi-run wave, or needs
supervision beyond one foreground completion.

A **lane** has a ready prompt, output sentinel, and log. Choose its model,
effort, access, and explicit root before launch; prompt assembly remains a
separate responsibility.

## Launch

Set `DISPATCH_SCRIPT` to the selected skill's `scripts/invoke.py`. Use absolute
paths for every artifact and add `--root /absolute/repo` for `agentic` or
`unrestricted` access.

```sh
LANE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/model-lane.XXXXXX")
cp /absolute/path/prompt.md "$LANE_DIR/prompt.md"

if command -v setsid >/dev/null 2>&1; then
  setsid python3 "$DISPATCH_SCRIPT" "$LANE_DIR/prompt.md" \
    --output "$LANE_DIR/result.md" --access closed \
    >"$LANE_DIR/run.log" 2>&1 &
elif command -v perl >/dev/null 2>&1; then
  perl -MPOSIX -e 'fork && exit; POSIX::setsid(); exec @ARGV' \
    python3 "$DISPATCH_SCRIPT" "$LANE_DIR/prompt.md" \
    --output "$LANE_DIR/result.md" --access closed \
    >"$LANE_DIR/run.log" 2>&1 &
else
  ( nohup python3 "$DISPATCH_SCRIPT" "$LANE_DIR/prompt.md" \
      --output "$LANE_DIR/result.md" --access closed \
      >"$LANE_DIR/run.log" 2>&1 & )
fi
```

The detacher lets the run survive its launching session. `setsid` and the
fork-first Perl form create a new session and process group. Perl must fork
first because `setsid(2)` fails when its caller is already a process-group
leader. `nohup` is the portability floor: it survives parent exit but remains
in the original process group.

After 3–5 seconds, confirm that `run.log` has bytes. A tiny dead log indicates
launch failure, not a live lane. Size parallelism by expected runtime, token
weight, and repository contention rather than a fixed lane count; serialize
shared files, schema changes, and architectural prerequisites.

## Supervise

Completion means the lane process is gone **and** `result.md` is nonempty. Log
phrases alone can false-positive when prompts or transcripts quote them.

Poll in proportion to expected runtime and keep the lifecycle under roughly ten
checks. At each check, verify both process liveness and log growth. When one
deliverable gates the next action, watch that artifact directly. Detached runs
are invisible to harness completion notifications, so use the environment's
scheduled wakeup or monitor mechanism when the owning session must return.

## Harvest and recover

Read `result.md` and the log tail. For an agentic or unrestricted coding run,
review the path-scoped diff and run the requested verification before
integrating the result; the dispatcher proves execution, not correctness.

Classify incomplete lanes before acting:

- Quota text: preserve the prompt and redispatch after reset.
- Live process with no log growth across two checks: inspect, then kill only
  the lane PID or its own process group. A box-wide `pkill` can terminate other
  owners' work.
- No process, no output, partial log: correct the execution failure and
  redispatch the preserved prompt.
- Patch mismatch or a moving checkout: narrow the task and require the next run
  to reread current files.

After two failed attempts with the same prompt, stop redispatching. Take over or
revise the prompt; a third identical attempt usually costs more than it teaches.
