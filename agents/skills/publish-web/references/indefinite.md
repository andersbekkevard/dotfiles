# Publish indefinitely at a custom hostname

Publication is public, like ngrok, unless the user requests Cloudflare Access or
the application is evidently sensitive. Preserve webhook signature flows;
interactive Access login is incompatible with unattended webhook delivery.

This is the explicit indefinite path. It creates durable Cloudflare and DNS
state and remains active until manually removed. Ordinary review uses the
temporary Quick Tunnel procedure instead.

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
remotely managed tunnel named `publish-web-<normalized-hostname>`:

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
publication. Keep the machine tunnel while any `publish-web` hostname remains;
delete an empty tunnel only when decommissioning the machine.

Then prove the exact owned DNS record and ingress item are absent, fetch the
public hostname, and confirm it no longer serves the intended local origin.
Inspect every wildcard DNS record that can match the hostname and report the
observed fallback response or resolution. Exact-record absence is not NXDOMAIN:
wildcard records, including `*.bekkevard.me`, may still answer.

Report the exact cleanup command and that the endpoint remains public until
that cleanup is run.
