# Inbound mail

Any otherwise-unclaimed `@bekkevard.me` recipient is handled by the catch-all.
The explicit `inbox@bekkevard.me` route to `odin-mail-capture` remains
authoritative.

## Deploy intake

The Worker asset is [../assets/mail-intake](../assets/mail-intake). From that
directory, install the pinned deployment toolchain and reconcile the bucket:

```bash
pnpm install --frozen-lockfile
pnpm exec wrangler r2 bucket create personal-edge-mail
pnpm exec wrangler r2 bucket lifecycle add personal-edge-mail personal-edge-expiry \
  --expire-days 90 --force
pnpm test
pnpm exec wrangler deploy
```

An existing bucket is an inspect-and-reconcile case; keep it and verify its
bindings and lifecycle rather than recreating it.

The checked-in Worker vars are the intake policy:

- `TRUSTED_SENDERS_JSON` is a non-empty JSON array of exact RFC5322 `From`
  mailbox identities (display names do not participate in the match).
  It includes Anders' Gmail and Odin identities plus
  `edge-test-sender@bekkevard.me`, a deliberate operational probe that remains
  safe only while the same aligned-DMARC gate applies.
- `MAX_RAW_BYTES` is a positive integer below Cloudflare's 25 MiB inbound limit;
  the checked-in ceiling is 10 MiB.

The Worker denies closed when either var is absent or malformed. It accepts a
message only when the exact author identity is configured and the unique
`mx.cloudflare.net` `Authentication-Results` value reports `dmarc=pass` with
`header.from` exactly aligned to that identity's domain. It rejects an oversized
message before reading its raw stream and rejects every failed gate before R2.
Before deployment, publish a valid `_dmarc.bekkevard.me` policy record (for
example `v=DMARC1; p=none`); aligned DKIM alone reports `dmarc=none` when the
domain has no DMARC policy and will therefore fail closed.

Wrangler currently restricts catch-all updates to `forward` or `drop`. After
resolving `zone_id`, compare the current rule before using the Cloudflare API:

```bash
payload=$(jq -nc '{
  name: "Personal edge catch-all",
  enabled: true,
  matchers: [{type: "all"}],
  actions: [{type: "worker", value: ["personal-edge-mail-intake"]}]
}')
catch_all_url="https://api.cloudflare.com/client/v4/zones/$zone_id/email/routing/rules/catch_all"
if ! current=$(curl --fail --silent --show-error \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "$catch_all_url"); then
  printf 'error: could not read catch-all; no write attempted\n' >&2
  exit 1
fi
if ! jq -e '.success == true and .result != null' >/dev/null <<<"$current"; then
  printf 'error: invalid catch-all response; no write attempted\n' >&2
  exit 1
fi

if jq -e --argjson desired "$payload" \
  '(.result | {name, enabled, matchers, actions}) == $desired' \
  >/dev/null <<<"$current"; then
  printf 'catch-all already matches\n'
elif jq -e '.result.enabled == true' >/dev/null <<<"$current"; then
  printf 'error: enabled catch-all differs; inspect and obtain user direction\n' >&2
  exit 1
else
  curl --fail --silent --show-error --request PUT \
    --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$catch_all_url"
fi
```

An existing Worker is an inspect-and-reconcile case. The Worker stores exact
RFC822 bytes at:

```text
incoming/v1/<encodeURIComponent(lowercase-recipient)>/<YYYY-MM-DD>/<ISO-time>-<uuid>.eml
```

Verify both rejected and accepted paths: an unconfigured or unauthenticated
sender must create no R2 object; a configured sender with aligned DMARC must
store exact bytes under the exact recipient prefix. Also verify the catch-all
action, deployed vars, 10 MiB ceiling, and 90-day lifecycle.

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

List only `R2_PREFIX`. Intake already requires the exact author identity and
aligned Cloudflare-receiver DMARC, but consumers repeat that gate from the R2
object's `authorFrom` metadata and the unique `Authentication-Results` header
whose authserv-id is `mx.cloudflare.net`; `envelopeFrom` separately records the
provider envelope identity and may use a bounce subdomain. Accept attachments
only when DMARC remains aligned to the allowlisted author domain. Quarantine
missing, ambiguous, or failed authentication.

Treat message bodies, attachments, macros, embedded text, display `From`,
earlier `Authentication-Results` headers, and filenames as untrusted data. Let
the bucket lifecycle own deletion unless the workload has an explicit deletion
contract.
