---
name: pro-brief
description: "Compile a one-shot, clipboard-ready GPT-5.5 Pro briefing bundling the local repo, vault, docs, or code context ChatGPT cannot access. Use when Anders wants to ask GPT-5.5 Pro / Pro / ChatGPT about a programming, architecture, research, or knowledge-base topic needing local context: select minimal relevant files, bundle with exact tiktoken counts, copy to clipboard, report file/char/token stats, and support pruning an existing briefing to a token or percentage budget."
---

# Pro Brief

Prepare a compact zero-context briefing that Anders can paste into GPT-5.5 Pro.
Default to one-shot execution: select context, compile the full prompt, copy it
to the clipboard, then report metrics and included files. Do not stop to ask for
approval unless the missing choice would materially change the bundle or risk
including sensitive material.

Use this for any topic whose truth lives in local files: code, docs, wiki notes,
ADRs, data-plane configuration, financial methodology, product context, meeting
notes, or other semantic material. Do not assume the question is a programming
problem.

## Workflow

1. Identify the topic and desired consultation shape from the user's message.
   If the user only gives a topic, infer the likely question area from live repo
   context, but do not invent Anders' final question.
2. Gather enough context to choose a small file set:
   - Read local agent/repo instructions first.
   - Search semantically using `rg`, Maps, docs, symbols, headings, and filenames.
   - Prefer canonical/live docs and local source-of-truth files over stale notes.
   - Include only the generic project context the topic needs; do not dump a
     repo's constitution/boot docs unless they directly change the answer.
3. Compile the prompt in a temp file:
   - write a short project brief;
   - write the current scenario and constraints;
   - write instructions for GPT-5.5 Pro on how to use the context;
   - append the approved-by-judgment `<file_context>` block from the bundler.
4. Copy the full prompt to the clipboard with `pbcopy`.
5. Reply in chat with attached-context metrics first, then the included file
   list. Do not paste the full prompt unless Anders explicitly asks.

## File Selection

Keep the bundle as small as possible while still giving GPT-5.5 Pro the mental
model it needs. Fewer files plus a sharper briefing beats a whole-repo dump.

Prefer:
- root/local `AGENTS.md` instructions that affect the task;
- canonical product/docs/config/spec files for the topic;
- implementation files that contain the actual behavior;
- tests or fixtures only when they clarify contracts or edge cases;
- wiki Maps/Notes/ADRs when the question is conceptual or strategic.

Avoid by default:
- secrets, `.env*`, credentials, cookies, raw tokens, private keys;
- generated output, large binary data, caches, vendored dependencies;
- long adjacent files that can be summarized accurately instead;
- duplicate files that repeat the same fact.

For finance and analytics topics, preserve assumptions explicitly in the
scenario: metric basis, frequency, overlap policy, annualization, gross/net,
risk-free rate, and whether coverage gaps are known.

## Final Prompt Shape

The final prompt must be standalone. GPT-5.5 Pro starts with no project memory,
no filesystem, and no access to local paths.

If Anders already stated the consultation question, review request, or critique
target, make that question the main prompt. Do not wrap it in a generic "Anders
will paste his actual question above" briefing. If Anders only gave a topic,
write a compact briefing that makes the likely consultation shape clear without
inventing a final question.

For conceptual, architecture, or PRD reviews, be sparse with file examples and
spend the hand-written scenario on the semantic goal: what we are trying to
achieve, why it matters, what constraints shape the answer, and what kind of
tradeoffs or critique would be useful.

Use this shape when Anders already supplied the question:

```text
<anders_question>
...the actual question or review request, rewritten only enough to be standalone...
</anders_question>

<context_metrics files="..." chars="..." tokens="..." tokenizer="tiktoken:o200k_base" />

<project_brief>
...
</project_brief>

<current_scenario>
...
</current_scenario>

<how_to_use_this_context>
...
</how_to_use_this_context>

<file_context files="..." chars="..." tokens="..." tokenizer="tiktoken:o200k_base">
  <file path="..." bytes="..." sha256="..." content_encoding="xml-escaped">
    ...
  </file>
</file_context>
```

