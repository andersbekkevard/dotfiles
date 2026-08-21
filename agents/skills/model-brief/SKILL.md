---
name: model-brief
description: Assemble a self-contained prompt for guidance from a stronger model.
disable-model-invocation: true
---

# Model brief

Compile the question and its minimal sufficient evidence into a ready prompt
file. Stop at the prompt: this skill neither chooses nor invokes a model, and
it does not decide what tool access the eventual run receives.

## Assemble

1. Recover the actual question, desired outcome, fixed constraints, and live
   uncertainty. Do not invent a final question when Anders supplied only a
   topic.
2. Select the smallest evidence set that lets a zero-context model reason
   independently. Prefer current authority and exact source text where wording
   or behavior matters; use a provenance-rich digest for broad adjacent
   material.
3. Write a concise standalone prompt. Separate observed facts, inference, and
   open judgment. Ask for the decision, tradeoffs, missing evidence, and what
   would change the conclusion when those are material.
4. Write the result to `prompt.md` in a fresh work directory. Report the
   absolute path, token count, and included evidence. Copy it to the clipboard
   only when Anders asks for a manual paste workflow.

The prompt is complete when the receiving model can explain the question,
constraints, evidence, and requested deliverable without this conversation or
filesystem access.

## Choose the assembly procedure

- For a question whose evidence is mainly whole local files, use
  [`scripts/bundle_files.py`](scripts/bundle_files.py). It owns safe expansion,
  XML escaping, hashes, exact `tiktoken` counts, pruning limits, and file
  reports. Compose the question and scenario around its `<file_context>` block.
- For guidance, an independent proposal, or a challenge to a formed direction,
  read [decision counsel](references/decision-counsel.md), then use
  [`scripts/compose_prompt.py`](scripts/compose_prompt.py). Treat the script as
  opaque unless changing or auditing it.
- For a small prompt needing neither procedure, write `prompt.md` directly.

Keep secrets out of the prompt. When a material fact lives in sensitive input,
write a sanitized, clearly labeled redaction or a provenance-rich digest.
