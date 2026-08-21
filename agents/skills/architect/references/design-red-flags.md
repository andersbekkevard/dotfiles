# Design red flags

A red flag is a reason to revise or reject the proposed shape.

## Shallow module

A shallow module exposes a large interface while hiding little complexity.
Prefer a simple interface backed by substantial behavior.

Look for callers coordinating several methods to complete one operation,
public options that expose internal stages, or an interface that saves the
caller from learning almost none of the implementation.

## Information leakage

Information leakage makes several modules depend on the same internal
representation, policy, or protocol detail. Changing it then requires
coordinated edits.

Keep transport, storage, framework, and wire types behind the owning interface.
Parse them into domain types at the edge.

## Temporal decomposition

Temporal decomposition organizes modules by execution order rather than the
knowledge they own. Separate load, validate, transform, and save stages often
repeat one representation and its invariants across several boundaries.

Group behavior around domain knowledge and ownership, even when its methods run
at different times.

## Pass-through method

A pass-through method forwards essentially the same arguments to another
method. Remove it or move responsibility to the module that can complete the
operation. Keep the boundary only when it adds policy, adaptation, or a
distinct abstraction.
