---
name: cycle-codex-account
description: Placeholder for the paused Europa Codex account-cycling workflow.
disable-model-invocation: true
---

# Cycle Codex Account

> **PLACEHOLDER — NON-OPERATIONAL.** This skill records the target and the
> verified state as of 2026-08-12. It does not switch accounts, retrieve
> credentials, or change the Europa host.

## Invocation contract

On invocation:

1. Announce that the workflow remains a placeholder.
2. Summarize the current state and the unfinished gates below.
3. Stop before any login, logout, credential access, process control, profile
   mutation, or service change. Ask Anders whether to resume designing the
   migration.

Keep passwords, one-time codes, recovery material, OAuth tokens, and 1Password
service-account tokens inside approved secret storage and out of chat, shell
history, logs, and repositories.

## Wanted outcome

Make account selection on the headless Linux host `europa` deterministic and
low-burden for an agent-managed appliance:

- Operate native Codex scheduled automations on Europa from a Mac or phone.
- Select among `anders.bekkevard@gmail.com` (normal default),
  `spam.bekkevard@gmail.com`, and `js-coding26@gmail.com` without mixing OAuth,
  Chromium/Electron data, Codex state, or scheduled tasks.
- Give each account an isolated, persistent Codex profile and an explicit
  launcher/service identity.
- Preserve one canonical 1Password item for every managed login; avoid copied
  credentials that drift after an update.
- Eventually permit unattended reauthentication through a least-privilege
  machine identity scoped only to the custom `Europa` vault.
- Verify the active identity and automation continuity after every switch, with
  a recovery path that preserves the previously working profile.

## Current state

- The official Codex Linux preview is installed on Europa.
- A persistent headless GUI substrate runs under a virtual X display with
  Openbox, session D-Bus/keyring support, and user-level systemd services.
- The default Codex profile remains separate and signed in as `Ano Nymos`; its
  identity and processes are outside the cycling procedure.
- `agent-chatgpt-spam.service` uses:
  - `CODEX_HOME=/home/anders/.codex-profiles/spam`
  - `--user-data-dir=/home/anders/.config/Codex-profiles/spam`
- `spam.bekkevard@gmail.com` is signed into that isolated Codex profile.
- Codex Remote Control has been paired, and a native recurring automation was
  created from the remote surface and observed on Europa.
- A separate Chromium profile exists for the spam account.
- Google MFA for the spam account is configured and verified in 1Password.
- A custom 1Password vault named `Europa` exists. The spam login was moved from
  `Personal` into `Europa`, leaving one canonical item rather than a duplicate.
- 1Password CLI 2.38.1 is installed on Europa, but no 1Password account or
  persistent service identity is configured there.
- The proposed 1Password Service Account migration is explicitly on hold. No
  persistent token has been created, transferred, or installed.
- A prior long-running Codex app-server exhausted its inherited file-descriptor
  limit. Its live limit was raised without killing the process; a durable fix
  for future SSH-launched app servers remains unfinished.
- Profiles and login flows for `anders.bekkevard@gmail.com` and
  `js-coding26@gmail.com` have not been created or verified.

## Gates before implementation

Resume only after the design explicitly settles all of these:

1. Create a read-only 1Password Service Account scoped only to `Europa`, and
   bootstrap its token onto Europa without exposing it through chat, clipboard
   history, shell history, logs, or the repository.
2. Choose the local token custody mechanism and prove revocation, rotation,
   audit, and unattended read access, including TOTP retrieval.
3. Define the profile/service mapping for all three accounts and the exact
   switch semantics: preserve per-account tasks, launch the requested profile,
   verify identity, and avoid touching unrelated app-server sessions.
4. Test one reversible account transition end to end, including Remote Control,
   native scheduled automation, restart persistence, and rollback.
5. Make the app-server file-descriptor limit durable for future SSH sessions and
   verify it without disrupting the existing long-running process.

Replace this placeholder only after the complete procedure has been executed
successfully and its evidence, failure behavior, and recovery path are known.
