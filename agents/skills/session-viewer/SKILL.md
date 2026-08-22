---
name: session-viewer
description: "Render Codex, Claude Code, Cursor Agent, Grok, OpenClaw, or Pi session transcripts as a searchable, shareable single-file HTML viewer."
---

# Session Viewer

Use when asked to view, export, inspect, or share a Codex, Claude Code, Cursor
Agent, Grok, OpenClaw, or Pi session transcript in a browser.

## Commands

Find the likely JSONL session, then render it with `session-viewer`.

Session Viewer owns transcript parsing and the viewer's existing visual design.
For delivery, follow [`html`](../html/SKILL.md#delivery). `--open` preserves the
rendered file, delivers it to Anders's Mac with Fleet, and opens it there.

From a repo that has this skill:

```bash
node skills/session-viewer/scripts/session-viewer.ts <session> --open
```

Useful modes:

```bash
node skills/session-viewer/scripts/session-viewer.ts <session> --out session.html
node skills/session-viewer/scripts/session-viewer.ts <session> --raw --out session.html
node skills/session-viewer/scripts/session-viewer.ts --blank --out viewer.html --open
```

In a downstream repo that syncs shared skills under `.agents/skills`, replace
`skills/session-viewer` with `.agents/skills/session-viewer`.

Defaults:

- detects `codex`, `claude`, `cursor`, `grok`, or `pi-openclaw`
- accepts a Cursor transcript directory, native JSONL, or `stream-json` output
- accepts a Grok session directory, its `summary.json`, or `chat_history.jsonl`
- embeds normalized session data into one HTML file
- writes to a timestamped file in the OS temp directory unless `--out` is set
- keeps tool input/output text in the DOM so browser search can find it
- `--raw` embeds the original JSONL and lets the browser parse it
- `--blank` creates a reusable file-picker viewer

## Where Sessions Live

Codex:

```bash
find "${CODEX_HOME:-$HOME/.codex}/sessions" -name 'rollout-*.jsonl' -type f | sort
ls -t "${CODEX_HOME:-$HOME/.codex}"/sessions/*/*/*/rollout-*.jsonl | head
```

OpenClaw/Pi:

```bash
AGENT_ID="<agentId>"
SESSION_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}/agents/$AGENT_ID/sessions"
ls -t "$SESSION_DIR"/*.jsonl | head
find "${OPENCLAW_STATE_DIR:-$HOME/.openclaw}/agents" -path '*/sessions/*.jsonl' -type f | sort
```

Use `sessions.json` in the same directory to map session keys to session ids.

Claude Code:

```bash
find "$HOME/.claude/projects" -name '*.jsonl' -type f | sort
ls -t "$HOME/.claude/projects"/**/*.jsonl | head
```

Some Claude installs also keep exported JSON/JSONL under project-specific cache folders; prefer the newest JSONL with the target repo path in its parent folder.

Cursor Agent:

```bash
find "$HOME/.cursor/projects" -path '*/agent-transcripts/*/*.jsonl' -type f | sort
ls -t "$HOME/.cursor/projects"/*/agent-transcripts/*/*.jsonl | head
```

You can also render JSONL captured from `cursor-agent -p --output-format
stream-json`. Native Cursor transcript directories contain one same-named
JSONL file, so either the directory or that file is accepted.

Grok:

```bash
find "${GROK_HOME:-$HOME/.grok}/sessions" -name summary.json -type f | sort
```

Native Grok sessions live under `${GROK_HOME:-$HOME/.grok}/sessions/`.
For `grok-dispatch`, render the `Transcript:` path it prints. The dispatch
skill's [transcript reference](../grok-dispatch/references/transcripts.md) owns
its storage layout.

## Development

Scripts are native Node TypeScript. Keep them erasable:

- ok: types, interfaces, unions, `satisfies`
- avoid: enums, namespaces, decorators, parameter properties
- no tsconfig path aliases; use relative imports

Importer ownership:

- `scripts/importers/codex.ts`: Codex rollout JSONL
- `scripts/importers/claude.ts`: Claude Code JSONL
- `scripts/importers/cursor.ts`: native and streamed Cursor Agent JSONL
- `scripts/importers/grok.ts`: native and dispatched Grok sessions
- `scripts/importers/pi-openclaw.ts`: Pi/OpenClaw session JSONL

Validate:

```bash
pnpm exec tsgo -p skills/session-viewer/tsconfig.json
node --test skills/session-viewer/scripts/session-viewer.test.ts
scripts/validate-skills
```
