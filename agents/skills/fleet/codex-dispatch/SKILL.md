---
name: codex-dispatch
description: Dispatch Codex from a Claude or Fable orchestrator. Invoke before every Claude/Fable `codex exec`, foreground or detached; when polling lane liveness; or when recovering a dead, hung, or quota-blocked lane.
disable-codex-model-invocation: true
---

# Codex Dispatch — dispatching and supervising Codex runs

`codex-dispatch` is the Codex counterpoint to Claude and Fable's local `Agent`
tool. It owns every Codex dispatch, foreground or detached. GPT agents use
native subagent tools instead. A **lane** is one detached `codex exec` run with
a prompt file, a log, and a sentinel. Every rule below traces to a real dispatch
failure.

## Every dispatch — foreground or lane

These rules bind every `codex exec`, not only detached lanes:

- Prompts are fully self-contained — paths, context, constraints,
  acceptance criteria, and exactly what to return. Codex cannot ask
  follow-up questions.
- Run from the target repo, or pass `-C <repo>`.
- Stage the prompt to a file **with the Write tool or a quoted heredoc
  (`<<'EOF'`)**, then pass it on stdin: `codex exec … - < /tmp/<name>.md`.
  The `-` makes codex read instructions from stdin, so the prompt never
  touches argv (multi-KB argv prompts have died at exit 144) and stdin
  closes at EOF (a connected stdin blocks codex forever). An unquoted
  heredoc executes any `$(...)` inside the prompt text while staging it.
- Add `-o /tmp/<name>.out.md` (`--output-last-message`) to every
  invocation. Codex writes its final message there on completion, making
  the file both the harvestable report and the completion **sentinel**: it
  exists only if the run actually finished.
- After 3–5s, confirm the log has bytes (`wc -c`). A tiny dead log means
  the dispatch itself failed — read it before assuming the run is live.
- Regular mode only: never fast mode, never priority service tier.
  Read-only mining/exploration: `-c model_reasoning_effort="medium"`;
  implementation: `-c model_reasoning_effort="high"`.
- Foreground runs may add `2>/dev/null` — codex's thinking stream bloats
  context, and the result lives in the `-o` file. Drop the suppression only
  to debug a failing dispatch.
- When a prompt references a skill, verify the path resolves before dispatch
  (`test -f <path>/SKILL.md`) or inline the skill text. A missing skill
  reference is a dispatch defect — surface it loudly; never let the lane
  silently downgrade to "normal engineering discipline". (A one-character
  path typo once disabled a skill for a whole adoption week.)
- Prompts that stage shell snippets: never use `status` as a variable name —
  it is read-only in zsh and the assignment kills the script.
- Follow-ups reuse the session instead of paying for a fresh run:
  `codex exec resume <session-id> -o /tmp/<name>.out.md - < /tmp/<name>-resume.md`,
  session id from `~/.codex/sessions/YYYY/MM/DD/` (grep for the prompt
  text). Never `resume --last` when more than one run may have happened —
  it races.

**Mode choice.** A single bounded run that this session will harvest may use
the harness's tracked background execution — completion notifies you, so no
wakeup machinery is needed. Cut a detached lane (the rest of this skill) when
the run must survive the session, joins a multi-lane wave, or needs
supervision beyond one completion notification. Inside Workflow scripts —
whose model parameter only takes Claude models — reach codex through a thin
wrapper agent (model `sonnet`, effort `low`) whose prompt is to run the
staged, self-contained `codex exec` command via Bash and return its output
verbatim.

## Dispatch

1. Stage the prompt per **Every dispatch** at `/tmp/<lane>.md`. A lane
   prompt additionally names:
   - exact cwd and allowed edit paths;
   - forbidden paths (shared crates, harness, goldens) and forbidden
     satisfactions (deleting checks, punching computed rows, loosening
     tolerances, `git checkout/restore/stash`, committing);
   - verification commands the lane must run;
   - the deliverable: an exact output file path or an exact report format;
   - "No commit/push" — the owner commits.
2. Dispatch detached. `setsid` (util-linux) exists on Linux but **not on
   stock macOS**, so use a three-tier launcher — real `setsid` where present,
   a fork-first `perl` `setsid` for exact parity on macOS, and `nohup` as the
   always-available floor:

