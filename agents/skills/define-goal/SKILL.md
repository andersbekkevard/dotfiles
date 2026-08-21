---
name: define-goal
description: Goal definition. Use when Anders asks to create/set a goal or turn an intention into a verifiable objective.
---

# Define Goal

## Overview

Shape the user's intent into an objective an agent can pursue honestly. Prefer measurable outcomes, explicit evidence, and bounded scope over activity descriptions.

This skill covers goal definition and goal-tool creation only. Do not create intermediate planning artifacts, durable snapshots, ledgers, decision logs, or resume files from this skill.

Important: a private goal is not a durable work tracker. In repos with a tracker contract, follow that contract before calling `create_goal`. For bead-backed work, read the `beads` skill and the relevant bead, claim it with `br update <id> --claim`, and then seed the goal from the bead's `## Success Criteria` or task `## Acceptance Criteria`. Never let an active goal replace the bead lock.

## Workflow

1. Confirm that goal definition is actually needed.
   - Use this skill when the user asks for `$define-goal`, asks to create or set a goal, asks for the goal tool, or wants help turning an intention into a clear objective.
   - If the user only asks for ordinary implementation work, do the work directly instead of forcing goal creation.
   - If the request mentions a bead/task/epic, says to continue or finish tracked work, or asks for an end-to-end implementation goal, stop goal creation until the bead-backed workflow has claimed the bead.

2. Restate the likely goal in concrete terms.
   A usable goal names:
   - the specific outcome that will be true
   - the main artifact, system, repo, environment, or user-facing behavior involved
   - how completion will be verified
   - what is in scope
   - what is out of scope when ambiguity would matter
   - the stop condition for asking the user instead of grinding

   For loaded terms (primitive, semantic, durable, reusable, canonical,
   source-backed, provenance, production, one-shot, etc.), define the mechanism
   before the metric. State what proves the term, not only the label/artifact.

3. Make it quantitative when the domain supports it.
   Prefer numbers that represent real success, not decorative precision:
   - pass/fail validators: exact tests, checks, CI jobs, evals, commands, or acceptance criteria
   - quality thresholds: latency, error rate, cost, accuracy, recall, precision, coverage, flake rate, bundle size, memory, uptime, completion rate, or manual review criteria
   - artifact constraints: file paths, affected modules, allowed commands, output formats, target environments, deadlines, or maximum blast radius
   - evidence counts: number of reproduced failures, successful reruns, reviewed examples, migrated records, addressed comments, or verified cases

4. Repair weak goals before setting them.
   - Rewrite vague goals into measurable objectives when local context makes the rewrite safe.
   - Ask one concise clarification question when the missing detail changes the intended outcome or validation.
   - Reject pure activity goals such as "make progress," "keep investigating," "improve things," or "work on X" unless they are sharpened into a verifiable outcome.
   - Reject proxy goals that could pass while the user rejects the result. Ask:
     "What could satisfy this metric while missing intent?" Add that forbidden
     shortcut and mechanism check.
   - Do not let the owner redefine the metric, invariant, oracle, schema, or
     proof surface unless explicitly scoped with an independent falsifier.

5. Check active goal state before creating a goal.
   - For bead-backed work, first confirm the durable tracker is in the right state; for beads, that means `br show <id>` has been read and `br update <id> --claim` has succeeded.
   - Call `get_goal`.
   - If there is no active goal and the objective meets the quality bar, call `create_goal`.
   - If there is an active goal that still matches the user's intent, continue using it instead of creating a duplicate.
   - If there is an active goal that conflicts with the new request, ask whether to finish the current goal, mark it complete if done, or start a separate goal-backed thread.

6. Create the goal only after it passes the quality bar.
   - Use a single concise objective string.
   - Include the verification evidence in the objective itself.
   - Include scope bounds when they constrain the work.
   - Include a token budget only when the user explicitly requested one.
   - Do not call `create_goal` for an ordinary multi-step task unless the user explicitly asked for goal-backed work.

## Goal Quality Bar

Before `create_goal`, the objective should answer:

- What concrete thing will be true when this is done?
- What evidence will prove it?
- What quantitative or binary threshold defines success?
- What scope boundaries matter?
- What should cause the agent to stop and ask?
- What false-pass implementation is explicitly forbidden?
- If using a loaded term, what mechanism evidence proves it?

Good:

> Reduce checkout API p95 latency below 250 ms for the documented slow path by making the smallest safe server-side change, then verify with `npm run test:checkout` and the existing local latency benchmark showing p95 under 250 ms across 3 consecutive runs.

Good:

> Resolve the open review comments on PR 123 that request code changes, update only the affected auth files and tests, and verify with the targeted auth test command plus `gh pr view 123` showing no unresolved change-request threads.

Weak:

> Make checkout faster.

Weak:

> Keep investigating the PR comments.

## Quantification Heuristics

- For bugs, define success as reproduction first, fix second, and a failing-then-passing validator when possible.
- For tests, name the exact command and required pass condition.
- For performance, name the metric, target threshold, measurement method, and number of runs.
- For quality work, define an observable acceptance bar such as reviewed examples, lint/typecheck/test pass, or user-approved artifact.
- For research, define the decision the research must enable, the sources or systems in scope, and the evidence standard.
- For operations, define healthy state, monitoring window, failure threshold, and rollback or escalation trigger.

## Clarifying Questions

Ask only when a reasonable rewrite would risk pursuing the wrong outcome. Keep the question short and oriented around the missing validator or scope boundary.

Useful question shapes:

- "What metric should define success here: latency, cost, accuracy, or user-visible behavior?"
- "Which environment should I verify against: local, staging, or production?"
- "What is the minimum evidence you want before I mark this goal complete?"

If the user cannot provide a metric, propose the most honest binary validator available and ask for confirmation.
