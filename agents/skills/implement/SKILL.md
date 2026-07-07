---
name: implement
description: "Implement a piece of work based on a PRD or set of issues."
disable-model-invocation: true
---

Implement the work described by the user in the PRD or issues.

If the work is a bead, read it and its parent umbrella epic with `br show <id>`, plus the PRD file the umbrella points to, and claim it before starting: `br update <id> --claim`. Follow the `beads` skill for lifecycle conventions.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /review-changes to review the work.

Commit your work to the current branch.

If the work was a bead, close it with evidence: `br close <id> --reason "<what was verified, commands run>"`.
