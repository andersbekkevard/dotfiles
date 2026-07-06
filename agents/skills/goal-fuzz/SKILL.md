---
description: Goal fuzzing. Use to sharpen success criteria, bead acceptance, dossiers, or autonomous-owner briefs until they cannot be misread or cheaply passed.
name: goal-fuzz
disable-model-invocation: true
---

# Goal Fuzz

A goal is a contract handed across a context boundary. The shared understanding built in conversation dies at the handoff: the implementer sees only the goal text, and an agent optimizing against a verifiable criterion will find the cheapest build that satisfies its letter. Goal-fuzz tests, before dispatch, whether the text alone carries the end state.

It is the front gate to `intent-review`'s back gate: this fires before dispatch and sharpens the contract; intent-review grades the delivered end state against it after. The in-scope readings ruled here become its seed stories, and a `BROKEN` intent-review on a fuzzed goal is a goal-fuzz defect — the text failed to carry the intent.

## Leading Words

- **cold** — the brancher sees only G, never the intended reading, spec draft, or plan. Shown the intent, it anchors and stops finding forks.
- **cheat** — the cheapest build that satisfies G's letter. If the cheat would disappoint Anders, the goal leaks intent.
- **spread** — the divergence across readings; the signal this skill drives down.
- **bisect** — ask the question that eliminates the most divergent builds. One sharp cut beats ten cosmetic ones.
- **fixed point** — the done state: a cold re-fuzz produces no new fork.
- **oracle** — only Anders knows what he meant. On a real fork, ask; never guess.

## Two Ways In

- **Sharpen this** — the goal comes from the conversation; report the sharpened goal inline and carry the seed stories into the implementation.
- **Sharpen a spec** — pointed at a draft bead `## Success Criteria` or a dossier; write the converged goal back before an owner is dispatched.

Mandatory before loaded-term work — primitive, semantic, durable, reusable, canonical, source-backed, provenance, production, one-shot — these must converge to mechanism-level meanings before an owner starts.

## Loop

1. **Frame.** Capture G as one concrete statement with its source. Note what Anders already treats as settled — do not re-litigate it. Done when G is one stated goal with a source.
2. **Branch cold.** Dispatch a subagent given *only* G. It returns (a) divergent **readings** grouped by **axis** — the dimension along which intent forks (scope boundary, edge handling, definition of done, the tradeoff being optimized) — and (b) the **cheat**: the laziest implementation it could defend as satisfying G. Done when every axis shows its divergent options and the cheat is stated.
3. **Bisect.** Rank axes by how much resolving them changes the build — a fork that produces materially different code outranks a cosmetic one, and the cheat marks where letter and intent diverge most. Ask Anders forced-choice questions, highest-impact first, at most three per round; drop any question whose answers all yield the same build. Prefer one tracer-bullet over an interrogation when a cheap prototype would disambiguate faster than Anders can answer — say so and defer. Done when every high-impact axis has a ruling or an explicit defer.
4. **Rewrite and re-fuzz.** Fold the rulings into a rewritten G: nail resolved axes, mark rejected readings out-of-scope, and kill the cheat — if the cheat still passes the rewritten G, the rewrite failed. For loaded terms, define the mechanism and name the forbidden shortcuts: labels/wrappers/renames, metric drift, broad masks, fallbacks, proxy passes. Re-branch cold on the rewrite; a new high-impact fork returns to step 3. Cosmetic spread is not a defect — stop at the **fixed point**, or when Anders accepts the residual forks as deferred.
5. **Emit.** Report and record per the rules below. Done when the sharpened G, seed stories, and out-of-scope list are recorded where the implementer will read them.

## Emit

- `SHARP` — fixed point reached; ready to implement.
- `DEFERRED` — residual forks accepted as named risks, under build-the-likely-one-and-react.
- `BLOCKED` — a high-impact fork awaits an oracle ruling; not ready. Do not let an owner start.

Report with the sharpened G first, then the axes with their rulings, the cheat and the line in G that now kills it, the seed stories (a handoff — each concrete enough for the implementer and intent-review to act on), the out-of-scope readings, and any open forks with why they stayed open. Prose, not a form; depth goes to the forks that mattered. For a bead, end with a searchable line: `GOAL-FUZZ <id> <VERDICT>`.

Recording — inline goal: report in chat. Spec or bead: follow the `beads` skill —
- `SHARP` → write the converged goal into `## Success Criteria`; comment the seed stories and out-of-scope list.
- `DEFERRED` → write the goal with the open forks recorded as named risks in `## Success Criteria`.
- `BLOCKED` → leave the bead un-ready; comment the open fork and what ruling it needs.
