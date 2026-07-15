---
name: fix-merge-conflicts
description: Resolve an in-progress git merge/rebase conflict, including .beads/issues.jsonl.
disable-model-invocation: true
---

1. **See the current state** of the merge/rebase. Check git history and the conflicting files. Identify the commits behind each side rather than relying on "ours" and "theirs": during a rebase, those labels are reversed from their usual intuitive meaning.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets, and consult the repo's owning docs. Determine whether the local change, remote change, or a combination best matches the merge/rebase goal.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. When evidence is otherwise tied, preserve the merge/rebase target.

   For `.beads/issues.jsonl`, merge structurally by issue `id`, not as lines or by choosing one whole side:

   - Compare the base and both Git stages.
   - Preserve records created on either side.
   - When only one side changed a record, take that change.
   - When both sides changed the same record, use the newer `updated_at` record as the spine, then preserve unique comments, labels, dependencies, and fields contributed by the other side.
   - Resolve incompatible scalar fields using the same primary-source and merge-goal judgment as ordinary conflicts.
   - Write one record per ID in deterministic ID order.

   Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them -- typically typecheck, then tests, then format. For a resolved Beads file, also verify that every line parses, IDs are unique, conflict markers are absent, and the dependency graph has no cycles:

   ```bash
   jq -s 'all(.[]; (.id | type) == "string")
     and (length == (map(.id) | unique | length))' \
     .beads/issues.jsonl

   ! rg -n '^(<<<<<<<|=======|>>>>>>>)' .beads/issues.jsonl
   br dep cycles --json
   br lint
   ```

5. **Finish the merge/rebase.** Stage everything and commit. If rebasing, continue the rebase process until all commits are rebased, repeating this process for every new conflict. Once the Git operation is complete and `.beads/issues.jsonl` is clean, reconcile the local database:

   ```bash
   br sync --import-only
   br sync --status --json
   ```
