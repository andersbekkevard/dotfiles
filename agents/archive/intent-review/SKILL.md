---
name: intent-review
description: Review finished work against intent: derive the expectations Anders would hold blind from the plan artifacts, then check each against reality.
disable-model-invocation: true
---

# Intent Review

Verification proves the letter: V holds. This review asks whether the build upheld the spirit — the shared mental model behind the goal, which dies at the handoff, and which an implementer optimizing against V can cheat without failing a single check. The mechanism is blind grading: derive the expectations Anders would hold from the plan artifacts alone, then check each against what was actually built.

It is the back gate to `goal-fuzz`'s front gate. Goal-fuzz is done well exactly when this review returns `UPHELD`; a `BROKEN` review on a fuzzed goal indicts the goal text, not just the build.

## Leading Words

- **expectation** — the unit: one concrete observable Anders would check ("open the workbook — its coloring matches the golden one"; "a single command exists and runs clean"), entailed by the shared mental model, citing the artifact statement that entails it.
- **blind** — expectations are written before any look at the code, the output, or the implementer's reasoning. A reviewer who reads the submission first grades with the implementer's answer key.
- **cheat** — a build that satisfies the letter of V while breaking the spirit. Goal-fuzz hunts it before dispatch; this review catches the one that survived. Probe the mechanism behind every surface match: a coloring that matches because it was hard-coded is a cheat, not a pass.
- **upheld** — the verdict grammar: binary per expectation, no partial credit, strict overall — one violated in-scope expectation breaks the review.
- **ratchet** — every confirmed violation becomes a permanent check appended to V. V only tightens toward intent; the next run starts from the tighter V.
- **oracle** — only Anders knows what he meant. Expectations with debatable grounding get his cheap in/out ruling; never guess, never inflate scope to manufacture findings.

## Two Ways In

- **Review this** — inline ("did this capture what I meant", "intent-review the result"). Report the verdict inline.
- **Review a bead / closeout** — read the bead's `## Success Criteria` and its dossier or plan as the mental-model artifacts; treat the owner's checks as V.

For loaded terms (primitive, semantic, durable, canonical, source-backed, provenance, one-shot…), expectations must target the mechanism, not artifact parity — the loaded term is where a cheat hides.

## Loop

1. **Frame.** Gather the mental-model artifacts — goal, plan, dossier, or bead criteria, plus goal-fuzz seed stories — and name V (the checks the build passed) and I (the diff or working tree). If V cannot be located, reconstruct it from what I actually passes and say so. Done when all three have concrete sources.
2. **Write the rubric blind.** Dispatch a subagent (Agent tool) given *only* the mental-model artifacts. It returns the expectations Anders would check, each observable and each citing the statement that entails it; seed stories enter verbatim, pre-confirmed in-scope. Done when every expectation is observable, cited, and written without sight of V or I.
3. **Check.** Now open reality. Verify each expectation with evidence — run the command, open the file, diff expected against actual — and probe the mechanism behind any surface match. Per expectation: `UPHELD` or `VIOLATED` with the expected-vs-actual diff, or `UNCHECKED` when no clean check exists. Never report upheld on an expectation you could not check. Done when every expectation carries an evidenced verdict.
4. **Rule.** Send expectations with debatable grounding to the oracle as in/out rulings. Done when every violation is confirmed in-scope or ruled out.
5. **Fix and ratchet.** Default is auto-fix: make I uphold each confirmed violation, then ratchet its check into V. `--report` writes nothing — emit the rubric and the proposed ratchets. Either way, if the goal was fuzzed, note what the sharpened text failed to carry so the front gate learns. Done when every confirmed violation is fixed-and-ratcheted or proposed, and every debatable one is surfaced.

## Verdict

- `UPHELD` — every in-scope expectation upheld with evidence.
- `BROKEN` — at least one confirmed violation. Strict: no partial credit.
- `INCONCLUSIVE` — a decisive expectation could not be cleanly checked. Say which and why.

## Report

Lead with the verdict, then the expectations — violations first, each with its expected-vs-actual diff; upheld ones with their evidence in a line. Name the ratcheted checks and, when a fuzzed goal broke, the front-gate note. Prose, not a form: the report is read by Anders, and one deep violation deserves paragraphs where ten upheld lines deserve a sentence. For a bead, end with a searchable line: `INTENT-REVIEW <id> <VERDICT>`.

## Record

**Review this:** report inline; in `--report` mode capture durable gaps with `br q "<title>" -l triage`.

**Review a bead:** follow the `beads` skill.
- `UPHELD` → comment the rubric as evidence; leave state unchanged.
- `BROKEN` → default: comment the fixes and ratcheted checks. Report mode: `br reopen <id>`, label `intent-gap`, comment the numbered violations.
- `INCONCLUSIVE` → leave state unchanged; comment what blocked a clean check.
