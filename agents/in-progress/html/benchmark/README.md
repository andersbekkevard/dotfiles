# HTML skill benchmark

This benchmark exists to choose and improve Anders's eventual `/html` skill by
running competing candidates on the kinds of visual requests Anders actually
makes. HTML quality is difficult to infer from a skill document alone: two
prompts can sound equally sensible while producing artifacts with very
different information density, visual judgment, usefulness, and restraint.
The useful test is therefore repeated side-by-side output on real work.

The corpus is a tournament seed, not a universal scoring system. Its cases were
reconstructed from Anders's sessions. Positive cases exercise reports,
explainers, architecture, research, and interactive exploration. Routing
controls test whether a candidate can leave code diffs, screenshots, video,
workbooks, and slides with their better-suited tools. Anders's comparative
judgment remains the evaluator.

## What a case contains

Each directory under `cases/` keeps the model-visible prompt separate from
hidden evaluation context:

- `context.md` reconstructs the established task state. It gives the agent the
  domain facts and unresolved question it would have known in the original
  conversation, without prescribing a visual form.
- `prompt.md` preserves Anders's triggering message verbatim.
- `metadata.json` records provenance, source session, case group, and expected
  ownership boundary. The renderer never shows this file to the model.

`manifest.json` is the ordered case index. Candidate artifacts and judging
notes do not belong in this directory; keeping them elsewhere prevents one run
from learning from another candidate's output.

## Validate the corpus

Run the structural check after editing any case:

```bash
python3 agents/in-progress/html/benchmark/validate.py
```

When the two external source corpora named in `metadata.json` are available on
the machine, also prove that every `prompt.md` still matches its mined source:

```bash
python3 agents/in-progress/html/benchmark/validate.py --sources
```

The source comparison protects the user prompt only. Context files are
deliberately reconstructed from the broader session and repository evidence.

## Render one tournament prompt

Pass the candidate's actual `SKILL.md`; the renderer resolves it to an absolute
path and appends `call <path>` after the reconstructed context and verbatim
prompt.

```bash
python3 agents/in-progress/html/benchmark/render.py \
  --case 16-analytics-mcp-data-flow \
  --skill agents/in-progress/html/html-1/SKILL.md
```

To keep a copy for a fresh Codex task:

```bash
mkdir -p /tmp/html-tournament/html-1
python3 agents/in-progress/html/benchmark/render.py \
  --case 16-analytics-mcp-data-flow \
  --skill agents/in-progress/html/html-1/SKILL.md \
  --output-dir /tmp/html-tournament/html-1

codex exec -C /Users/andersbekkevard/dotfiles - \
  < /tmp/html-tournament/html-1/16-analytics-mcp-data-flow.txt
```

Use the source working directory from the case's `metadata.json` instead of the
dotfiles path when the original repository is available and the request needs
live repo inspection.

## Materialize a full candidate run

`--all` creates one prompt file per case. It does not invoke an agent:

```bash
python3 agents/in-progress/html/benchmark/render.py \
  --all \
  --skill agents/in-progress/html/html-1/SKILL.md \
  --output-dir /tmp/html-tournament/html-1
```

Run every candidate-case pair in a fresh task with the same model, harness,
permissions, and relevant working directory. Give each pair a separate output
location. Fresh tasks matter because an agent that has seen another artifact
is no longer testing only its assigned skill.

For an efficient tournament, start with a varied subset: one report, one
architecture or flow explanation, one interactive case, and two routing
controls. Advance the strongest candidates to the full corpus rather than
paying for every weak candidate across all 26 cases.

## Compare the outputs

Judge pairs without reading the candidate name first when practical. Record
which artifact better:

- identifies and communicates the important substance rather than decorating
  a thin summary;
- chooses a form that fits the subject and makes relationships easy to read;
- maintains hierarchy, legibility, semantic use of color, and useful detail;
- preserves factual fidelity and makes source references clickable where
  possible;
- delivers a usable browser artifact on Anders's Mac; and
- routes away when HTML is not the right owner.

Keep the concrete correction, not only the winner. Repeated corrections are the
evidence for narrowing the eventual `/html` skill; a one-off preference should
remain a tournament observation until another case supports it.
