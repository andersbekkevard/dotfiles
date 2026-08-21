# Architectural critique rubric

Apply only the lenses relevant to the subsystem.

## Abstraction fit

Do abstractions represent real concepts and hide useful complexity? Are
boundaries placed between things that change independently? Look for accidental
coupling, speculative indirection, and framework wiring mixed with business
logic. Over-abstraction and under-abstraction are both problems.

## Data model

Do structures fit actual access patterns? Look for repeated reshaping,
representations that leak across owners, and types that promise more than the
runtime data provides.

## Boundary discipline

Are validation and error handling concentrated at real entry points? Does data
cross boundaries in honest typed shapes? Can the subsystem be tested through
its public seam without starting the whole system?

## Evolution readiness

For the most plausible next requirements, would change remain local? Look for
hard-coded assumptions, bolted-on behavior, and legacy paths without current
callers. Do not penalize the design for imaginary futures.

## Complexity versus value

Is complexity concentrated where the domain requires it, or spent on
boilerplate, pass-through layers, and configuration? Does each component earn
its existence?

## Consistency

Does this area follow established local patterns? Different is acceptable when
the reason is concrete; unexplained difference creates maintenance cost.
