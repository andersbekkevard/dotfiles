# HTML benchmark cases

This corpus contains 26 reconstructed cases for comparing candidate HTML and diagram skills. Each case keeps three concerns separate:

- `context.md` recreates the established task state without adding visual direction.
- `prompt.md` is Anders's original trigger prompt, preserved verbatim.
- `metadata.json` holds provenance and the expected ownership boundary. The renderer never includes it in the model prompt.

## Render a case

```bash
python3 agents/in-progress/benchmark/render.py \
  --case 16-analytics-mcp-data-flow \
  --skill /absolute/path/to/SKILL.md
```

The renderer prints:

```text
<context.md>

<prompt.md>

call /absolute/path/to/SKILL.md
```

To materialize every prompt for a tournament:

```bash
python3 agents/in-progress/benchmark/render.py \
  --all \
  --skill /absolute/path/to/SKILL.md \
  --output-dir /tmp/html-benchmark-prompts
```

Generated prompts belong outside the repository. Candidate outputs should be stored separately so one run cannot inspect another candidate's artifact.

## Case groups

`positive` cases ask for an HTML or closely related visual artifact. `positive-borderline` and `routing-borderline` exercise a contested boundary. `routing-control` cases should normally remain with the owning medium or tool even when an HTML skill path is appended.

The expected owner is evaluation metadata, not prompt context. It must not be shown to the model under test.
