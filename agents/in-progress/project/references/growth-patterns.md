# Project growth patterns

Status: working hypotheses. These are optional transitions, not a target
architecture. Use the smallest one that resolves pressure already visible in
the project.

## Authority and routing

**One owner per question.** Different representations may answer different
questions. Policy can own what must happen, configuration what is selected,
code what happens, a receipt what happened, and an ADR why a consequential
choice was made. Name precedence when they conflict instead of inventing one
master document.

**One home, many routes.** Store an item once and link it into every useful
reading path. An inbox is quarantine for material whose owner is genuinely
unknown, not a permanent category.

**Map and Note may begin combined.** A small file can both route and own current
knowledge. Split a thin Map from a claim-owning Note only when selective reading
or different change rhythms make the combination costly.

**Current authority and history are different jobs.** When an owner is
superseded, move the current claim and routes together. Preserve meaningful
rationale in Git, dated evidence, an ADR, or a claim-free signpost at an address
readers will still try.

## Work and evidence

**Planning earns durability through time or coordination.** Keep one-turn work
in the active task. Add one planning record when work must survive sessions.
Add a tracker only when dependencies, concurrency, claims, or status need a
durable execution model. Reconcile settled work into its permanent owner.

**Intent and volatile state may need different owners.** A stable goal or
operating doctrine should not be rewritten as often as a machine, application,
or external-world snapshot. Split them when their update rhythms diverge.

**Recurring events begin with the first occurrence.** A first real occurrence
earns a record; repetition earns machinery. For a self-contained event with
meaningful context, experience, results, or friction, prefer one date-marked
Markdown record per occurrence. This fits workouts, cooks, meetings,
experiments, and similar histories. Very small, high-frequency measurements may
fit an append-only or structured log better. Keep the observed event separate
from the reusable method it may eventually improve, and do not turn one result
into a rule.

**Source layers describe transformations.** A source-heavy project may need raw
received evidence, a faithful searchable derivation, and an integrated output.
Bronze, Silver, and Gold are useful names when the project defines their exact
guarantees. Interpretation does not automatically belong in Gold, and a
Markdown-native source may need no duplicate layer.

**Provenance is more than a link.** When relevant, preserve origin, author or
producer, date, revision or hash, transformation, uncertainty, and intentional
divergence. The required depth follows the consequence of getting the claim
wrong.

## Mechanisms

**Definitions tracked, materializations selective.** Track authored definitions,
scripts, configuration, and compact receipts. Keep reproducible runs only when
the result itself needs delivery, audit, comparison, or promotion.

**Determinism follows repetition or risk.** Move a method into structured data,
code, lint, tests, or an application when repeated interpretation or
consequential effects make prose unreliable.

**Models propose; controlled mechanisms perform exact effects.** Publication,
mail, deployment, database writes, and other consequential actions may deserve
deterministic code and an explicit authority boundary. A Markdown-only project
does not inherit this machinery merely because larger projects use it.

**Check the real journey.** A convenient unit or proxy test can pass while the
user's actual workflow fails. Add an end-to-end check after evidence shows the
proxy is insufficient, and keep generated, tested, reviewed, deployed, and
accepted as distinct states.

**Policy, checker, and repair are separate.** A deterministic validator can
expose drift. It does not become the policy owner, and detecting a failure does
not authorize repair. Keep the validator aligned as the policy evolves.

## Test for adding a layer

Before adding structure, ask:

1. What real question lacks a clear owner?
2. What concrete confusion, repetition, or risk does the layer remove?
3. Could the current owner be deepened instead?
4. What will route readers here?
5. What old authority or route must be retired in the same change?

If those answers are weak, leave the repository smaller.
