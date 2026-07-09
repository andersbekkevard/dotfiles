# agents/archive — retired skills

Skills that are no longer active. An archived skill keeps its full folder
(`SKILL.md`, agents, references) but is invisible to every harness: nothing
under this folder is linked into `~/.claude/skills` or `~/.codex/skills`, and
`skillctl`, `skilltokens`, and `skillpull` only scan `agents/skills/`.

To archive a skill:

1. `git mv agents/skills/<name> agents/archive/<name>`
2. Remove its entry from `agents/skill-sources.toml` (`skillpull validate`
   requires the manifest to match `agents/skills/` exactly).
3. Fix any references to it in other skills' descriptions or bodies.
4. Run `./setup.sh --layer minimal --skip-install` (or remove the two dangling
   `~/.claude/skills/<name>` / `~/.codex/skills/<name>` links and run
   `agents/skillctl sync`) so the harness links are pruned.

To restore, reverse the same steps. Record why a skill was archived in the
commit message that moves it.

## Contents

- `goal-fuzz`, `intent-review` — front-gate/back-gate goal-contract hardening.
  Built for the gpt-5.6-era failure mode of cheating and overfitting to narrow
  readings of a goal; Mythos-class models don't need the scaffolding.
- `review-changes` — beads-adapted port of mattpocock code-review. Archived
  2026-07-09: builtin /code-review, codex review, and autoreview cover review
  well; a bespoke two-axis protocol over-encoded it.
- `implement` — orchestration pointer (claim → tdd → review → close). Archived
  2026-07-09 on two-corpus dream evidence: silently absent for a week at zero
  cost, routed around even on textbook triggers; its one load-bearing line
  (claim/close lifecycle) lives in the `beads` skill.
