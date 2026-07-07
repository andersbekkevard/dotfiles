---
name: codex-lane
description: Dispatch work to the codex coding agent (gpt-5.5) — the codex counterpart of the Agent tool. Use before every `codex exec` invocation, foreground or background; when delegating investigation or implementation to codex; when running multi-lane waves or polling lane liveness; or when recovering a dead/hung/quota-blocked lane.
---

# Codex Lane — dispatching and supervising codex runs

This skill is the codex mirror of the Agent tool: every delegation to the
codex coding agent goes through it. A **lane** is one detached `codex exec`
run with a prompt file, a log, and a deliverable. Every rule below traces to
a real dispatch failure.

## Every dispatch — foreground or lane

These rules bind every `codex exec`, not only detached lanes:

- Stage the prompt to a file **with the Write tool or a quoted heredoc
  (`<<'EOF'`)**, then dispatch with `"$(cat /tmp/<name>.md)"`. Multi-KB
  inline prompts have died at exit 144, and an unquoted heredoc executes any
  `$(...)` inside the prompt text while staging it.
- `< /dev/null` on every invocation — codex blocks forever on a connected
  stdin.
- After 3–5s, confirm the log/output file has bytes (`wc -c`). A tiny dead
  file means the dispatch itself failed — read it before assuming the run
  is live.
- Regular mode only: never fast mode, never priority service tier.
  Read-only mining/exploration: `-c model_reasoning_effort="medium"`;
  implementation: `-c model_reasoning_effort="high"`.

**Mode choice.** A single bounded run that this session will harvest may use
the harness's tracked background execution — completion notifies you, so no
wakeup machinery is needed. Cut a detached lane (the rest of this skill) when
the run must survive the session, joins a multi-lane wave, or needs
supervision beyond one completion notification.

## Dispatch

1. Stage the prompt per **Every dispatch**, fully self-contained at
   `/tmp/<lane>.md`. A lane prompt names:
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
  setsid codex exec "$(cat /tmp/<lane>.md)" < /dev/null > /tmp/<lane>.log 2>&1 &
elif command -v perl >/dev/null 2>&1; then
  perl -MPOSIX -e 'fork && exit; POSIX::setsid(); exec @ARGV' \
    codex exec "$(cat /tmp/<lane>.md)" < /dev/null > /tmp/<lane>.log 2>&1 &
else
  ( nohup codex exec "$(cat /tmp/<lane>.md)" < /dev/null > /tmp/<lane>.log 2>&1 & )
fi
```

   Why: the detacher makes the lane survive session restarts (non-detached
   lanes die with the parent); the log redirect preserves evidence and quota
   errors. On the tiers — `setsid` and the `perl` form both put the lane in a
   **new session + own process group** (`PPID 1`, `PGID==PID`), so even a
   `kill -- -PGID` on the launching shell's group can't reach it. The `perl`
   line must `fork` first: `setsid(2)` fails with `EPERM` if the caller is a
   process-group leader (which `&` makes it under interactive job control),
   and the fork guarantees the child isn't one. `nohup` is the floor for a
   future macOS that ships without `perl` (Apple has deprecated the bundled
   scripting runtimes): it reparents to init and ignores SIGHUP so it survives
   parent exit, but it stays in the original process group — so it does **not**
   survive a group-targeted kill. Never rely on a bare `perl -e 'setsid();…'`
   without the fork: it silently degrades to `nohup`-level detachment when the
   caller is a group leader.
3. Cap parallelism at ~8 lanes — wide waves get OOM-killed (a 29-wide
   wave died on a 15GB host).
   Respect quota as a budget; keep an overnight reserve.
4. If the lane writes a new typed value (enum variant, schema field), the
   owner lands the type change FIRST — a lane writing data the code cannot
   parse poisons fixtures incrementally.

## Supervise

- **Completion = process gone AND deliverable exists.** Never rely on a log
  substring: lanes that read transcripts or codex logs quote `tokens used`
  and false-positive as done. Check `pgrep -f "codex exec"` plus the
  deliverable path from the prompt.
- Poll cadence: size to the expected runtime of the slowest single lane,
  never to lane count. Interval ≈ that estimate ÷ 5, floored at ~270s; err
  toward too often — a wasted poll costs one context reload, a missed
  completion costs wall-clock — but keep the whole supervision lifecycle
  under ~10 polls. On every poll verify liveness, not just completion: log
  growth since last check AND a live process.
- After dispatching, always end the turn with a scheduled wakeup. Detached
  lanes are invisible to the harness; persistent background pollers and
  sentinels get killed by the environment — the wakeup is the reliable
  path.
- For long multi-lane waves, arm a dead-session supervisor if the repo
  provides one (e.g. a `tools/agent-supervisor/`), reviving the session
  inside tmux (interactive) or via a print-mode pulse while lanes still run.

## Harvest

1. Read the tail of the log and the deliverable.
2. Owner-verify before integrating: path-scoped diff review against the
   allowed edit paths, run the named gates/tests yourself, screen against
   the product invariants named in the lane prompt. Lanes fail by
   optimizing the wrong objective, not by failing to code.
3. Commit immediately and path-scoped (`git -C <absolute repo path> add <lane paths>`)
   — uncommitted lane output in the shared checkout eventually gets wiped.
4. Refill the freed lane slot in the same wake.

## Recover

Classify a lane with no completion before acting:

- **Quota text in the log** ("You've hit your usage limit"): keep the
  prompt, redispatch after reset; write the next-day plan into the working
  plan artifact
  if quota is gone for hours.
- **Live process, no log growth** across two checks: hung — inspect, then
  kill; a resume can freeze for an hour at a tiny log while its edits are
  already in the tree, so diff the working tree before assuming the work is
  lost.
- **No process, partial log**: find the rollout under
  `~/.codex/sessions/YYYY/MM/DD/` (grep for prompt text), then
  `codex exec resume <session-id> "<narrow follow-up>"`. Never
  `resume --last` when more than one lane may have run — it races.
- **Patch-mismatch chatter in the log**: the checkout moved under the lane;
  narrow the resume prompt and require it to re-read current files.
