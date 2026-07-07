---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable beads epics using tracer-bullet vertical slices.
disable-model-invocation: true
---

# To Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets).

Work items live in beads (`br`) — follow the `beads` skill for tracker conventions.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a bead id or a path as an argument, fetch it (`br show <id>`) and read its full description and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Issue titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

<vertical-slice-rules>

- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Any prefactoring should be done first

</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?

Iterate until the user approves the breakdown.

### 5. Publish the issues to beads

For each approved slice, create a child epic with the issue body template below as its description:

```bash
br create "<slice title>" --type epic --parent <umbrella-id> --silent
br dep add <slice-id> <blocker-id>   # once per blocker
```

Publish issues in dependency order (blockers first) so you can reference real bead ids. Parent and blocker relationships are native edges (`--parent`, `br dep add`), so the issue body carries no `## Parent` or `## Blocked by` section — `br ready` surfaces each slice as its blockers close, and no triage label is needed.

<issue-template>
## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if the `/prototype` skill produced code that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), add a context pointer to where that prototype code lives rather than inlining it.

## Success Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Scope

The files/dirs this slice mainly touches — used to judge whether two slices can run in parallel.

</issue-template>

Do NOT close or modify any parent issue.
