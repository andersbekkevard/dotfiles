---
name: wayfinder
description: "Durable planning. Use when a planning conversation should become durable — 'write this down', 'document this so we can pick up later' — or to chart and work a map of investigation tickets for an effort too big for one session. Owns the map: the register every planning artifact hangs off."
---

# Wayfinder

Cross-conversation planning fails at the context boundary: the shared
understanding built in one conversation dies at the next. Wayfinder makes it
survive, in one artifact per effort: the **map** — the current-intent
**register** that always answers *what are we doing, toward what, what's
decided, what's deliberately still open*. Everything else — tickets, charter,
slices — exists only when a reader who lacks this context exists.

## The Map

One map per effort, at the repo's planning home (the repo constitution names
it; default `docs/prd/<effort-slug>/map.md`). It is an **index, not a store**:
it gists and links; each decision's detail lives in exactly one place.

```markdown
## Destination

<what reaching the end looks like — the decision, change, or product this
effort is finding its way to>

## Notes

<domain; skills every session should consult; standing preferences>

## Decisions so far

<!-- append-only log: one line per resolution — gist + link to detail.
     Never edit a past entry; a changed decision gets a NEW entry that
     supersedes the old by name. -->

- [<name>](link) — <one-line gist of the answer>

## Not yet specified

<!-- fog: in-scope questions too dim to phrase sharply yet, and details
     deliberately skipped to stay at direction-altitude. This section is what
     lets a successor interrogate instead of guessing. -->

## Out of scope

<!-- consciously ruled beyond this destination, so no session re-litigates -->
```

**Refer by name.** In everything Anders reads, call maps and tickets by their
title, never a bare id — the id rides inside the link.

**The register discipline** (the completion criterion of every wayfinder
action): nothing is resolved until its decision line is in the map, and
nothing is current in the map that has been superseded without saying so. A
pivot is an *edit to the register* — the old direction explicitly superseded —
never just a new artifact beside the old one.

## Branch 1 — Land a conversation

A planning conversation (usually skill-less) has built understanding, and
Anders wants it durable. **Pure synthesis — never re-interview him.**

1. Create or update the map from the conversation: destination, decision lines
   with reasoning gists, and — as important as the decisions — the **fog**:
   what was deliberately left undecided or skipped. Most re-explaining happens
   because a successor can't tell *decided* from *never discussed*; the fog
   section is that distinction.
2. Add the effort to the repo's work register if it has one.
3. Only if questions must **wait** — blocked, need research, or delegated —
   create tickets for them (below). Questions the conversation answered are
   decision lines, not tickets.

Done when a stranger could read the map and know the destination, what is
settled, and where understanding is thin.

## Branch 2 — Chart and work a map

For an effort too big or too foggy for one session.

**Chart:** name the destination (grill if it is not sharp — `/grilling`,
`/domain-modeling`), sketch the fog, create tickets for the questions you can
already state precisely, wire blocking edges. Don't pre-slice fog into
ticket-sized pieces — one patch may graduate into several tickets, or none.
**Fog or ticket?** Ticket when the question is stateable now, even if blocked;
fog when it isn't. Charting is one session's work.

**Work:** load the map (the low-res view — zoom into ticket bodies on
demand), take the frontier (open, unblocked, unclaimed), claim before working.
Resolve as many tickets per sitting as judgment allows — the register
discipline, not a pacing rule, is the guard; fog-heavy exploration naturally
goes slower than deadline-driven resolution. Per resolution: record the answer
(concise close + link to any substantial artifact), append the decision line,
graduate newly-stateable fog into tickets, move out-of-destination work to
Out of scope. Other sessions may be working the same map concurrently.

### Tickets

A ticket is an open question that must **outlive or leave this session** —
blocked, needs research, prototyped, or worked in parallel. It is a child
issue of the map on the repo's tracker (follow the repo's tracker conventions;
for beads, the `beads` skill — `--parent` for children, `br dep add` for
blockers, claim as the lock, resolution as close reason):

```markdown
Wayfinder type: research | prototype | grilling | task
Mode: AFK | HITL

## Question

<the decision or investigation this ticket resolves>

## Expected output

<decision, summary link, prototype link, or plan amendment>
```

HITL tickets (grilling, most prototypes) resolve only through live exchange
with Anders; never stand in for his side. AFK tickets (research, most tasks)
run alone. Substantial reasoning lives in linked repo
artifacts; tracker text stays gist + link.

## Downstream — reader-gated, never automatic

When the frontier is empty and no fog remains, the way is clear. What happens
next depends on who must read the plan, and Anders decides:

- **Ownership will cross a context boundary** (big-ownership handoff, blind
  verification) → compile a charter: `/to-prd`.
- **Execution will fan out or span sessions** → slice to the tracker:
  `/to-issues`.
- **Neither** — the same conversation implements, Anders steering → the map's
  decisions *are* the spec; go build against them.
