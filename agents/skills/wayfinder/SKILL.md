---
name: wayfinder
description: Plan a huge chunk of work — more than one agent session can hold — as a shared map of investigation tickets on the repo's issue tracker, resolving one ticket at a time until the way to the destination is clear.
disable-model-invocation: true
---

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** is not visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** on the repo's issue tracker, then resolves one ticket per session until the route is clear.

The destination varies per effort, and naming it is the first act of charting. It might be a PRD ready to author, a decision to lock before planning starts, or a change whose shape must be discovered before execution. The map is domain-agnostic — engineering work, course content, whatever fits the shape.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when the way is clear — nothing important remains to decide before someone goes and does the thing. The pull to just implement is usually the signal that you reached the edge of the map and should hand off to the repo's normal execution workflow.

## Refer by name

Every map and ticket has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible; names read at a glance. The id and URL do not vanish — a name wraps its link — but they ride *inside* the name, never stand in for it.

## The Map

The map is a single issue on this repo's issue tracker. Its tickets are child issues of the map.

The map is an **index**, not a store. It lists the decisions made and points at the tickets or linked artifacts that hold their detail; a decision lives in exactly one detailed place, so the map never restates it, only gists it and links. Open tickets are not listed in the map body — they are open child issues, found by tracker query.

**Tracker issues hold coordination and short indexes. Substantial reasoning lives in linked repo artifacts unless the repo explicitly uses its tracker as the document store.** Research summaries, prototypes, PRDs, ADRs, and domain docs should live where the repo normally stores those artifacts; the ticket links to them.

```markdown
## Destination

<what reaching the end of this map looks like — the PRD, decision, or change this effort is finding its way to>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- one line per closed ticket: enough to judge relevance, then zoom the link for detail -->

- [<closed ticket title>](link) — <one-line gist of the answer>

## Not yet specified

<!-- in-scope fog that cannot be ticketed yet -->

## Out of scope

<!-- consciously ruled beyond this destination -->
```

### Tickets

Each ticket is a child issue of the map. The issue id is its identity. Its body is the question, sized to one 100K token agent session:

```markdown
Wayfinder type: research | prototype | grilling | task
Mode: AFK | HITL

## Question

<the decision or investigation this ticket resolves>

## Expected output

<decision, summary link, prototype link, checklist result, or plan amendment>
```

Use the tracker's native blocking relationship when it has one. A ticket is **unblocked** when every ticket blocking it is closed. The **frontier** is the open, unblocked, unclaimed child tickets — the edge of the known.

The answer is recorded on resolution as a concise comment or close reason. If the answer needs paragraphs, tables, source notes, or design prose, write a repo artifact and link it from the ticket.

## Ticket Types

Every ticket is either **HITL** — human in the loop, worked *with* a human who speaks for themselves — or **AFK**, driven by the agent alone. A HITL ticket only resolves through that live exchange; the agent never stands in for the human's side of it.

- **Research** (AFK): Reading documentation, third-party APIs, or local resources like knowledge bases. Creates a linked summary artifact. Use when knowledge outside the current working directory is required.
- **Prototype** (HITL): Raise the fidelity of the discussion by making a cheap, rough, concrete artifact to react to — an outline, a rough take, a stub, or UI/logic code via the /prototype skill. Links the prototype as an asset. Use when "how should it look" or "how should it behave" is the key question.
- **Grilling** (HITL): Conversation via the /grilling and /domain-modeling skills, one question at a time. The default case.
- **Task** (HITL or AFK): Manual work that must happen before a *decision* can be made — nothing to decide, prototype, or research, but the discussion is blocked until it is done. This type does, but only to unblock a decision; it does not deliver the destination.

## Fog of war

The map is _deliberately_ incomplete: don't chart what you can't yet see. Beyond the live tickets lies the **fog of war** — the dim view of decisions and investigations you can tell are coming but can't yet pin down, because they hang on questions still open. Resolving a ticket clears the fog ahead of it, graduating whatever is now specifiable into fresh tickets — one at a time, until the way to the destination is clear and no tickets remain.

The map's **Not yet specified** section is where that dim in-scope view is written down: the suspected question, the area to revisit later, the risk you're deferring. Write as loosely or as fully as the view allows.

**Fog or ticket?** The test is whether you can state the question precisely now — _not_ whether you can answer it now.

- **Ticket when** the question is already sharp — even if it's blocked and you can't act on it yet.
- **Not yet specified when** you can't yet phrase it that sharply. Don't pre-slice fog into ticket-sized pieces: it is coarser than a ticket, and one patch may graduate into several tickets, or none, once the frontier reaches it.

**Not yet specified** excludes what's already decided, what's already a live ticket, and what's out of scope.

## Out of scope

Fog only ever gathers _toward_ the destination. The destination fixes the scope, so work beyond it is **out of scope** — it is not fog, and it does not belong in **Not yet specified**.

Out-of-scope work never graduates. It returns only if the destination is redrawn, and then as a fresh effort, not a resumption. When a live ticket turns out to sit past the destination, close it and leave one line in **Out of scope** with the gist, why it is out, and a link to the closed ticket.

## Tracker adapters

Follow the repo's issue-tracker conventions before inventing wayfinder-specific mechanics. If the repo has tracker docs, they own the exact commands, labels, and query shape.

### project / beads

project uses beads for coordination, not as the place to write fleshed-out ideas.

- Map = umbrella/planning epic bead, never a launch-unit implementation epic.
- Child tickets = child task beads.
- Keep the existing project workstream label. Do not use `wayfinder:*` labels.
- Put `Wayfinder type:` and `Mode:` fields in the ticket body instead of labels.
- Use `br dep add <ticket> <blocker> --type blocks` for ordering.
- Use `br update <ticket> --claim` as the claim lock.
- Record resolution as a concise comment plus close reason.
- Link heavy artifacts under `docs/prd/<effort>/wayfinding/` or the natural owning path.

## Invocation

Two modes. Either way, **never resolve more than one ticket per session.**

### Chart the map

User invokes with a loose idea.

1. **Name the destination.** Run a `/grilling` and `/domain-modeling` session to pin down what this map is finding its way to.
2. **Map the frontier.** Grill breadth-first: fan out across the whole space rather than deep on one thread. If this surfaces no fog, you do not need a map; stop and ask how to proceed.
3. **Create the map**: Destination and Notes filled in, Decisions-so-far empty, fog sketched into **Not yet specified**.
4. **Create the tickets you can specify now** as child issues of the map, then wire blocking edges in a second pass once issue ids exist.
5. Stop — charting the map is one session's work; do not also resolve tickets.

### Work through the map

User invokes with a map. A ticket is **optional** — without one, you pick the next decision, not the user.

1. Load the **map** — the low-res view, not every ticket body.
2. Choose the ticket. If the user named one, use it. Otherwise take the first frontier ticket in tracker order. Claim it before any work.
3. Resolve it — **zoom as needed**: fetch the full body of any related or closed ticket on demand; invoke the skills the Notes block names. If in doubt, use `/grilling` and `/domain-modeling`.
4. Record the resolution: concise tracker resolution plus links to any substantial artifact; close the ticket; append a context pointer to the map's Decisions-so-far.
5. Add newly surfaced tickets, graduate specifiable fog out of **Not yet specified**, and move out-of-destination work to **Out of scope**.

The user may run unblocked tickets in parallel, so expect other sessions to be editing the tracker concurrently.

When the frontier is empty and no fog remains, the map is complete: hand the effort to `/to-prd`, which synthesizes the resolved decisions into `prd.md` beside `map.md`.
