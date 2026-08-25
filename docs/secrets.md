# Secrets

The [private repository content policy](../AGENTS.md#private-repository-content)
defines the semantic inventory and required commit checks. `.gitattributes` is
the authoritative exact path list. This document owns the operator unlock and
key-handling procedure.

The git-crypt key and asymmetric private keys stay outside Git. Secret values
may live only in paths explicitly protected by git-crypt. Keep them out of
public files, commands, logs, and replies.

Skill-usage batch paths expose only an opaque replica id and sequence. Their
contents include skill names, harness, invocation type, UTC day, and counts.
They never include prompts, transcript paths, hostnames, or session text.

## Unlock flow

```bash
git-crypt unlock <keyfile>
```

`dotfiles.sh` does not fail if the repository is still locked. It prints a reminder and continues with public work. Agent setup skips locked private skills, and Fleet rejects its locked private configuration with an unlock instruction.

`shell/.zshrc` only sources `~/.secrets` when the file exists and looks like readable text.

Export a symmetric key from an already-authorized clone when onboarding a new machine:

```bash
git-crypt export-key /secure/location/dotfiles-git-crypt.key
```

## Application Cloudflare services

The `publish-web` and `application-email` workflows use the account-owned
Cloudflare token and account id from `~/.secrets`. Publication owns remotely
managed `cloudflared` tunnels and DNS. Application email owns the generic
inbound-email Worker and its dedicated R2 bucket. Outbound mail uses the
existing `RESEND_API_KEY` and verified `bekkevard.me` Resend domain. Cloudflare
Email Sending requires Workers Paid and is not part of the system. The
application, mail consumer, and scheduler do not share a runtime or secret with
one another.

Validate the account-owned token at
`/accounts/$CLOUDFLARE_ACCOUNT_ID/tokens/verify`; the user-token verification
endpoint is not authoritative for this token type. Required permissions and
the safe operating procedures live in the global `publish-web` and
`application-email` skills. Tunnel tokens and workload-specific, read-only R2
credentials are derived operational secrets and must never be committed or
echoed.

Temporary public-review URLs are recorded and expired by a persistent systemd
user timer on Europa. The timer sources Europa's local `~/.secrets` at runtime;
expiry state and receipts live under `~/.local/state/personal-edge/` and contain
provider resource identifiers, never the API token itself. The tracked
implementation and operating procedure live in the global `publish-web` skill.