```bash
if command -v setsid >/dev/null 2>&1; then
  setsid codex exec -o /tmp/<lane>.out.md - < /tmp/<lane>.md > /tmp/<lane>.log 2>&1 &
elif command -v perl >/dev/null 2>&1; then
  perl -MPOSIX -e 'fork && exit; POSIX::setsid(); exec @ARGV' \
    codex exec -o /tmp/<lane>.out.md - < /tmp/<lane>.md > /tmp/<lane>.log 2>&1 &
else
  ( nohup codex exec -o /tmp/<lane>.out.md - < /tmp/<lane>.md > /tmp/<lane>.log 2>&1 & )
fi
```

   Why: the detacher makes the lane survive session restarts (non-detached
   lanes die with the parent); the log redirect preserves evidence and quota
   errors. `setsid` and the `perl` form both put the lane in a **new session
   + own process group** (`PPID 1`, `PGID==PID`), so even a `kill -- -PGID`
   on the launching shell's group can't reach it. The `perl` line must `fork`
   first: `setsid(2)` fails with `EPERM` if the caller is a process-group
   leader, which `&` makes it under interactive job control. `nohup` is the
   floor for a future macOS without `perl`: it survives parent exit but stays
   in the original process group, so a group-targeted kill still reaches it.
3. Respect quota as a budget: keep an overnight reserve. Size in-flight
   parallelism by lane *weight* (expected tokens/runtime and repo contention),
   not a flat lane count — many light read-only lanes can run wide; a few
   heavy implementation lanes saturate earlier.
4. If the lane writes a new typed value (enum variant, schema field), the
   owner lands the type change FIRST — a lane writing data the code cannot
   parse poisons fixtures incrementally.
5. Lanes never write the tracker: a read-only fan-out lane never claims,
   closes, or touches beads — its self-contained prompt is the steering
   artifact, and the owning session advances bead status at each verified
   checkpoint.

## Supervise

- **Completion = process gone AND sentinel exists.** Check
  `pgrep -f "codex exec"` plus a non-empty `/tmp/<lane>.out.md`. Log
  substrings false-positive: lanes that read transcripts or codex logs
  quote `tokens used`.
- Poll cadence: size to the expected runtime of the slowest single lane,
  never to lane count — parallelism does not lengthen the critical path.
  Interval ≈ that estimate ÷ 5, floored at ~270s; err
  toward too often — a wasted poll costs one context reload, a missed
  completion costs wall-clock — but keep the whole supervision lifecycle
  under ~10 polls. On every poll verify liveness, not just completion: log
  growth since last check AND a live process. When a *single* deliverable
  gates the next action, watch that exact artifact rather than a blanket
  fixed interval.
- After dispatching, always end the turn with a scheduled wakeup. Detached
  lanes are invisible to the harness, and persistent background pollers get
  killed by the environment — the wakeup is the reliable path.
- For long multi-lane waves, arm a dead-session supervisor if the repo
  provides one (e.g. a `tools/agent-supervisor/`), reviving the session
  inside tmux (interactive) or via a print-mode pulse while lanes still run.

## Harvest

1. Read the sentinel (`/tmp/<lane>.out.md`) — the lane's final report — and
   the tail of the log.
2. Owner-verify before integrating: path-scoped diff review against the
   allowed edit paths, run the named gates/tests yourself, screen against
   the product invariants named in the lane prompt. Lanes fail by
   optimizing the wrong objective, not by failing to code.
3. Commit immediately and path-scoped (`git -C <absolute repo path> add <lane paths>`)
   — uncommitted lane output in the shared checkout eventually gets wiped.
4. If more work packages are queued, dispatch the next one in the same wake.

## Recover

Classify a lane with no completion before acting:

- **Quota text in the log** ("You've hit your usage limit"): keep the
  prompt, redispatch after reset; write the next-day plan into the working
  plan artifact if quota is gone for hours.
- **Live process, no log growth** across two checks: hung — inspect, then
  kill *by PID or the lane's own PGID only; never a box-wide
  `pkill -f "codex exec"`* — on a shared machine that murders every other
  owner's lanes. A resume can freeze for an hour at a tiny log while its
  edits are already in the tree, so diff the working tree before assuming
  the work is lost.
- **No process, no sentinel, partial log**: resume the session with a
  narrow follow-up prompt (resume form in **Every dispatch**).
- **Patch-mismatch chatter in the log**: the checkout moved under the lane;
  narrow the resume prompt and require it to re-read current files.

**Stop-loss:** after two failed resume rounds on the same lane, take over
and do the work directly — a third round costs more than doing it yourself.
