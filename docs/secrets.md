# Secrets

Private repository content uses `git-crypt`. It includes:

- `shell/.secrets`, which stows to `~/.secrets`;
- skill evidence under `agents/skill-uses/` and usage batches under
  `agents/skill-usage-batches/`;
- the private MCP registry;
- the complete `application-email`, `control-europa-desktop`, and
  `cycle-codex-account` skills;
- Fleet's machine registry and verified host identities; and
- benchmark cases reconstructed from Anders's real sessions.

Reusable procedures, runners, and sanitized examples remain public. Private
keys, the git-crypt key, raw credentials, and access tokens stay outside Git
even when a path is encrypted.

Skill-usage batch paths expose only an opaque replica id and sequence. Their
contents include skill names, harness, invocation type, UTC day, and counts.
They never include prompts, transcript paths, hostnames, or session text.

## Unlock flow

```bash
git-crypt unlock <keyfile>
```

`dotfiles.sh` does not fail if the repository is still locked. It prints a reminder and continues with public work. Agent setup skips locked private skills, and Fleet rejects its locked private configuration with an unlock instruction.

Before committing protected content, verify the index rather than trusting the
attribute declaration:

```bash
agents/git-crypt-check staged
```

After committing or fetching, verify a tree or remote ref:

```bash
agents/git-crypt-check tree HEAD
agents/git-crypt-check tree origin/main
```

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
