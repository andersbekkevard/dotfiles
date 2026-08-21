# Run a Tailnet preview

Tailscale Serve is the authority for the private URL. It is Tailnet-only; the
origin remains bound to loopback.

## Start temporarily

Verify the exact origin locally before exposing it. Read the current
`tailscale serve status --json`; an existing unowned configuration blocks the
operation.

Run foreground Serve as a transient user service:

```bash
origin=http://127.0.0.1:3000
unit=tailnet-preview
systemd-run --user --unit="$unit" --collect \
  --property=RuntimeMaxSec=4h --property=Restart=no -- \
  tailscale serve --yes "$origin"
```

Foreground Serve removes the shared route when the process exits. Do not add
`--bg` to a temporary preview. If Serve is disabled, inspect the unit journal,
return Tailscale's activation URL to Anders, and leave the empty initial Serve
configuration intact.

Derive the HTTPS URL from the active Serve status and the node's Tailscale DNS
name. Fetch the intended path through that URL and confirm it serves the same
origin. Record the exact UTC time four hours after the service started.

## Keep indefinitely

Only after Anders explicitly asks for indefinite availability, replace the
temporary foreground service with a verified background Serve configuration.
Report that it persists until manually removed and give the exact removal
command. Preserve any pre-existing Serve configuration; this skill may reset
the whole configuration only when its preflight proved the configuration was
empty and this run owns the only route.

## Inspect or close

Use both authorities:

```bash
systemctl --user status tailnet-preview.service --no-pager
tailscale serve status --json
```

Close a temporary preview by stopping its unit, then require an empty or
restored Serve configuration. Close an indefinite preview with the exact
Tailscale removal operation reported when it was created. Never stop the
origin application unless the caller owns that lifecycle too.
