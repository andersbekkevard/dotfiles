---
name: beads
description: Beads (`br`) CLI reference and concurrency invariants. Use when creating, claiming, updating, closing, or querying beads, or when another skill defers to beads tracker conventions.
disable-model-invocation: true
---

# Beads

Beads (`br`) is the cross-session coordination substrate. State lives in
`.beads/` at the repo root, not in a thread's context, so any actor reads the
same truth. Beads is the one shared file that is safe to co-write concurrently
— SQLite + JSONL handle the locking.

Authoring work items — specs, tickets, and `## Success Criteria` — is owned by
`/to-spec` and `/to-tickets`. The execution lifecycle (claim → work → close
with evidence) is this skill's own contract: the CLI and the invariants below.

## Invariants

- **Beads exist for cross-session persistence.** Never create a bead and close
  it within the same session — do the work and report it in chat. Bead only
  when state must outlive the session: planning now and executing later,
  handoffs, dependencies, parallel ownership, persistent follow-up.
- **Claim is the lock.** `br update <id> --claim` (atomic: assignee=me +
  in_progress) before implementation. Never start a second session on an
  `in_progress` bead that is not yours.
- **Closed means implemented and verified.** The claimant closes, with
  evidence: `br close <id> --reason "<what was verified, commands run,
  artifact path>"`.
- **Defects reopen.** `br reopen <id>` + label `verification-failed` + a
  comment explaining what failed; a fresh owner fixes it.

## States

```
open ──claim──> in_progress ──implemented & verified──> closed
                   │                                       │
                blocked                    reopen (defect found later)
```

`blocked` is orthogonal: the work cannot proceed and needs a decision.

## Hierarchy

Beads form a **forest**, not one tree; epics nest by dotted ID (`<prefix>-7` →
`<prefix>-7.9`). An epic with child epics is an **umbrella** — organizational,
never claimed directly. The grabbable unit is a childless epic with
`## Success Criteria` (`br lint` flags epics missing one; `## Acceptance
Criteria` is the equivalent for tasks).

`/to-spec` publishes the full spec, including its high-level `## Success
Criteria`, as an umbrella epic's description. `/to-tickets` creates its
claimable child epic or epics with executable `## Success Criteria`, even when
one child can carry the whole spec, so the umbrella remains organizational.

## CLI

```bash
br ready                       # open, unblocked, not deferred
br epic status                 # epic tree + progress
br show <id>                   # full bead incl. description sections
br update <id> --claim         # atomic: assignee=me + in_progress (the lock)
br close <id> --reason "..."   # record verified completion
br reopen <id>                 # reopen if a defect is found later
br update <id> --add-label verification-failed
br comments add <id> "..."     # evidence pointer / findings (positional text, no -m)
br q "title" -l triage         # quick capture
br lint                        # flag epics missing ## Success Criteria
```

The `br` CLI is intentionally small. Check `--help` when unsure, and prefer
these shapes over guessed flags:

```bash
br epic status                 # takes no epic id; shows all epic progress
br show <id>                   # no --children flag
br query run <name>            # query is for saved queries, not ad hoc filters
br list --all --json           # inspect/filter issues with jq when needed
br dep list <id>               # show dependencies for one issue
br dep add <id> <blocker-id>   # <id> depends on <blocker-id>
br create "<title>" --type epic --parent <id> --silent   # child epic
```

To inspect the direct children of a dotted epic, filter the JSON list by one
more dotted segment:

```bash
br list --all --json | jq -r '.issues[]
  | select(.id | test("^<prefix>-7\\.18\\.[^.]+$"))
  | "\(.id) \(.status) \(.title)"'
```

## Repo conventions are repo-owned

Label taxonomy, saved queries, ID prefix, and sync/commit rules for `.beads/`
vary per repo. Before creating or labeling beads, read the repo's `AGENTS.md`
work-tracking section and its beads doc (`docs/beads.md` where present).
Absent any, use plain unlabeled beads and the invariants above.
