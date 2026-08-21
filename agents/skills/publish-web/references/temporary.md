# Publish temporarily

Use a Cloudflare Quick Tunnel. It creates a random `trycloudflare.com` URL for
the lifetime of one `cloudflared` process, without a DNS record or account-side
tunnel to clean up. It is for review and development, not production. It has no
uptime guarantee, does not support server-sent events, and anyone with the URL
can reach the origin.

Verify the exact loopback origin and inspect it for admin routes, secrets,
source exposure, production bindings, and other content that should not become
public. Then run the Quick Tunnel as a transient user service:

```bash
origin=http://127.0.0.1:3000
unit=publish-web
systemd-run --user --unit="$unit" --collect \
  --property=RuntimeMaxSec=24h --property=Restart=no -- \
  cloudflared tunnel --no-autoupdate --url "$origin"
```

Cloudflare does not start Quick Tunnels when its default configuration file is
present. Preserve that file; use an isolated empty configuration only when the
installed CLI supports selecting one explicitly.

Read the unit journal for the generated `https://*.trycloudflare.com` URL. Wait
for HTTPS to serve the intended path and verify it against the local origin.
Record the exact UTC time 24 hours after the unit started.

The URL dies when the service stops or reaches `RuntimeMaxSec`; there is no DNS
record to remove. Inspect or close it with:

```bash
systemctl --user status publish-web.service --no-pager
systemctl --user stop publish-web.service
```

If Anders later wants indefinite availability, create a new stable custom
hostname through the indefinite procedure. A Quick Tunnel URL cannot be
promoted or preserved.
