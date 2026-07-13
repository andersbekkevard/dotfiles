---
name: recap
description: "Re-orient Anders after time away: a prose TLDR of where we are, what was decided, and the next decision he needs to make. Use for 'where are we', 'TLDR', 'recap', 'I was away', 'what's the status', 'what's next'."
disable-codex-model-invocation: true
---

# Recap

Anders returns after being away and needs to re-enter fast. The deliverable is
a short prose briefing — not a changelog, not a bullet dump.

## Gather (quickly, in parallel)

- This session's own context, if any.
- The repo's work registry and tracker where present (a work/initiatives doc,
  `br list` for open beads).
- `git log --oneline -15` for what actually landed recently.
- Anything in flight: running fan-outs or lanes, unfinished migrations,
  pending verification reports.

## Answer format — hard rules

- **Prose. No bullet points, no headers.** This is non-negotiable; he asks for
  it verbatim every time.
- **Lead with the decision:** the single most important thing Anders needs to
  decide or unblock right now, in the first sentence.
- Then, in order: what has happened since he left, what is in flight, what the
  next step is.
- **Name unratified assumptions:** any judgement calls agents made recently
  that he hasn't explicitly approved (convention choices, overrides,
  placements).
- ≤250 words. No fluff, no praise, no restating what he already knows.
