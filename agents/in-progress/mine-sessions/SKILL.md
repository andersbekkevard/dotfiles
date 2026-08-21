---
name: mine-sessions
description: Answer a question across past Codex and Claude sessions through scoped discovery, token-budget sharding, parallel reading, and global reduction. Use to reconstruct recent work or investigate a pattern across sessions.
---

# Mine sessions

Treat the user's question as a query over a session corpus. Preserve the
question exactly. The skill owns corpus construction and orchestration, not the
kind of conclusion requested.

## Scope

Resolve the repository or working-directory scope, time range, session sources,
and output destination from the request. Make cheap, reversible assumptions
when a missing detail does not change the answer. Keep any material assumption
visible.

Discover every Codex and Claude session matching the scope from session
metadata, especially working directory and timestamps. Record included,
excluded, unreadable, and duplicate sessions in a manifest. Treat reflections
and summaries as secondary commentary; the original dialogue is primary.

## Fan out

Normalize the corpus without paraphrasing Anders. Preserve every user message
verbatim, session identity, date, runtime, and working directory. Remove
synthetic harness envelopes and cap or omit bulky assistant output only when it
cannot bear on the question.

Remove exact duplicated or inherited material before sharding. Preserve
independent repetitions of Anders' guidance because recurrence may answer the
question.

Shard by token weight so each shard can be read completely. Start one fresh
worker per shard, without inherited conversation. Give every worker the exact
question, its complete file list, and the same output contract. Fan out as wide
as the available runtime allows. Every discovered session must be assigned or
accounted for as unreadable.

Each worker must read every assigned file in full and return only relevant
claims, exact supporting excerpts, source session IDs, contradictions, and
uncertainty.

## Reduce

Give one fresh reducer the question, all shard results, and the manifest. Have
it combine semantically duplicate claims, preserve genuine disagreement and
changes over time, distinguish worker inference from Anders' words, and report
coverage gaps. A repeated quote inherited through forks counts as one piece of
evidence.

Return the reduced answer to the requesting conversation. When Anders requests
a durable result, write only `report.md` and `manifest.json` to the agreed
destination. Label the report as derived evidence, not project authority. Keep
raw extracts and shard outputs temporary and regenerable.

Done when every session in scope is accounted for and every material conclusion
can be traced to its source sessions.
