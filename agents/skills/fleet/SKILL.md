---
name: fleet
description: Run commands, transfer files, or open artifacts across Anders' Mac, Europa, and agent machines. Use whenever work must execute on or move to another machine.
---

# Fleet

Use the `fleet` CLI. It gives every machine the same command and transfer
interface, backed by the Git-synced machine registry.

Start with `fleet list` when the target name is unclear and `fleet <machine>
check` when reachability matters. Then use the CLI's own help:

```bash
fleet <machine> run -- <command> [arg ...]
fleet <machine> put [--open] [--force] <local-file>... <destination-directory>
fleet <machine> get [--force] <remote-file>... <local-directory>
fleet <machine> open [--app <application>] <path-or-url>...
```

Use `put --open` for the common handoff where Anders should receive and see an
artifact on his Mac. The CLI verifies transferred files by SHA-256 and reports
the exact destination. Transfers fail rather than replace an existing file;
use `--force` only when replacement is intended. Prefer `fleet` over
handwritten SSH, SCP, hostnames, or quoting.

This skill owns commands and files between machines. Use `tailnet-preview` for
a private live HTTP service and `publish-web` for a public URL.
