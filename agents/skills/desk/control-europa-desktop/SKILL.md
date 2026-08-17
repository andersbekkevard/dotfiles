---
name: control-europa-desktop
description: Open, inspect, or close Anders' private Mac Screen Sharing session to the persistent Europa agent desktop.
disable-model-invocation: true
---

# Control Europa Desktop

Give Anders full graphical control of Europa through native macOS Screen
Sharing. Keep the desktop substrate persistent; make VNC and its SSH tunnel
temporary.

## Run

Set the skill directory, then run exactly one operation:

If this skill is invoked without a requested operation, default to `open`.

```bash
SKILL_DIR="<this skill directory>"
"$SKILL_DIR/scripts/control-europa-desktop" open
"$SKILL_DIR/scripts/control-europa-desktop" status
"$SKILL_DIR/scripts/control-europa-desktop" close
```

### `open`

Use when Anders asks to control, view, or open Europa's desktop on his Mac.
The script:

1. proves that it is running on Europa;
2. starts the persistent desktop target and the on-demand loopback-only VNC
   service with a fresh per-session VNC credential;
3. creates a supervised reverse SSH tunnel from Europa to Mac loopback port
   selected afresh from `5901`–`5999`, avoiding Screen Sharing's per-endpoint
   credential cache;
4. passes that credential over the existing authenticated SSH stream to an
   AppleScript read from standard input, which opens native Screen Sharing
   without a password prompt;
5. verifies that Screen Sharing completed VNC authentication before returning
   success.

Report that Screen Sharing was opened and that `close` ends remote control
without stopping Codex or the desktop substrate. Never print the VNC password
or place it in a command argument, repository, log, clipboard, or persistent
Mac credential store. The script sends it only through SSH standard input.

### `status`

Use for a read-only audit. Report the script's `session`, desktop, VNC, tunnel,
Mac reachability, and Mac listener fields. Treat `session=open` as the complete
control path, `session=closed` as the expected idle state, and
`session=partial` as a repairable interrupted state.

### `close`

Use when Anders is finished or asks to shut the remote-control path. The script
stops the supervised SSH tunnel and VNC service, verifies that the Mac listener
is gone, invalidates the session credential, and leaves
`agent-desktop.target`, Xvfb, Openbox, Codex profiles, and scheduled
automations running.

## Boundaries

- Bind VNC and the Mac-side forwarded port only to loopback.
- Use the canonical Tailscale SSH identity with batch authentication and strict
  host-key checking.
- Treat an occupied Mac port not owned by this skill as a collision and stop.
- Preserve unrelated Screen Sharing windows and SSH sessions.
- Generate and invalidate an eight-character random credential for every
  control session. VNC authentication only uses the first eight characters.
- Keep authentication material out of output, command arguments, repositories,
  logs, clipboard operations, and persistent Mac credential stores.
- Use `close` after a completed human session; the access path is temporary by
  design.
