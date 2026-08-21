---
name: publish-web
description: Publish a local HTTP service to the public internet for 24 hours by default. Use when Anders explicitly asks for a public URL, public web access, or an indefinite production hostname. For ordinary Mac-only viewing, use fleet forwarding; for iPhone or Tailnet access, use tailnet-preview.
---

# Publish web

Publication is public. Confirm the application is suitable for internet access
and preserve any authentication or webhook requirements.

Choose one mode:

- ordinary public preview: use [temporary publication](references/temporary.md);
- explicit indefinite, durable, or production endpoint: read
  [authentication](references/authentication.md), then use
  [indefinite publication](references/indefinite.md).

Temporary is the default and lasts 24 hours. Indefinite publication requires
Anders to ask for it explicitly and creates a stable custom hostname; it cannot
preserve a temporary random URL.

Every successful handoff must state:

- that the URL is public;
- the 24-hour default and exact expiry time in UTC, or that the endpoint is
  indefinite;
- that indefinite availability requires a manual request from Anders;
- the status and cleanup commands.
