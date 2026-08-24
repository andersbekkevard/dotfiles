---
name: onboard-mcps
description: Reconcile the current machine's MCP clients with Anders' private desired-server registry.
disable-model-invocation: true
---

# Onboard MCPs

Read [the private registry](references/registry.toml) completely. It is the
authoritative list of MCPs Anders wants available, not a credential store or
proof that a live client works. If it is unavailable or still encrypted, stop
and report that this checkout must be unlocked with git-crypt.

Default to this machine and the clients named by each registry entry. If no
entry applies, say so. Inspect and parse the live client config before changing
it. For a listed server, the registry wins for transport, command or URL, and
authentication fields; reconcile divergent as well as missing registrations.

Use the client's supported CLI, expanding paths such as `~` before passing them.
Compare parsed config before and after each CLI mutation and restore any
unrelated fields it drops. Preserve unlisted servers and unrelated settings
unless Anders explicitly asks to remove them. If the client does not support a
registered transport or auth method, report the entry as blocked; do not invent
an adapter.

Use the registry's authentication contract without copying credential values
into the registry, commands, logs, or replies. OAuth may require Anders to
complete an interactive login. An environment-backed entry is ready only when
the named variable is available to the MCP process, whether inherited directly
or loaded by the registered command. Do not extract or reuse tokens from a
client's private store.

Verify through the configured client by discovering its tools and making the
registry's harmless read-only call. Treat protocol or tool errors as failures.
Report only the outcome, never the returned payload. If the client needs a new
process or task before tools appear, leave the entry explicitly pending that
fresh-session verification; do not substitute a hand-built client. Report
registration, authentication, tool discovery, and verification as distinct
states, and call an entry complete only after all four succeed.

Keep this skill small. Extend the registry when Anders names another desired
MCP, without credential values. When changing it, stage `.gitattributes` first
and confirm the staged registry blob is git-crypt ciphertext before committing.
Add procedure here only after repeated use exposes a general rule.
