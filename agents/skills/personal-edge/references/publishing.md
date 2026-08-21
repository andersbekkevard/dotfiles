# Publish a local application

Publication is public, like ngrok, unless the user requests Cloudflare Access or
the application is evidently sensitive. Preserve webhook signature flows;
interactive Access login is incompatible with unattended webhook delivery.

## Set the lifetime

Treat a public review URL as temporary. Default its lifetime to 24 hours from
publication. A custom expiry is valid when the user gives one. Skip expiry only
when the user explicitly calls the endpoint durable or production, or explicitly
asks for no expiry.

After provider and HTTPS verification, record the exact ownership tuple on
Europa with `scripts/publication_expiry.py schedule`: hostname, zone id, tunnel
id, DNS record id and content, ingress service, and (when supervised) origin
host and systemd user unit. The command defaults to 24 hours; pass
`--expires-at` for a custom ISO-8601 instant. The expiry runner must live on
Europa, not on the published machine, so losing the origin cannot strand the
public route.

Install or refresh the Europa runner from the skill checkout with
`scripts/install_expiry_runner.sh`. This copies the tracked runtime and units
into Europa's home directory and enables the persistent systemd user timer.

Before declaring publication complete, prove the Europa
`personal-edge-expiry.timer` is enabled and active and that `status` lists the
hostname. If scheduling or timer verification fails, roll back the provider
publication unless the user explicitly chose a durable endpoint.

## Gate the hostname

Lowercase the requested hostname and trim a trailing dot. Accept it by default
only when it is one valid DNS label directly below `bekkevard.me`, such as
`new-app.bekkevard.me`. For a deeper name, proceed only when a read-only
Cloudflare inspection proves that an active Total TLS, advanced, or custom edge
certificate covers the exact hostname. An enabled setting or pending certificate
is not proof. Stop before every provider mutation when this gate fails.

## Reconcile

Normalize the machine hostname to lowercase ASCII letters, digits, and hyphens.
Before writing, record the exact DNS records, complete tunnel configuration, and
whether the tunnel already existed; these are the rollback image. Use one
remotely managed tunnel named `personal-edge-<normalized-hostname>`:

1. `GET /accounts/{account}/cfd_tunnel?is_deleted=false&name={name}`.
2. If absent, `POST /accounts/{account}/cfd_tunnel` with
   `{"name":"<name>","config_src":"cloudflare"}`.
3. Read `GET /accounts/{account}/cfd_tunnel/{tunnel}/configurations`.
4. Add or replace the requested ingress item, for example
   `{"hostname":"new-app.bekkevard.me","service":"http://localhost:3000"}`.
5. Preserve every unrelated item and keep one terminal
   `{"service":"http_status:404"}` last. PUT the complete merged config.
6. Create a proxied CNAME pointing the requested hostname to
   `<tunnel-id>.cfargotunnel.com`. An existing unrelated DNS record blocks the
   operation pending user direction.
7. Fetch `GET /accounts/{account}/cfd_tunnel/{tunnel}/token` without displaying
   it. Run `cloudflared tunnel run --token "$TUNNEL_TOKEN"` under the workload's
   process supervisor.

For a long-running Linux service, use
`sudo cloudflared service install "$TUNNEL_TOKEN"`. On macOS, use the supervisor
that owns the local app. Store the tunnel token only as a runtime secret.

Verify a connected connector, the exact DNS target and merged ingress item,
valid HTTPS, and content from the intended local port. If any post-mutation
verification fails, stop the connector started for this publication, restore the
recorded DNS records and complete tunnel configuration, and delete a tunnel
created by this run once it is empty. Verify the restored state before reporting
failure.

## Cleanup

Remove only the requested ingress item and the exact DNS record owned by this
publication. Keep the machine tunnel while any personal-edge hostname remains;
delete an empty tunnel only when decommissioning the machine.

Then prove the exact owned DNS record and ingress item are absent, fetch the
public hostname, and confirm it no longer serves the intended local origin.
Inspect every wildcard DNS record that can match the hostname and report the
observed fallback response or resolution. Exact-record absence is not NXDOMAIN:
wildcard records, including `*.bekkevard.me`, may still answer.

For an expiring publication, use `scripts/publication_expiry.py run-due` rather
than reimplementing cleanup. It fails closed when the exact DNS content or
ingress service no longer matches the recorded owner, removes DNS before
ingress, keeps unrelated routes and the shared tunnel, verifies both removals,
then stops and disables only the recorded origin unit. It writes a receipt under
`~/.local/state/personal-edge/receipts/` and removes the active expiry record
only after successful cleanup.
