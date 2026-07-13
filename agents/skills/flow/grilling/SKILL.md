---
description: Grill the user relentlessly about a plan or design. Use when the user wants to stress-test a plan before building, or uses any 'grill' trigger phrases.
name: grilling
disable-codex-model-invocation: true
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering. Keep each question's framing and recommendation short — under ~300 words, prose-first — so it reads as a conversation, not a report.

If a *fact* can be found by exploring the codebase, look it up rather than asking me. The *decisions*, though, are mine — put each one to me and wait for my answer.

Do not enact the plan until I confirm we have reached a shared understanding.

When the grill converges on a hard-to-reverse, non-obvious trade-off decision, route the outcome to an ADR (via the `domain-modeling` skill's three-part test) so the reasoning survives independent of this conversation.
