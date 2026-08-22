---
name: model-wave
description: Run an explicit set of ready prompts concurrently through the registered Claude, Codex, and Grok dispatchers. Use only when a workflow asks for a multi-model wave.
---

# Model wave

Execute independent model lanes concurrently. This skill owns fan-out,
collection, and visible dropouts. Each lane delegates to one provider dispatch
skill, which owns authentication, access boundaries, and atomic result capture.

Model wave accepts ready prompt files. It does not construct prompts, choose
review lenses, define rubrics, judge candidates, synthesize results, or decide
that a workflow needs several models.

## Run a wave

Write an absolute-path manifest:

```json
{
  "runs": [
    {
      "id": "claude",
      "provider": "claude",
      "prompt": "/absolute/prompts/shared.md",
      "output": "/absolute/results/claude.md",
      "access": "closed",
      "model": "claude-fable-5",
      "effort": "high"
    }
  ]
}
```

Use a distinct `id` and output for each lane. The registered providers are
`claude`, `codex`, and `grok`. `access` is `closed` or `agentic`; every agentic
lane also requires an absolute `root`. Omit model or effort to use that
provider dispatcher's default.

Run:

```sh
SKILL_DIR="<directory containing SKILL.md>"

python3 "$SKILL_DIR/scripts/run.py" /absolute/wave.json \
  --result /absolute/wave-result.json
```

The result records each lane's completion state, output, log, and return code.
Partial success exits successfully so the owning workflow can use completed
lanes while naming dropouts. If every lane fails, the runner exits nonzero.

The caller owns what happens next. Do not synthesize or interpret results in
this skill.
