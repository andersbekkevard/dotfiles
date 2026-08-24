---
name: wayfinder
description: "Plan a huge chunk of work — more than one agent session can hold — as a shared Markdown map of investigation tickets, and resolve them until the way to the destination is clear. Also use when a planning conversation should become durable — 'write this down', 'document this so we can pick up later' — landing it on the map."
disable-model-invocation: true
---

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared Markdown map** in the repo, then works its tickets until the route is clear.

The destination varies per effort, and naming it is the first act of charting — it shapes every ticket. It might be a spec to hand off and iterate on, a decision to lock before planning starts, or a change made in place like a data-structure migration. The map is domain-agnostic — engineering work, course content, whatever fits the shape.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when the way is clear — nothing left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in its **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## Conversation

Wayfinder binds the artifacts, never the dialogue. Sessions are natural flowing prose conversation — the agent is a thinking partner who reflects, pushes back, and sharpens. The procedure lives entirely in the landing: settled decision → map line + ticket, discovered fact → asset, committed as it happens. Before stopping, sweep the conversation for unlanded residue.

## Refer by name

Every map and ticket has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name as a Markdown link, never by a bare path or slug.

## The Map

The canonical artifact is `map.md` in the repo's planning home (default `docs/prd/<effort-slug>/map.md`). Its investigation tickets live beside it under `tickets/`; substantial research and prototypes live under `assets/`.

The map is an **index**, not a store. It lists the decisions made and points at the tickets that hold their detail; a decision lives in exactly one place — its ticket — so the map never restates it, only gists it and links.

### The map body

The whole map at low resolution, loaded once per session. Open tickets are **not** listed — find them from their metadata under `tickets/`.

```markdown
## Destination

<what reaching the end of this map looks like — the spec, decision, or change this effort is finding its way to. One or two lines; every session orients to it before choosing a ticket.>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Decisions so far

<!-- the index — one line per resolved ticket: enough to judge relevance, then zoom the link for the detail the ticket holds. Append-only: never edit a past line; a changed decision gets a new line that supersedes the old by name. -->

- [<resolved ticket title>](link) — <one-line gist of the answer>

## Not yet specified

<!-- see "Fog of war": in-scope fog you can't ticket yet; graduates as the frontier advances -->

## Out of scope

<!-- see "Out of scope": work ruled beyond the destination; closed, never graduates -->
```

A pivot is an edit to the map — the old direction explicitly superseded in Decisions-so-far — never just a new artifact beside the old one.

### Tickets

Each ticket is a Markdown file under `tickets/`, sized to one 100K token agent session:

```markdown
Type: research | prototype | grilling | task
Mode: AFK | HITL
Status: open | claimed | resolved | out-of-scope
Claimed by: <agent or human name; omit while open>
Blocked by: <ticket links, or none>

## Question

<the decision or investigation this ticket resolves>

## Answer

<filled when resolved; link substantial supporting artifacts>
```

A session **claims** a ticket by setting `Status: claimed` and `Claimed by:`, **first**, before any work, so concurrent sessions skip it.

A ticket is **unblocked** when every ticket in `Blocked by:` is resolved; the **frontier** is the open, unblocked, unclaimed tickets — the edge of the known. Find candidates by searching `tickets/` for `Status: open`, then read only those tickets' blocker fields. Assets created while resolving a ticket are linked from its Answer, not pasted into the map.

## Ticket Types

Every ticket is either **HITL** — human in the loop, worked *with* a human who speaks for themselves — or **AFK**, driven by the agent alone. A HITL ticket only resolves through that live exchange; the agent never stands in for the human's side of it (a grilling agent that answers its own questions has broken this).

- **Research** (AFK): Reading documentation, third-party APIs, or local resources like knowledge bases. Creates a markdown summary as a linked asset. Use when knowledge outside the current working directory is required.
- **Prototype** (HITL): Raise the fidelity of the discussion by making a cheap, rough, concrete artifact to react to — an outline, a rough take, a stub, or UI/logic code. Links the prototype as an asset. Use when "how should it look" or "how should it behave" is the key question.
- **Grilling** (HITL): Resolved in live conversation with the human. The default case.
- **Task** (HITL or AFK): Manual work that must happen before a *decision* can be made — nothing to decide, prototype, or research, but the discussion is blocked until it's done. Signing up for a service so its API can be judged, provisioning access, moving data so its shape can be seen. This is the one type that *does* rather than decides — and it earns its place by unblocking a decision, not by delivering the destination. The agent drives it alone where it can (AFK); otherwise it hands the human a precise checklist (HITL). Resolved when the work is done; the answer records what was done and any resulting facts (credentials location, new URLs, row counts) later tickets depend on.

## Fog of war

The map is _deliberately_ incomplete: don't chart what you can't yet see. Beyond the live tickets lies the **fog of war** — the dim view of decisions and investigations you can tell are coming but can't yet pin down, because they hang on questions still open. Resolving a ticket clears the fog ahead of it, graduating whatever's now specifiable into fresh tickets — one at a time, until the way to the destination is clear and no tickets remain.

