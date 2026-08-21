---
name: tailnet-preview
description: Privately expose a local file, directory, or HTTP service to Anders' Tailnet devices for four hours by default. Use when Anders should inspect a live preview on his Mac or iPhone without making it public. For internet access, use publish-web.
---

# Tailnet preview

Create a Tailnet-only preview with [the run procedure](references/run.md).

Temporary is the default. Keep the foreground Tailscale Serve process under a
four-hour runtime limit; its exit removes the preview. An indefinite preview
requires Anders to ask for it explicitly.

Every successful handoff must state:

- the private URL and intended audience;
- the four-hour default and exact expiry time in UTC;
- that indefinite availability requires a manual request from Anders;
- the status and cleanup commands.

If Tailscale requires Anders to enable Serve, return its activation URL and
stop. Activation is the remaining outcome, not a completed preview.
