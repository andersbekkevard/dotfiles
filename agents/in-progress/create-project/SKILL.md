---
name: create-project
description: Use an explained goal or accumulated conversation to scaffold one minimal project; interview Anders first when the project is not yet clear.
disable-model-invocation: true
---

# Create project

Status: work in progress.

Turn a goal or an accumulated conversation into one minimal Anders project.
This skill owns the transition from an idea to a repository. It does not
maintain an existing project or perform the project's domain work. Read and
follow [`project`](../project/SKILL.md) for the repository's durable context
contract; do not restate its architecture here.

## Build the mental model

Start from the conversation already available. If Anders has explained the
goal over many turns, reconstruct that intent instead of interviewing him from
scratch. Treat his messages as the primary evidence. Preserve uncertainty where
the conversation has not settled something.

If the invocation is blank or the conversation is insufficient, interview
Anders. Understand:

- the project's North Star;
- its purpose and why it is worth doing;
- the domain boundary, including what belongs here and what does not;
- what a useful first outcome or recurring use looks like;
- the durable context already known; and
- its intended home, privacy, and publication boundary.

Ask only questions whose answers could change the project. Keep the interview
conversational rather than turning it into a fixed questionnaire. Infer what is
safe to infer and reflect the emerging model back when that helps Anders correct
it.

The minimal shape is clear when you can state the North Star, purpose, boundary,
first useful outcome, repository home and privacy, and the few current owners
the project actually needs without inventing content.

In interview mode, ask exactly at that threshold:

> Do you want me to make it now, or continue the interview?

If Anders chooses to continue, keep refining the mental model. Ask the same
question again when the next meaningful threshold is reached. There is no limit
on how long Anders may keep interviewing. If he answers `Scaffold` or otherwise
chooses to make it now, use the best current model.

An explicit invocation after Anders has already explained a sufficiently clear
goal, or after a long conversation has converged on one, is itself the instruction
to scaffold. Reconstruct the project from that context and proceed without
restarting the interview or asking the checkpoint question. Interview only when
the available context is below the threshold.

## Scaffold

An explicit creation invocation with sufficient context, or `Scaffold` after an
interview, authorizes the project scaffold and its publication, not unrelated
domain execution. Inspect Anders's current project-root and Git-hosting
conventions rather than relying on an old hard-coded path.

Create the smallest opinionated repository that is already useful. Normally it
contains:

- one concise repository-owned agent contract, usually `AGENTS.md`;
- one human landing page, usually `README.md`, that states the North Star,
  purpose, boundary, current understanding, and next useful move; and
- only the first real notes, sources, code, ignores, or harness routes that the
  current mental model has already earned.

Files may combine these jobs while the project is small. Do not create empty
directories, speculative taxonomies, ADR collections, trackers, source tiers,
applications, or duplicated harness instructions. If the project is an
Obsidian knowledge graph, use Obsidian-compatible Markdown and wikilinks;
otherwise use its native format.

Initialize Git, create the remote through Anders's authenticated provider when
available, make the initial path-scoped commit, and push it. A personal project
defaults to a private repository unless Anders established another boundary.
Follow shared-project governance when the conversation identifies collaborators
or an existing organization policy. If publication is unavailable, leave a
complete local repository and report the exact blocker.

Finish by reporting the absolute local path, remote URL when created, initial
commit, the small set of owners chosen and why, and the important questions
intentionally left open for use to answer.