Use the older "Anders will paste his actual question above this briefing" shape
only when Anders has not yet supplied the question.

The `<context_metrics>` tag mirrors the attached `<file_context>` metrics. It is
not a count of the hand-written scenario prose unless the full prompt is counted
separately.

## Prompting Rules

- Write outcome-first, concise instructions suited for GPT-5.5 Pro.
- Give the receiving model enough context to reason independently, but avoid
  process-heavy instruction stacks.
- Ask it to distinguish source-backed facts from inference.
- Ask it to name missing evidence or contradictions rather than smoothing them
  over.
- For planning or review asks, request recommendations, tradeoffs, validation
  checks, and failure modes.
- For semantic or strategy asks, request a clear view of the concept graph,
  current assumptions, and what would change the conclusion.
- Do not ask it to browse, access the local filesystem, or authenticate.

## Bundling Script

Use `scripts/bundle_files.py` to wrap selected files in XML-safe file tags. It
accepts explicit files, directories, globs, and `!` excludes. It uses `tiktoken`
through uv inline script dependencies and emits exact tiktoken token counts for
the rendered `<file_context>` block.

Use `--files-report` whenever generating a final bundle so the chat reply can
include the exact included file list and per-file token weights:

```sh
uv run "<this skill dir>/scripts/bundle_files.py" \
  --files-report \
  --file "docs/README.md" \
  --file "notes/<topic>.md" \
  --output /tmp/pro-brief-file-context.xml
```

Use `--max-total-tokens` during pruning or when Anders gives a hard budget:

```sh
uv run "<this skill dir>/scripts/bundle_files.py" \
  --files-report \
  --max-total-tokens 50000 \
  --file "docs/README.md" \
  --file "notes/<topic>.md" \
  --output /tmp/pro-brief-file-context.xml
```

In normal use, have the script generate the `<file_context>` block, compose the
project brief and scenario around it in `/tmp/pro-brief-prompt.txt`, then copy
the full prompt:

```sh
pbcopy < /tmp/pro-brief-prompt.txt
```

If clipboard copy is unavailable, print the prompt path or prompt text and say
that clipboard copy failed.

## Chat Reply Format

After copying, reply with the stats at the top and use spaces as thousands
separators:

```text
Files: 12
Characters: 184 203
Tokens: 42 917

Copied to clipboard.

Included files:
- ...
- ...
```

If the user asks for the full prompt in chat, paste it after the metrics.

## Pruning Follow-Ups

If Anders follows up with `prune`, `reduce`, `drop`, `make smaller`, a token
budget, or a percentage, reuse the last Pro Brief bundle as the starting point.

Interpret budgets this way:
- `to 50 000 tokens` means final rendered context must be at or under 50 000
  tiktoken tokens.
- `to 60%` means target 60 percent of the previous token count.
- `by 40%` means remove about 40 percent of the previous token count.

If Anders names files, sections, concepts, or priorities, follow that direction
first. Otherwise prune by judgment:
1. preserve root instructions and the highest-authority source-of-truth files;
2. preserve files that directly answer the consultation topic;
3. drop optional, duplicative, stale, generated, or merely illustrative files;
4. prefer removing whole files over bloating the prompt with long summaries;
5. rerun the bundler with `--files-report` and, for hard budgets,
   `--max-total-tokens` until the target is met.

After pruning, copy the revised prompt and reply again with metrics first plus
the new included file list. Mention notable dropped files only when useful.

## Quality Bar

- No invented facts. Mark anything inferred as inference.
- No secrets. If a needed fact lives in a sensitive file, summarize or redact it.
- Minimal sufficient context. Explicitly justify any large file.
- Use repo-relative or meaningful local-relative paths in file tags; avoid
  absolute home paths unless the file is outside any clear project root and the
  path itself is necessary.
- Token counts must come from `tiktoken`, not character heuristics.
