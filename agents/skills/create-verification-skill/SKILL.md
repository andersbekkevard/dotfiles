---
name: create-verification-skill
description: "Create a project-local verification skill that drives the real app as a user and captures evidence. Use when a project lacks a repeatable way to prove UI, CLI, service, or library behavior."
disable-model-invocation: true
---

# Create a verification skill

Create a project-local skill that lets a fresh agent launch the real product,
exercise it through a user-facing seam, and retain evidence. Write it for an
agent arriving cold.

## Understand the product

Answer these from the repository before asking Anders:

- **Surface:** what does the user touch: web UI, CLI, desktop or mobile app,
  API, or library?
- **Run:** how does it start locally, including readiness, authentication,
  fixtures, ports, and environment?
- **Drive:** which existing harness can operate the real surface? Prefer the
  project's own Playwright, Cypress, PTY, CLI, HTTP, or debug tooling.
- **Observe:** which screenshots, transcripts, responses, logs, exit codes,
  files, or stored values prove the result?
- **Isolate:** can verification use distinct ports, profiles, and data? If not,
  the skill must refuse to drive an unowned shared instance.

Establish whether the current checkout can run before documenting it. Report a
broken baseline precisely; do not encode guessed recovery steps as procedure.

## Create the project-local skill

Follow the repository's project-skill convention. Prefer
`.agents/skills/verify-<app>/` when the repository has no other convention.
Give the generated skill these grounded sections, with no placeholders:

- **Launch:** exact start, readiness, and teardown procedures. For a short-lived
  CLI, launch means preparing it once and driving each case in an isolated
  process or PTY.
- **Doctor:** a read-only check that confirms the instance, build, ownership,
  authentication, and relevant state are worth driving.
- **Drive:** exact commands and stable user-facing handles from this project.
- **Evidence:** where proof lives and what each artifact establishes. Capture
  both the action and resulting state, including externally visible side
  effects. Use mocks only at an existing production boundary.
- **Cleanup:** stop only processes the run started and remove only its scratch
  state. Retain evidence.
- **Helpers:** document every shipped helper at its call site and make it
  directly executable.

Do not trust a mode called `dry-run` merely by name. Observe which files,
network calls, records, or refs it actually changes.

## Seed the feature map

Create `features/README.md` and one file for each of the first three to five
important user-facing features. Read [the feature-map contract](references/feature-map.md)
before writing them.

The map is the maintained verification source. It records every user entry
point worth preserving; proof through one convenient route does not verify
another route.

## Prove the generated skill

Run its instructions end to end once: launch, doctor, drive one mapped feature,
capture evidence, and clean up. After cleanup, confirm the evidence remains and
the started process and scratch state do not. Repair failures and repeat the
real path. An unexecuted verification skill is a draft.

Use `maintain-verification-skill` later to reconcile the skill and feature map
with the changing product.
