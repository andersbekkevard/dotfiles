# Agent tooling TODO

## Stream live sessions in Session Viewer

Add a generic live mode:

```bash
session-viewer <transcript> --follow --open
```

The command runs beside the transcript, serves the existing viewer on
loopback, forwards it through Fleet to Anders' Mac, and streams newly committed
events through server-sent events. When the session finishes, the same page
remains exportable as today's self-contained HTML artifact.

Put filesystem complexity behind a `SessionFeed` interface. The implementation
tails by byte offset, buffers an incomplete final JSONL line, and detects file
truncation, replacement, or rotation by identity and size. Reconnects are
idempotent: normalized event identities prevent duplicates, while a reset
rebuilds from the current file when append-only continuity is lost. Poll file
state as the reliable mechanism; filesystem notifications may reduce latency
but are not authority.

Reuse the existing Codex, Claude, Cursor, Grok, and Pi/OpenClaw importers and
the existing viewer design. The browser appends normalized events without
losing search, filters, expansion state, or scroll position. Auto-follow only
while the reader is already near the bottom, and show `Live`, `Complete`, or
`Disconnected` status.

Keep host access outside Session Viewer. The viewer reads a local path and
binds only to loopback; Fleet owns forwarding and opening it on the Mac.
Europa therefore works with the existing Fleet route. Other hosts, including
the Azure ingest VM, need Fleet connectivity before they can use the same
mode. Root-owned sandbox transcripts require a narrow read-only host adapter,
not broader viewer privileges.

Completion requires live demonstrations for supported transcript families and
tests for partial writes, reconnect duplication, truncation, replacement,
rotation, large tool results, reader scroll preservation, terminal completion,
and final static export. The live page and exported artifact must render the
same normalized session.