The map's **Not yet specified** section is where that dim view is written down: the suspected question, the area to revisit later, the detail deliberately skipped to stay at direction-altitude. It's the undiscovered frontier _toward_ the destination — everything here is in scope, just not sharp enough to ticket. Write as loosely or as fully as the view allows; it doubles as a signpost for collaborators reading where the effort is headed — the line between *decided* and *never discussed*.

**Fog or ticket?** The test is whether you can state the question precisely now — _not_ whether you can answer it now.

- **Ticket when** the question is already sharp — even if it's blocked and you can't act on it yet.
- **Not yet specified when** you can't yet phrase it that sharply. Don't pre-slice the fog into ticket-sized pieces: it's coarser than a ticket, and one patch may graduate into several tickets, or none, once the frontier reaches it.

**Not yet specified** excludes what's already decided (Decisions so far), what's already a live ticket, and what's out of scope (the next section).

## Out of scope

Fog only ever gathers _toward_ the destination. The destination fixes the scope, so work beyond it is **out of scope** — it isn't fog, and it doesn't belong in **Not yet specified**. It gets its own **Out of scope** section on the map: work you've consciously ruled out of _this_ effort. Scope, not sharpness, lands it here.

Out-of-scope work never graduates — the frontier stops at the destination — so it returns only if the destination is redrawn, and then as a fresh effort, not a resumption.

Ruling something out of scope is a scoping act, not a step on the route. When a ticket that already exists turns out to sit past the destination — mis-scoped in while charting, or exposed by a resolution — set `Status: out-of-scope` and leave one line in the **Out of scope** section: the gist plus why it's out of scope, linking the ticket. It stays out of **Decisions so far**, which records the route actually walked — a scope boundary isn't a step on it.

## Invocation

Three modes. Resolve as much per sitting as the conversation genuinely settles — the guard is recording each resolution on the map, not the pacing.

### Land a conversation

User invokes after a planning conversation (usually skill-less) has built the understanding — "write this down so we can pick up later." Pure synthesis; never re-interview.

1. Create or update the map from the conversation: Destination, one Decisions-so-far line per settled decision (detail stays where it lives — link it), and the fog — what was deliberately left undecided or skipped, so a successor interrogates instead of guessing.
2. Add the effort to the repo's work register if it has one.
3. Create tickets only for questions that must **wait** — blocked, needing research, or delegated. Questions the conversation answered are decision lines, not tickets.

Done when a stranger could read the map and know the destination, what is settled, and where understanding is thin.

### Chart the map

User invokes with a loose idea.

1. **Name the destination.** Talk it out until it's pinned — the spec, decision, or change this map is finding its way to. The destination fixes the scope, so it's settled first.
2. **Map the frontier.** Go **breadth-first**: fan out across the whole space rather than deep on any one thread, surfacing the open decisions and the first steps takeable now. **If this surfaces no fog** — the way to the destination is already clear, the whole journey small enough for one session — you don't need a map. Stop and ask the user how they'd like to proceed.
3. **Create the map**: Destination and Notes filled in, Decisions-so-far empty, the fog sketched into **Not yet specified**.
4. **Create the tickets you can specify now** as Markdown files, then add their `Blocked by:` links. This sorts them into the frontier and the blocked; everything you can't yet specify stays in the fog — the **Not yet specified** section.
5. Stop — charting the map is one session's work; do not also resolve tickets.

### Work through the map

User invokes with a map path. A ticket is **optional** — without one, you pick the next decision, not the user.

1. Load the **map** — the low-res view, not every ticket body.
2. Choose the ticket. If the user named one, use it. Otherwise take the first frontier ticket in order. **Claim it** in the ticket metadata before any work.
3. Resolve it — **zoom as needed**: read the full body of any related or resolved ticket on demand; invoke the skills the `## Notes` block names.
4. Record the resolution: write its `## Answer`, mark it resolved, and **append a context pointer** to the map's Decisions-so-far.
5. Add newly-surfaced Markdown tickets and their blocker links — but a surfaced question you can already answer in this session is answered and recorded as a decision line, not ticketed; ticket only what must wait. Graduate any fog the answer has made specifiable, clearing each graduated patch from **Not yet specified** so it lives only as its new ticket. If the answer reveals a ticket — this one or another — sits beyond the destination, **rule it out of scope** rather than resolving it on the route. If the decision invalidates other parts of the map, update or delete those tickets.

The user may run unblocked tickets in parallel, so expect other sessions to be editing the shared Markdown concurrently.

## When the way is clear

When the frontier is empty and no fog remains, hand off by reader: `/to-spec` when ownership will cross a context boundary (big-ownership handoff, blind verification), then `/to-tickets` when the work should become claimable execution — one ticket may carry the whole spec, or several may expose a frontier. Neither reader coming — the map's decisions are the spec, and the user's session builds against them.
