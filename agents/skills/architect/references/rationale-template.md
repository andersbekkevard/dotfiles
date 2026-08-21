# Architecture rationale

## Problem

What are we trying to do, and which existing constraints make the shape
non-obvious?

## Usage from the caller's view

Write this first. Show the README-style usage and two or three realistic call
sites: what callers import, what they call, and what comes back. When usage and
the type sketch diverge, reconcile the sketch to the usage.

## Shape

Describe the recommended data structures, interfaces, module ownership, and
data flow. State which invariants are encoded in types, where validation lives,
what complexity the interface hides, and what the system deliberately does not
do.

## Decision

Why is this shape preferred? Name the decisive constraints and evidence.

## Tradeoffs accepted

State each material tradeoff as: "We accept X in exchange for Y."

## Alternatives considered

Name at least one genuinely different shape and why it lost. Compare the
complexity each alternative exposes to callers and the complexity it hides.

## Open questions and risks

What still needs judgment, evidence, or verification?

## Next implementation step

What should be built first against the sketch?
