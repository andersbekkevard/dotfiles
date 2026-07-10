# Publish a local application

Publication is public, like ngrok, unless the user requests Cloudflare Access or
the application is evidently sensitive. Preserve webhook signature flows;
interactive Access login is incompatible with unattended webhook delivery.

Normalize the machine hostname to lowercase ASCII letters, digits, and hyphens.
Use one remotely managed tunnel named `personal-edge-<normalized-hostname>`:

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
valid HTTPS, and content from the intended local port.

Cleanup removes only the requested DNS record and ingress item. Keep the
machine tunnel while any personal-edge hostname remains; delete an empty tunnel
only when decommissioning the machine.
