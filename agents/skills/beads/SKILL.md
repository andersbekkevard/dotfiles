---
name: beads
description: Beads tracker protocol. Use when creating, claiming, updating, labeling, closing, reopening, or syncing beads, or when following epic-owner lifecycle.
---

# Beads Protocol

Beads (`br`) is the cross-session coordination substrate. State lives in
`.beads/` at the repo root, not in a thread's context, so any actor reads the
same truth — a session reports done by closing its bead, not by messaging
anyone. Beads is the one shared file that is safe to co-write concurrently —
SQLite + JSONL handle the locking.

## When to bead

Beads exist for **cross-session persistence**: never create a bead and close it
within the same session — a bead born and closed in one conversation is pure
overhead, whatever the size of the work. Do the work and report it in chat.
This holds even for multi-file or "epic-shaped" work, and "if you want it
tracked" is not an explicit ask. Beads are valuable only when state must
outlive the session: planning now and executing later, distinct
handoff/execution phases, dependencies, parallel ownership, persistent
follow-up, or long-running state.

For bead-backed work, the live state must be in beads, not only in chat or the
goal tool: claim before implementation, keep the bead state honest while
working, and close or block it with evidence when done.

## States

Beads has a fixed four-state lifecycle:

```
open ──claim──> in_progress ──implemented & verified──> closed
                   │                                       │
                blocked              reopen +verification-failed (defect found later)
```

- `open` — ready and unclaimed.
- `in_progress` — claimed; this is the lock. Never start a second session on an
  `in_progress` epic that is not yours.
- `blocked` — orthogonal; the work cannot proceed and needs a decision.
- `closed` — the owner implemented **and** verified it against its success
  criteria.
- A closed epic can be **reopened** if a defect surfaces later (`br reopen` +
  label `verification-failed` + a comment explaining what failed); relaunch an
  owner on it.

## Who closes

The epic owner closes its own epic, with evidence in the close reason, once it
has implemented and verified the `## Success Criteria`. The owner is the owner
of correctness — there is no separate acceptance gate it must wait on. Closing
records verified completion.

```bash
br close <epic-id> --reason "<what was verified, commands run, artifact path>"
```

Closed work is not frozen: if a defect is found later, reopen it as above and a
fresh owner fixes it.

## Required sections on an epic

A launch-unit epic needs two sections in its description body:

- **`## Success Criteria`** — the verification contract: oracle + the
  check/command to run + the one-line rejection test. This is what `define-goal`
  seeds from and what the owner verifies against. `## Success Criteria` is
  beads' built-in epic lint section, so `br lint` flags any epic that lacks it.
  (`## Acceptance Criteria` is the equivalent for tasks.)
- **`## Scope`** — the epic's home territory: the files/dirs it mainly touches,
  used to judge whether two epics can run in parallel. It is **not** a hard
  wall — an owner may edit beyond it carefully — and it is not lint-enforced,
  so the launcher and Anders maintain it. Naming likely-shared files (CLI
  entrypoints, `__init__`, `pyproject`, lockfiles, docs indexes) helps the
  overlap check.

For loaded terms (primitive, semantic, durable, reusable, canonical,
source-backed, provenance, production, one-shot, etc.), `## Success Criteria`
must define the mechanism, reject weak readings, and name evidence that would
catch rename/tag/wrap shortcuts.

Author both as markdown sections in the description (via `br create` or
`br update <id> --description`).

## Hierarchy

Beads form a **forest**, not one tree: several top-level epics coexist. Within
each, epics nest by dotted ID (`<prefix>-7` → `<prefix>-7.9` → `<prefix>-7.9.x`)
— **epics nest inside epics**. The distinction that matters is structural, not
positional:

- **Umbrella epic** — has child epics. Organizational, never launched directly;
  may have a PRD above it.
- **Launch-unit epic** — has a `## Success Criteria` and **no child epics**
  (just leaf tasks, or none). One agent owns it as one goal; this is what gets
  launched. A standalone top-level epic with no children is a launch unit too.
- **Leaf task** — the within-run ledger under a launch-unit epic.

`br epic status` shows each epic's children-closed ratio. Do **not** rely on
`br epic close-eligible` to auto-close an epic — all-children-closed is not the
same as outcome-verified; the owner verifies the epic's outcome before closing
it.

## Key commands

```bash
br ready                       # open, unblocked, not deferred (leaf tasks)
br epic status                 # epic tree + progress
br show <id>                   # full bead incl. ## Success Criteria / ## Scope
br update <id> --claim         # atomic: assignee=me + in_progress (the lock)
br close <id> --reason "..."   # owner records verified completion
br reopen <id>                 # reopen if a defect is found later
br update <id> --add-label verification-failed
br comments add <id> -m "..."  # evidence pointer / findings
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
```

To inspect the direct children of a dotted epic, filter the JSON list by one
more dotted segment:

```bash
br list --all --json | jq -r '.issues[]
  | select(.id | test("^<prefix>-7\\.18\\.[^.]+$"))
  | "\(.id) \(.status) \(.title)"'
```

## Repo conventions are repo-owned

Label taxonomy, workstream views and saved queries, ID prefix, epic-section
extensions, and sync/commit rules for `.beads/` vary per repo. Before creating
or labeling beads, read the repo's `AGENTS.md` work-tracking section and its
beads doc (`docs/beads.md` where present) — they own those conventions. Absent
any, use plain unlabeled beads and the protocol above.
