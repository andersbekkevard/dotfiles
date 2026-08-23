---
name: compress-agent-transcript
description: Mechanically compress one native agent transcript without summarizing it.
disable-model-invocation: true
---

# Compress an agent transcript

This is mechanical compression, not sanitization. Use it only after any needed
secret or privacy redaction.

Run the compressor on one Codex, Claude Code, or Cursor Agent JSONL file, or
one Grok Agent session directory:

```bash
python3 /home/anders/dotfiles/agents/skills/compress-agent-transcript/scripts/compress_agent_transcript.py \
  compress <session-file-or-directory> --output <archive.tar.gz>
```

The archive retains the provider's native files, record order, instructions,
messages, reasoning, tool calls, arguments, identifiers, and statuses. It
replaces tool-result bodies with byte-count and SHA-256 markers, removes known
telemetry, and shortens only compaction history already present earlier in the
same Codex transcript. Unknown and malformed records pass through unchanged.

Verify the written archive before deleting or moving any source:

```bash
python3 /home/anders/dotfiles/agents/skills/compress-agent-transcript/scripts/compress_agent_transcript.py \
  verify <archive.tar.gz>
```

Completion means the command detected the intended provider, verification
passed, the manifest accounts for every source file, and the source remains
unchanged. This skill never deletes the source.
