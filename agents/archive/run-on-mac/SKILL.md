---
name: run-on-mac
description: Run commands on Anders' Mac from the current Linux host over SSH/Tailscale, copy files to the Mac, open files or URLs in Comet, expose host-local TCP ports on the Mac, and present an interactive Linux desktop in the Mac browser through loopback-only noVNC. Use when Anders asks Codex on a Linux host to do something on his Mac, send or open an artifact there, open a page in Comet, expose a local service at localhost on the Mac, or control a GUI/browser running on the Linux host from the Mac.
---

# Run On Mac

Use the configured `mac` SSH alias. Keep ongoing work Codex-owned; do not ask Anders to run a per-session Mac command.

## Preflight

Run:

```bash
ssh mac 'printf "ok\\n"; hostname; id -un'
```

If it fails, inspect `tailscale status` and `tailscale ping anders-sin-macbook-pro` before changing keys. The expected endpoint is `anders-sin-macbook-pro`, user `andersbekkevard`, using the dedicated key configured in `~/.ssh/config`.

## Common operations

Use `scripts/mac.sh` for recurring operations:

```bash
# Run a command.
scripts/mac.sh run sw_vers

# Copy a local file into ~/Downloads/Codex on the Mac.
scripts/mac.sh copy /absolute/path/report.html

# Copy a file and open it in Comet.
scripts/mac.sh copy-open /absolute/path/report.html

# Open a URL in Comet.
scripts/mac.sh open-url https://example.com

# Expose local port 3000 as Mac localhost:3000 and open it in Comet.
scripts/mac.sh forward 3000 3000 --open

# Inspect or stop that tunnel.
scripts/mac.sh forward-status 3000
scripts/mac.sh forward-stop 3000

# Start an isolated Linux-host desktop and open it in Comet on the Mac.
scripts/mac.sh desktop-start --url https://example.com

# Reuse a persistent browser profile when the remote site requires login.
scripts/mac.sh desktop-start --url https://example.com --profile-dir /absolute/profile/path

# Inspect or stop the desktop, browser, noVNC, and SSH tunnel together.
scripts/mac.sh desktop-status
scripts/mac.sh desktop-stop
```

Prefer an unused Mac port when the requested port is occupied. Forward only to `127.0.0.1` on both ends unless Anders explicitly asks for LAN exposure. Use `ExitOnForwardFailure` and verify the Mac-side URL after creating a tunnel.

`desktop-start` creates a separate Xvfb display, launches headed Chromium on the current Linux host, and serves
it through x11vnc plus noVNC. It allocates unused display and loopback ports, records the systemd
user unit and tunnel state, and opens the viewer in Comet. It never exposes VNC or noVNC beyond
loopback. If dependencies are missing, use the explicit install command it prints; do not install
packages silently. Stop an existing managed desktop before starting another. Use a persistent
profile only when the task requires durable login state; otherwise accept the temporary profile.

For commands outside these helpers, use `ssh mac -- <command>` and `scp <source> mac:<destination>`. Quote remote paths and untrusted values carefully.

## Safety

- Treat the Mac as a distinct machine; confirm paths and working directories before mutation.
- Do not expose a forwarded port beyond Mac loopback by default.
- Do not open arbitrary downloaded content without checking its source.
- Stop temporary tunnels when they are no longer useful. Leave persistent tunnels running only when the task requires it, and report the Mac port and stop command.
- Treat the remote desktop as interactive access to the current Linux host. Keep its noVNC and VNC listeners on
  loopback, do not place secrets in command arguments, and stop it when supervision is complete.
