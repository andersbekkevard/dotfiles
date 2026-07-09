# <Repo> — Agent Boot

<!-- Copy this file to the new repo root as AGENTS.md, symlink CLAUDE.md → AGENTS.md,
     fill every <slot>, delete comments. Bindings and pointers only — protocol lives
     in the global skills and ~/.claude/CLAUDE.md; restating it here is doc drift. -->

You are operating in <one line: what this repo is and is for>.

## Read these in this order

1. <constitution / meta-docs entrypoint, e.g. docs/README.md — or delete if none yet>
2. <root map / index file, if the repo has one>
3. <live-state docs: the docs that always describe current reality>

## Bindings

- **Planning** lands per the global `wayfinder` skill; this repo's maps live at
  `<docs/prd/<slug>/map.md>`. Plans → PRDs in `<docs/prd/>`; todos → beads.
- **Tracker**: beads, prefix `<prefix>`; labels: `<label set, or "plain unlabeled">`.
  See the global `beads` skill; repo-specific rules in `<docs/beads.md or "none yet">`.
- **Work register**: `<path, or "none — br list is the register">`. Every PRD,
  effort map, and open epic must be reachable from it.
- **Decisions** → ADRs in `<adr home>`, per `<adr conventions doc or "the global
  domain-modeling skill's three-part test">`. Glossary: `<CONTEXT.md / glossary path>`.
- **Human-only areas**: `<paths the agent reads but never writes, or "none">`.
- **Agent surface**: repo skills in `.agents/skills/`; reflections in
  `.agents/reflections/`; dream runtime in `.agents/dreams/`.

## Authority (typed, per question)

Current intent → the effort's map / the work register. Today's behavior → the
code and the owning docs (present tense). Rules → this file and `<docs/>`.
Why → ADRs and decision logs. Maps speak future tense, live docs present
tense; divergence is licensed while an effort is open, forbidden after close.
On contradiction: trust per type, flag with `br q "<finding>" -l doc-drift`,
never silently obey or rewrite the older claim.

## Core rules

- Behavior changes update the owning doc in the same commit; an effort's close
  includes reconciling docs its decisions invalidated.
- <repo-specific hard rules: runtimes, singletons, data-plane gates — one line
  each, pointer to the owning doc for detail>

## Project context

<the unchanging two-minute brief: who, what, why, when — the paragraph a fresh
session needs before any task>
