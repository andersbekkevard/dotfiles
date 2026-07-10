# Inbound mail

Any otherwise-unclaimed `@bekkevard.me` recipient is handled by the catch-all.
The explicit `inbox@bekkevard.me` route to `odin-mail-capture` remains
authoritative.

## Deploy intake

The Worker asset is [../assets/mail-intake](../assets/mail-intake). From that
directory:

```bash
pnpm dlx wrangler r2 bucket create personal-edge-mail
pnpm dlx wrangler r2 bucket lifecycle add personal-edge-mail personal-edge-expiry \
  --expire-days 90 --force
pnpm test
pnpm dlx wrangler deploy
```

Wrangler currently restricts catch-all updates to `forward` or `drop`; use the
Cloudflare API for the Worker action after resolving `zone_id`:

```bash
payload=$(jq -nc '{
  name: "Personal edge catch-all",
  enabled: true,
  matchers: [{type: "all"}],
  actions: [{type: "worker", value: ["personal-edge-mail-intake"]}]
}')
curl --fail --silent --show-error --request PUT \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  --header 'Content-Type: application/json' \
  --data "$payload" \
  "https://api.cloudflare.com/client/v4/zones/$zone_id/email/routing/rules/catch_all"
```

An existing bucket, Worker, or rule is an inspect-and-reconcile case. The Worker
stores exact RFC822 bytes at:

```text
incoming/v1/<encodeURIComponent(lowercase-recipient)>/<YYYY-MM-DD>/<ISO-time>-<uuid>.eml
```

Verify the catch-all action, successful Worker invocation, exact recipient
prefix, raw bytes, and 90-day lifecycle.

## Consume safely

Create credentials at **Cloudflare Dashboard > R2 > Manage R2 API Tokens >
Create Account API token**. Choose **Object Read only**, limit it to
`personal-edge-mail`, and set an expiry for temporary workloads. Keep the Access
Key ID and Secret Access Key in the workload's secret store:

```text
AWS_ACCESS_KEY_ID=<R2 Access Key ID>
AWS_SECRET_ACCESS_KEY=<R2 Secret Access Key>
AWS_ENDPOINT_URL=https://<CLOUDFLARE_ACCOUNT_ID>.r2.cloudflarestorage.com
AWS_REGION=auto
AWS_DEFAULT_REGION=auto
R2_BUCKET=personal-edge-mail
R2_PREFIX=incoming/v1/<encodeURIComponent(lowercase-recipient)>/
```

List only `R2_PREFIX`. For each message, require the exact expected envelope
sender and the Cloudflare-receiver `Authentication-Results` header whose
authserv-id is `mx.cloudflare.net`. Accept attachments only when it reports
`dmarc=pass` with `header.from` aligned to the allowlisted sender domain.
Quarantine missing, ambiguous, or failed authentication.

Treat message bodies, attachments, macros, embedded text, display `From`,
earlier `Authentication-Results` headers, and filenames as untrusted data. Let
the bucket lifecycle own deletion unless the workload has an explicit deletion
contract.
