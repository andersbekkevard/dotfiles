# Explanatory forms

Choose forms by the relationship the reader needs to see. Combine forms only
when they advance one reading order.

| Subject shape | Useful form |
|---|---|
| Alternatives, change, recommendation | Side-by-side comparison, before/after on identical axes, take/leave pair |
| Dependency, flow, sequence | Flow or sequence diagram |
| Mechanism, placement, spatial relationship | Directly annotated figure |
| Research or concept | Mental model, then route, evidence, consequence |
| Status, incident, plan, PR | Sections shaped around the reader's decisions; answer first |
| Dense inventory, ranking, lookup | Linked table with direct labels |
| A decision made in the browser | Read [interactive.md](interactive.md) |

For a concrete code shape, file tree, call path, or diff, use `show-me` to
select the smallest useful visual and include that result in the page
specification.

## Reading order

Use this arc when it fits:

> conclusion → comparative figure → direct annotation → nearby caveat →
> decision or question

Titles state conclusions, not chart types. Direct labels beat legend hunting.
Use small multiples when the reader must compare periods or measures. Prefer a
dense, intentional figure over a dashboard of interchangeable cards.

Match abstraction to the question. A system route is usually module-to-module;
descend to methods only when call order is the question. If a figure needs a
paragraph to explain how to read it, choose a clearer form.

Exact text and numbers are evidence. Preserve the relevant source material and
put each source link beside the claim it supports. A footer may summarize
coverage but cannot be the only place sources appear.
