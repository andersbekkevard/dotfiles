# Feature-map contract

`features/README.md` indexes the mapped user-facing features and states shared
preconditions, driving conventions, proof requirements, and isolation rules.

Each feature file begins with its user-visible purpose and then uses these
sections:

## Sub-features

Give each observable behavior a short stable ID and one-line description.

## How to get to it (user POV)

List every user entry point that matters: routes, controls, commands, keyboard
paths, or public calls.

## Driving it with the harness

State preconditions, then pair each user action with the exact harness command
and observable result. Use stable handles such as accessible names, prompt
strings, route paths, and public commands instead of coordinates or internal
implementation details.

## Gotchas

Record traps that can invalidate proof or waste a run.

For every proof, retain the feature ID and entry point. A mutation needs a
read-only second observation of the stored result. An unreachable path needs
the attempted route and unmet prerequisite; it is not verified through a
different entry point.
