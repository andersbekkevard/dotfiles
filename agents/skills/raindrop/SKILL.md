---
name: raindrop
description: Access or manage Anders' Raindrop bookmarks through the authenticated CLI/API on macOS and Linux. Use for Raindrop bookmarks, collections, tags, imports, exports, or API work.
---

# Raindrop

Use the `raindrop` CLI. It loads `RAINDROP_API_TOKEN` from the environment or
the git-crypt-managed `~/.secrets` file.

Start with `raindrop user` when authentication or machine setup is uncertain.
Use `raindrop request METHOD PATH [JSON|-]` for API operations; inspect
`raindrop --help` for the exact interface and the official Raindrop API docs
when an endpoint or request schema is uncertain.

Prefer the CLI/API. Use a browser only when Anders asks for it or the API does
not expose the required action.

Keep credentials out of commands, output, files, and logs. A read-only request
does not authorize bookmark or collection changes; make external changes only
when the task requests them.
