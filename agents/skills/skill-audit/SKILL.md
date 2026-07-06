---
name: skill-audit
description: Audit global agent skills against their declared upstream sources. Use when Anders asks to run a skill audit, check skill-source drift, review semantic pulls, or decide whether tracked skill updates should be ported.
disable-model-invocation: true
---

# Skill Audit

Run a read-only audit of global skills against `agents/skill-sources.toml`.
The point is semantic triage: decide whether upstream changed in a way worth
porting while preserving intentional local behavior.

Durable local divergence decisions live in
`references/skill-divergences.md`. Always read that file before classifying
drift or reporting recommendations, but only treat entries there as durable
when Anders explicitly recorded them.

## Workflow

1. Work from the dotfiles repo root.

2. Validate the source map:

```bash
agents/skillpull validate
```

If validation fails, report the manifest problem first and stop before auditing
remote drift.

3. Read the accepted divergence ledger:

```bash
sed -n '1,240p' agents/skills/skill-audit/references/skill-divergences.md
```

Treat it as the durable source for accepted local behavior only where it has an
explicit entry. The `preserve` entries in `agents/skill-sources.toml` are
compact routing hints; do not expand them into ledger entries unless Anders
explicitly says to durably record that divergence.

4. Run the tracked audit:

```bash
agents/skillpull check --all --json
```

Nonzero exit is expected when tracked skills drift. Treat JSON output as the
input artifact, not as the final answer.

5. Inspect only what matters:

- For `exact`, report nothing unless the user asked for a full inventory.
- For `drift`, inspect the diff with `agents/skillpull check <skill> --diff`
  and classify the change semantically against both the diff and the divergence
  ledger.
- For `error`, report the broken source path, clone failure, or local-path
  problem as an audit blocker.
- For `watch`, do not invent byte-level drift. Check the upstream project only
  when the user explicitly asks for watch-source review or when a known product
  change is likely to affect the local skill.
- For `local`, do not search for upstreams.

6. Preserve local intent. Treat every explicit decision in
`references/skill-divergences.md` as a hard constraint. Treat
`preserve = [...]` entries in `agents/skill-sources.toml` as audit hints, not
durable decisions. Do not recommend replacing a local customization just because
upstream lacks it, but do not suppress drift as "documented local divergence"
unless the Markdown ledger has an explicit entry for it.

7. Report concise findings:

```text
Skill audit: <clean / material changes / blocked>

Material changes:
- <skill>: <upstream change>; <why it matters>; recommendation: <port / ignore / inspect manually>

Intent conflicts:
- <skill>: <conflict with preserve note>; recommendation: <keep local / adapt carefully>

Noise ignored:
- <skill>: <frontmatter-only / generated-file / documented local divergence / cosmetic drift>
```

If there are no material changes, say that directly and include the commands
run. Do not paste the full JSON unless asked.

Do not make Anders re-decide documented divergences. If a divergence is not in
the Markdown ledger, it is not documented, even if it appears in a prior audit
or a TOML preserve hint.

## Rules

- Read-only by default. Do not edit skills during an audit unless Anders
  explicitly asks to port a change.
- Do not run `codex exec` or delegate the audit; the current agent can run the
  commands and inspect diffs directly.
- Do not treat existing baseline drift as new upstream movement unless a lock or
  prior report proves it changed since the last audit.
- Prefer "port this specific upstream idea" over "sync the skill".
- Keep local skills local.
