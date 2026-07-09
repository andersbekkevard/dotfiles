---
name: to-prd
description: Turn the current conversation into a PRD saved in the repo and tracked by a beads umbrella epic — no interview, just synthesis of what you've already discussed.
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

Work items live in beads (`br`) — follow the `beads` skill for tracker conventions.

## When not to run this

The PRD's readers are a **fresh-context implementer taking big ownership** and
a **blind verifier grading against it**. If neither reader is coming — the
effort is small, or the planning conversation will steer implementation live —
skip the PRD: the effort's map (see the `wayfinder` skill) already carries the
decisions, and a charter would be transcription. Compile when the decision
trail is too long for a fresh reader to cheaply replay, or when a frozen
measuring instrument is needed for handoff. When in doubt, ask Anders.

## Ownership

The PRD describes; the tracker verifies. Status lives **only** in beads — the
PRD's frontmatter carries a `bead: <epic-id>` pointer and no status field.
Slice-level `## Success Criteria` live **only** in the slices' beads
(`/to-issues`), never restated in the PRD. Decisions cite the map's decision
log for reasoning rather than restating it — gist here, link to the log.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the PRD, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the PRD and save it as a markdown file in the repo. If the repo has its own planning-material conventions (a `docs/prd.md` or equivalent naming the home, template, frontmatter, and status fields), follow those over the defaults here; otherwise use the template below and save to `docs/prd/<feature-slug>/<feature-slug>-prd.md` — one folder per effort, the same home wayfinder charts, so an effort's PRD lands beside its `map.md` (the slugged basename stays unique in Obsidian vaults, where wikilinks resolve by basename). Then publish a beads **umbrella epic** for it: `br create "<feature title>" --type epic --slug <feature-slug> --silent` (the bead id carries the effort's slug), then `br update <id> --description` with a short problem/solution summary, the agreed test seams, and the PRD file's path. The file is the source of truth; the epic is the tracker handle. An umbrella epic is organizational and never launched directly — `/to-issues` breaks it into grabbable slices. No triage label is needed. Exception: if the repo's conventions gate tracker creation behind an explicit execution order (e.g. "parse to beads only when the user says execute"), stop after saving the PRD and leave epic creation to that gate.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Verification Seams

A seam is a boundary where the work can be checked without re-doing the work —
an agreed observation point with a stateable pass condition. This section is
what the blind verifier grades at. For each seam: where semantics stop, the
pass condition (mechanical or spot-checkable — "N reporters → N sections",
never "looks right"), and who checks it. For code efforts this includes the
test seams (test external behavior through public interfaces, not
implementation details — see the `tdd` skill) and prior art for the tests;
for non-code pipelines, the same contract without the test harness.

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>
