# Anders's skill-writing principles

Status: work in progress.

These are Anders's three current principles for shaping a skill system. They
are working models to apply and revise, not laws to enforce mechanically.

## 1. Start with a small learning rate and a careful initialization target

A skill changes future agent behavior. Its first version establishes the region
from which later revisions will develop, while every added instruction pushes
behavior in a particular direction. Both the starting point and the size of
each update therefore matter.

Choose the initialization target deliberately. The strongest starting point is
often a completed piece of real work: perform the task, identify what was
reusable or unnecessarily difficult, and encode only that. A direct request
from Anders or a proven external procedure can also provide a starting point.
Begin with the responsibility, general direction, known boundaries, and the
parts supported by evidence. Leave the rest open.

Keep the initial skill shorter and less specific than a polished final workflow
might be. Long skills and detailed sequences exert behavioral pressure even
when their details are speculative. Early concision is therefore a way to
control oversteering, not merely a writing preference.

Revise with a small learning rate. Use real work to find where the agent needs
more direction, then make the narrowest correction that addresses the cause.
Do not generalize one recent example into a universal procedure. Record a
one-off result as evidence or a hypothesis; let repeated success, repeated
friction, or an explicit Anders decision earn stronger language.

Specificity should trail understanding. Fixed sequences, formats, decision
rules, and completion criteria become appropriate when Anders has established
the workflow's mental model. Safety, permission boundaries, and genuinely
fragile procedures can justify precision earlier because the cost of variation
is already understood.

Practical consequences:

- Prefer extracting a skill from real work over designing a complete workflow
  in advance.
- Preserve visible uncertainty in an early version.
- Treat length and precision as behavioral force that must be earned.
- Update existing guidance in small, evidence-backed steps.

## 2. Build a Unix-style toolbox and be careful with coupling

Anders wants a toolbox of skills he can combine, not one author's complete
system for interacting with agents. The composition of the tools belongs to
Anders. A skill should not claim the surrounding conversation, planning, or
handoff workflow merely because its own procedure touches those activities.

The leading design pressure is one skill, one coherent responsibility. This is
not a file-count rule. A useful boundary normally gives the skill one main
reason to be invoked and one main reason to change. Its procedure or technical
choice should be replaceable without redesigning unrelated skills.

Use replaceability to test the boundary. Anders should usually be able to swap
one procedure, adopt a better technical implementation, or borrow one focused
idea while the rest of the collection remains intact. If replacement requires
widespread coordinated edits, the responsibility is probably too broad or its
dependencies are hidden.

Coupling is sometimes real. Keep behavior together when separation would
duplicate essential state, split one invariant across owners, or require
constant coordination between the pieces. Record why the coupling exists so a
later editor can test whether it is still necessary. Prefer explicit skill and
reference boundaries over assumptions that several skills always travel as a
suite.

A useful supporting distinction is preference versus procedure. A preference
skill records Anders's taste, defaults, and trade-offs; its authority comes
from his explicit choices and stable patterns. A procedure skill records how
to do a job; its confidence comes from execution, iteration, recovery, and
verification. The distinction helps locate ownership, but should not be forced
when a task genuinely needs both.

Practical consequences:

- Give each skill a responsibility that fits in one clear sentence.
- Keep conversation style and adjacent workflow outside a technical skill
  unless they are part of the same invariant.
- Make dependencies explicit and coupling explainable.
- Prefer a replaceable specialist over a broad one-size-fits-all system.

## 3. Preserve intellectual juice

Intellectual juice is the thought, experiments, failures, and judgment a
creator has compressed into reusable agent behavior. A strong external skill
is an investment of attention, not merely a prompt whose wording can be freely
replaced.

Prefer an adapter to a rewrite. Make the smallest Anders-specific change that
fits the skill into his toolbox, closer to LoRA than retraining. Preserve the
creator's working procedure, useful structure, intent, and hard-won edge cases.
Change the assumptions, coupling, or preferences Anders has actually chosen
differently.

Do not import the creator's whole interaction system by default. Their
procedures may carry proven expertise; their taste and surrounding workflow
remain proposals until Anders adopts them. Isolate the smallest coherent
responsibility that contains the valuable work, and keep only the dependencies
that responsibility needs.

Preserve provenance and the ability to compare future upstream changes. Track
where the behavior came from, what Anders changed, and why. Port later
improvements deliberately rather than treating byte-for-byte synchronization
as the goal. Test borrowed procedures against realistic local work before
treating them as established behavior.

Rewrite broadly only when the original structure prevents a clean boundary or
cannot express Anders's chosen behavior without continued friction. Even then,
identify which parts of the original procedure carried the intellectual juice
and retain them intentionally.

Practical consequences:

- Inspect an external skill's procedure, assumptions, dependencies, and
  provenance before changing it.
- Preserve more than you replace.
- Adapt only the Anders-specific seam unless the original structure blocks it.
- Separate borrowed expertise from borrowed preferences.
