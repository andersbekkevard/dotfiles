---
name: fleet
description: Run commands, transfer files, open artifacts, or forward live services across Anders' Mac, Europa, and agent machines. Use whenever work must execute on, move to, or be shown from another machine.
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
fleet <machine> forward [--open] <source-port> [target-port]
fleet <machine> forward-status <target-port>
fleet <machine> forward-stop <target-port>
```

Use `put --open` for the common handoff where Anders should receive and see an
artifact on his Mac. The CLI verifies transferred files by SHA-256 and reports
the exact destination. Transfers fail rather than replace an existing file;
use `--force` only when replacement is intended. Prefer `fleet` over
handwritten SSH, SCP, hostnames, or quoting.

For a live HTTP service created away from Anders's Mac, use `fleet mac forward
--open <port>` without waiting for Anders to ask for forwarding. It creates a
managed Mac-loopback tunnel, verifies the service from the Mac, and opens it.
Report the URL and stop command. Use `tailnet-preview` only when Anders asks for
iPhone, Tailnet, or multi-device access; use `publish-web` for a public URL.
