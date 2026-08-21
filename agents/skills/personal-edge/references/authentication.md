# Authentication

## Fresh machine

Use `./dotfiles.sh install full` on a headless machine, or the `macos` /
`linux-desktop` profile for those environments. These profiles install Codex
and `git-crypt`; bare `./dotfiles.sh` selects nothing. `minimal` requires Codex
and `git-crypt` to be provisioned separately.

Unlock the repository before expecting `~/.secrets` to contain provider
credentials:

```bash
git-crypt unlock <keyfile>
```

`codex login` authenticates Codex only. When encrypted provider credentials are
unavailable, use an authorized browser session and obtain explicit approval
before interactive provider login.

## Cloudflare

Source `~/.secrets` without printing it. It provides
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Validate the account-owned
token at its account endpoint:

```bash
source ~/.secrets
curl --fail --silent --show-error \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify"
```

Required account permissions: Cloudflare One Connector cloudflared Edit,
Workers Scripts Edit, Workers R2 Storage Edit, and Account Settings Read.
Required `bekkevard.me` zone permissions: DNS Edit, Zone Read, Email Routing
Rules Edit, and Workers Routes Edit.

Resolve the zone id for each run:

```bash
curl --fail --silent --show-error \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=bekkevard.me"
```

Proceed only after validation and a read of every resource the requested change
can affect.
