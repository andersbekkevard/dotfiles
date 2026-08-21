---
name: maintain-verification-skill
description: "Reconcile a project's verification skill and feature map with source and live behavior. Use when auditing, repairing, or refreshing an existing project-local verification skill."
disable-model-invocation: true
---

# Maintain a verification skill

Keep an existing project-local verification skill honest as the product
changes. Cover every mapped feature from source and exercise every feature
live. The unit of rigor is the feature, not every sentence in its file.

Return one outcome:

- **clean:** every feature received source and live coverage; no correction is
  warranted.
- **changed:** one coherent set of proven corrections is ready.
- **blocked:** coverage could not finish or a proven correction could not be
  made safely; name the exact blocker.

## Scope

Edit only the verification skill's directory: its instructions, feature map,
and owned harness helpers. When the product is wrong, report the regression;
do not disguise it as documentation drift or edit product code in this pass.

## Reconcile

1. Locate the project-local verification skill with launch, doctor, drive, and
   feature-map instructions. If several match, resolve the intended target. If
   none exists, stop and recommend `create-verification-skill`.
2. Compare the feature index with its sibling files. Correct missing, duplicate,
   extra, and dead entries.
3. Explain each mapped feature from current source, cite its entry points, flag
   likely drift, and produce one concise live recipe. For a large map, these
   read-only source passes may run independently and concurrently; the
   maintainer owns all edits and live driving.
4. Reconcile the findings and sweep recent user-facing changes for features
   missing from the map. Require a concrete source path before calling one
   missing.

Source agreement is not live proof.

## Drive every feature

Follow the verification skill's own launch model. Use one owned long-lived
instance for a UI or service, or fresh isolated processes for a short-lived
CLI. Exercise every feature at least once.

Maintain these invariants throughout:

- Doctor before the first drive, after surprising behavior, and for each fresh
  session when sessions are the isolation unit.
- Preserve evidence already captured across every cleanup and confirm it at
  the named location.
- Remove residue from failed attempts and stop everything this run started
  after the final proof.

When doctor itself has drifted, repair it within scope, restart only what the
repair invalidated, and retry once. Mark a path `verified-unreachable` only
with its attempted route and concrete missing prerequisite. Re-drive every
harness correction before accepting it.

## Triage and finish

Wrong user-facing description is map drift. Working behavior the harness
cannot drive is a harness gap. Broken product behavior is a product regression.

For `changed`, reread and verify every changed file, then commit or publish only
as authorized by the surrounding task and repository rules. For `clean` or
`blocked`, make no empty bookkeeping change. Keep concise run notes in scratch
space rather than committing them.
