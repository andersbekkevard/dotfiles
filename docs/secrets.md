# Secrets

Secrets are tracked with `git-crypt` in `shell/.secrets`, which stows to `~/.secrets`.

## Unlock flow

```bash
git-crypt unlock <keyfile>
```

`setup.sh` does not fail if the repository is still locked. It prints a reminder and continues with non-secret setup.

`shell/.zshrc` only sources `~/.secrets` when the file exists and looks like readable text.

Export a symmetric key from an already-authorized clone when onboarding a new machine:

```bash
git-crypt export-key /secure/location/dotfiles-git-crypt.key
```

## Personal Cloudflare edge

The `personal-edge` agent workflow uses the account-owned Cloudflare token and
account id from `~/.secrets` for two independent lanes: remotely managed
`cloudflared` tunnels and DNS, and the generic inbound-email Worker plus its
dedicated R2 bucket. Outbound mail is a third, separate lane using the existing
`RESEND_API_KEY` and verified `bekkevard.me` Resend domain; Cloudflare Email
Sending requires Workers Paid and is not part of the system. The application,
mail consumer, and scheduler do not share a runtime or secret with one another.

Validate the account-owned token at
`/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify`; the user-token verification
endpoint is not authoritative for this token type. Required permissions and the
safe operating procedure live in the global `personal-edge` skill. Tunnel
tokens and workload-specific, read-only R2 credentials are derived operational
secrets and must never be committed or echoed.
