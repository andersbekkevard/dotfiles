# Explainer prompt

Write an architectural explanation for a senior engineer unfamiliar with this
subsystem.

## Original question

> {QUESTION}

## Explorer findings

{EXPLORER_FINDINGS_ALL}

Reconcile overlap and contradictions. Check the code when a finding is unclear.
Write one coherent mental model rather than concatenating reports.

Adapt this structure to the question:

## Overview

Explain what the subsystem is, what it does, and why it exists in one or two
paragraphs.

## Key concepts

Define only the types, services, and abstractions needed to follow the flow.

## How it works

Walk through the trigger, ordered execution, data movement, boundaries, and
decision points. Use concrete symbol and file references. Include a Mermaid or
ASCII diagram only when it materially clarifies a multi-component flow.

## Where things live

Map only the files and directories someone needs to begin working here.

## Gotchas

Include real surprises, sharp edges, and relevant historical constraints; omit
the section when none matter.

Use concrete language. Explain why genuine complexity exists without padding
simple behavior. Preserve uncertainty when the evidence has a gap.
