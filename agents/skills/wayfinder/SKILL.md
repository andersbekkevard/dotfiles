---
description: Plan a huge chunk of work — more than one agent session can hold — as a shared map of investigation tickets, resolved one at a time until the way to the goal is clear.
name: wayfinder
disable-model-invocation: true
---

A loose idea has arrived — too big for one agent session, and wrapped in fog: the route from here to a plan isn't visible yet. This skill charts it as a **shared map** of ticket files in the repo, then works the tickets one at a time. The map is domain-agnostic — engineering work, course content, whatever fits the shape.

## Where it lives

`docs/prd/<effort-slug>/` by default — follow the repo's planning-material conventions if they name a different home. The folder holds `map.md` plus `issues/NN-<slug>.md`, numbered from `01`.

## Refer by name

Every map and ticket has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare number or slug. A wall of `04, 07, 12` is illegible; names read at a glance. The number and path don't vanish — a name wraps its link — but they ride *inside* the name, never stand in for it.

## The Map

`map.md` is the canonical artifact: the whole effort at low resolution, loaded once per session. It is an **index**, not a store. It lists the decisions made and points at the tickets that hold their detail; a decision lives in exactly one place — its ticket — so the map never restates it, only gists it and links. Open tickets are **not** listed — they are the unresolved files under `issues/`.

```markdown
## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- the index — one line per resolved ticket: enough to judge relevance, then zoom the link for the detail the ticket holds -->

- [<resolved ticket title>](issues/NN-<slug>.md) — <one-line gist of the answer>

## Fog

<!-- see "Fog of war" for what belongs here -->
```

### Tickets

Each ticket is one file, `issues/NN-<slug>.md`; the number is its identity. State is plain lines near the top:

- `Type:` — one of `research`, `prototype`, `grilling`, `task` (see [Ticket Types](#ticket-types)).
- `Status:` — absent while open; `claimed` while a session works it; `resolved` when done.
- `Blocked by: NN, NN` — a ticket is **unblocked** when every ticket it lists is resolved.

The body is the question, sized to one 100K token agent session:

```markdown
## Question

<the decision or investigation this ticket resolves>
```

The **frontier** is the open, unblocked, unclaimed tickets, lowest number first — the edge of the known. The answer isn't part of the body — it's appended under `## Answer` on resolution (see [Work through the map](#work-through-the-map)). Assets created while resolving a ticket are linked from it, not pasted in.

## Ticket Types

- **Research**: Reading documentation, third-party APIs, or local resources like knowledge bases. Creates a markdown summary as a linked asset. Use when knowledge outside the current working directory is required.
- **Prototype**: Raise the fidelity of the discussion by making a cheap, rough, concrete artifact to react to — an outline, a rough take, a stub, or UI/logic code via the /prototype skill. Links the prototype as an asset. Use when "how should it look" or "how should it behave" is the key question.
- **Grilling**: Conversation with the agent. Uses the /grilling and /domain-modeling skills. Asks one question at a time. The default case.
- **Task**: Literal manual work that must be done before the discussion can move forward — nothing to decide, prototype, or research. Moving data, signing up for a service, provisioning access. The agent automates it where it can; otherwise it hands the human a precise checklist. Resolved when the work is done; the answer records what was done and any resulting facts (credentials location, new URLs, row counts) later tickets depend on.

## Fog of war

The map is _deliberately_ incomplete: don't chart what you can't yet see. Beyond the tickets lies fog — the dim view of decisions and investigations you can tell are coming but can't yet pin down, because they hang on questions still open. Resolving a ticket clears the fog ahead of it, graduating whatever's now specifiable into fresh tickets — one at a time, until the way to the goal is clear and no tickets remain.

The map's **Fog** section is where that dim view is written down: the suspected question, the area to revisit later, the risk you're deferring. Write as loosely or as fully as the view allows; it doubles as a signpost for collaborators reading where the effort is headed.

**Fog or ticket?** The test is whether you can state the question precisely now — _not_ whether you can answer it now.

- **Ticket when** the question is already sharp — even if it's blocked and you can't act on it yet.
- **Fog when** you can't yet phrase it that sharply. Don't pre-slice fog into ticket-sized pieces: it's coarser than a ticket, and one patch may graduate into several tickets, or none, once the frontier reaches it.

Fog excludes only what's already decided (that's Decisions so far) and what's already a ticket.

## Invocation

Two modes. Either way, **never resolve more than one ticket per session.**

### Chart the map

User invokes with a loose idea.

1. Run a `/grilling` and `/domain-modeling` session to surface the open decisions.
2. **Create the effort folder and `map.md`**: Notes filled in, Decisions-so-far empty, Fog sketched.
3. **Create the tickets you can specify now** as numbered files under `issues/`, then wire `Blocked by:` edges once all numbers exist. Wiring sorts them into the frontier and the blocked; everything you can't yet specify stays in the Fog.
4. Stop — charting the map is one session's work; do not also resolve tickets.

### Work through the map

User invokes with a map (path or effort slug). A ticket is **optional** — without one, you pick the next decision, not the user.

1. Load the **map** — the low-res view, not every ticket body.
2. Choose the ticket. If the user named one, use it. Otherwise take the first frontier ticket in order. **Claim it**: set `Status: claimed` and save before any work.
3. Resolve it — **zoom as needed**: read the full body of any related or resolved ticket on demand; invoke the skills the `## Notes` block names. If in doubt, use `/grilling` and `/domain-modeling`.
4. Record the resolution: append the answer under `## Answer`, set `Status: resolved`, and **append a context pointer** to the map's Decisions-so-far.
5. Add newly-surfaced tickets (numbered after the highest existing); graduate any fog the answer has made specifiable, clearing each graduated patch from the Fog so it lives only as its new ticket. If the decision invalidates other parts of the map, update or delete those tickets.

The user may run unblocked tickets in parallel, so expect other sessions to be editing the effort folder concurrently — re-read a ticket immediately before claiming it.
