---
name: architect
description: "Sketch types, signatures, and module structure before code, then stay in the loop while implementation fills in. Use for /architect, 'architect this', 'design this', or non-trivial work where jumping to code would lock in the wrong shape."
disable-model-invocation: true
---

# Architect

Design before implementing. Sketch the caller experience, types, function
signatures, module boundaries, and difficult logic with `not implemented`
bodies or pseudocode. Then implement against that sketch. If implementation
disproves the design, redesign instead of accumulating workarounds.

## Ground

Inspect the systems the change touches. Trace the present call path, ownership,
data shapes, invariants, and constraints far enough to explain how the proposed
shape will fit. Read applicable owner documentation and ADRs. Skip this only
for genuinely greenfield work.

## Sketch

Write the caller's usage first: the README-style example and two or three
realistic call sites. Derive the types and signatures from that usage, not the
reverse.

Make the proposed shape concrete enough to implement:

- Core data structures and the invariants they encode.
- Public interfaces, return values, and error modes.
- Module ownership and the data flow between modules.
- `not implemented` bodies and pseudocode for load-bearing logic.
- Validation and side-effect boundaries.

Prefer a small interface that hides substantial policy and complexity. Screen
the design against [design red flags](references/design-red-flags.md). Record
the recommendation, rejected alternatives, accepted tradeoffs, and open risks
using the [rationale template](references/rationale-template.md).

Pause before implementation only when Anders asks for a checkpoint or the
remaining choice materially changes the product, authority, or irreversible
shape.

## Implement against the sketch

Replace the placeholders with working code while keeping the sketch and
implementation aligned. Treat deviations as evidence: determine whether the
sketch missed a requirement, the implementation is overreaching, or a newly
discovered constraint changes the design. Update the sketch and rationale when
the contract changes.

## Redesign when the shape is wrong

Do not condemn a design for one difficult edge case. Redesign when the same
friction repeats: parallel workarounds, special cases with one cause, escape
hatches in the types, callers learning internal rules, or several deviations
of the same shape.

When that happens, feed the implementation lessons back into the constraints,
subtract unnecessary surface, and sketch the design again as though the new
constraints had been known from the start.

## Verify

Verify the completed behavior through the real caller path. Confirm that the
implementation still matches the usage sketch, public interface, invariants,
and accepted tradeoffs. Report any remaining divergence explicitly.

For a small change, the sketch and rationale may be one short file. For larger
work, include a module map and type definitions. Keep the artifact proportional
to the decision it protects.
