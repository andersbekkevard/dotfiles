---
name: reclaim-storage
description: Audit machine-wide disk or RAM-backed storage and propose exact reclaim candidates without deleting them. Use when Anders asks what consumes space, how much can be reclaimed, whether caches, build targets, Trash, worktrees, temporary files, or Codex sessions can be pruned, or when storage pressure appears during another task.
---

# Reclaim Storage

Run a read-only census of configured mutable roots, classify every surfaced
path, and return the reclaim menu. Capacity covers mounted filesystems;
immutable operating-system package trees are context, not reclaim candidates,
unless the machine configuration explicitly adds them. The skill earns
deletion authority later; this version has no apply path.

## Audit

1. Resolve the machine configuration from `machine.local.toml` beside this
   file, or from `RECLAIM_STORAGE_CONFIG`. When it is missing, inspect the
   machine and create only the ignored local file from `machine.example.toml`.

2. Run the deterministic audit from this skill directory:

```bash
python3 scripts/reclaim_storage.py audit --config machine.local.toml --json
```

The command must finish with filesystem capacity, classified candidates,
unknown large paths, and a non-overlapping reclaim total. It performs no
deletion and makes no network or model calls.

3. Triage every `unknown` path above the configured reporting threshold in
descending size. Use shallow, credential-safe checks of contents, ownership,
mount boundary, process references, Git state, and recreation source. Inspect
deeply only while evidence can turn it into a concrete candidate; otherwise
leave it explicitly classified as an unknown decision. Report the full unknown
list even when deep investigation would become a separate forensic task. Local
evidence outranks a guessed category.

4. Report one size-sorted reclaim menu. For each candidate include its exact
path, category, allocated bytes, reclaimable bytes, recreation cost, activity
or uncertainty, and the action that would be required. State that nothing was
removed.

5. When a useful recurring candidate is outside scope, propose one evolution:
put portable discovery in the tracked scripts and machine-only paths in
`machine.local.toml`. Do not silently expand either surface during an audit.

## Codex sessions

Treat Codex history as an archive decision, not a cache. The bundled
`scripts/codex_sessions.py` streams JSONL directly; agents must not inspect or
summarize sessions with model tokens.

Only sessions whose latest record or file modification is older than seven
days are eligible. The conservative archive retains raw session metadata, user
messages, assistant messages, agent messages, message event fallbacks,
timestamps, and unparseable records. It excludes tool traffic, patches, token
counters, world state, context replay, and model reasoning.

`audit` estimates the exact raw-byte delta. `archive` may be run only after
Anders approves its cutoff and destination; it writes gzip transcripts plus a
hash-and-count manifest, verifies every source stayed unchanged, and leaves
all source sessions in place. Removing source sessions remains a separate,
explicitly approved future step because the transcript archive is not a
Codex-resumable history.

After that approval, use the exact paths and cutoff from the audit result:

```bash
python3 scripts/codex_sessions.py archive \
  --sessions-root <sessions_root> \
  --retention-days 7 \
  --cutoff-at <cutoff_at> \
  --output <proposed_archive_path> \
  --json
```

Do not inspect session JSONL with an agent before or after this command. Verify
the returned manifest and source hashes programmatically.

## Guardrails

- Keep the audit read-only and path-exact.
- Inspect activity using PID, process name, cwd, and file-descriptor targets.
  Never print full command lines, process environments, or secret-bearing
  arguments while investigating storage.
- Treat symlinks, mount points, cross-device trees, live paths, unique work,
  Git state, credentials, and unknown data as blocked or decision items.
- Count allocated bytes as an estimate; reflinks, sparse files, open deleted
  files, and filesystem metadata can make reclaimed allocation differ.
- Preserve machine facts only in the ignored local configuration. Keep generic
  behavior and tests tracked in this skill.
