---
name: model-brief
description: Assemble a self-contained prompt for stronger-model guidance while preserving user intent and verbatim user wording.
disable-model-invocation: true
---

# Model brief

Compile the user's intent, exact wording, question, and supporting evidence into
a ready prompt file. Stop at the prompt.

This skill neither chooses nor invokes a model. It does not decide what tool
access the eventual run receives.

## Preserve the user

Every user-driven brief contains both:

- `user-intent.md`, which reconstructs what Anders means from the whole relevant
  conversation; and
- `user-anchors.md`, which lets the receiving model check that reconstruction
  against Anders's verbatim wording.

Always include the latest operative user request as an anchor. Add the passages
that carry the purpose, desired outcome, accepted decisions, corrections,
rejections, uncertainty, or strong preferences shaping the question. Use enough
anchors for a zero-context model to interpret Anders independently. Do not use a
fixed count or dump the transcript.

This pair is especially important for a Fable consultation. The intent file
states the assembling agent's reading, while the anchors leave Fable room to
read between the lines and disagree with it.

For a generated task with no user conversation, use the exact task
specification in place of these files. For sensitive wording, preserve a
clearly labeled redaction rather than silently paraphrasing it.

## Choose judgment mode

- `guidance`: answer a bounded question.
- `propose`: direction remains open. Give the receiving model the user's intent,
  evidence, constraints, and agreed premises while withholding the requesting
  agent's preferred direction.
- `challenge`: a direction exists. Add the proposed direction, causal case,
  strongest live alternative, contrary evidence, verification signals, and
  falsifiers.

Honor the mode Anders requests. Otherwise ask whether the current agent would
proceed with a specific direction if the consultation were unavailable. A yes
means `challenge`; a no means `propose`. Use `guidance` only for a bounded
question that does not ask the model to choose or test a direction.

Read [decision counsel](references/decision-counsel.md) for the intent
reconstruction, anchor selection, evidence types, and mode-specific brief. Use
[`scripts/compose_prompt.py`](scripts/compose_prompt.py) to compose it.

## Assemble

Select the smallest evidence set that lets the receiving model reason
independently without flattening the user's intent. Prefer current authority and
exact source text where wording or behavior matters. Use a provenance-rich
digest for broad adjacent material. Keep observed facts, inference, and open
judgment distinct.

For literal whole-file work rather than judgment, use
[`scripts/bundle_files.py`](scripts/bundle_files.py). It owns safe expansion,
XML escaping, hashes, exact `tiktoken` counts, pruning limits, and file reports.
Place the user intent and anchors around its `<file_context>` block.

Write `prompt.md` in a fresh work directory. Report its absolute path, token
count, and included evidence. Copy it to the clipboard only when Anders asks for
a manual paste workflow.

The prompt is complete when the receiving model can explain the question,
desired outcome, constraints, accepted and rejected directions, live
uncertainty, evidence, and requested deliverable without this conversation or
filesystem access. It must also be able to distinguish Anders's words from the
assembling agent's interpretation.

Keep secrets out of the prompt. When a material fact lives in sensitive input,
write a sanitized, clearly labeled redaction or a provenance-rich digest.
