# Share a local application privately

SSH loopback forwarding is the default lane for accessing a local HTTP service.
It avoids DNS and keeps the service private to the machines joined by SSH.

## Choose the direction

When the application runs on a remote host and Anders will open it on his Mac,
run this on the application host:

```bash
forward-to-me <remote-port> [mac-port]
```

When the application runs on Anders' Mac and a remote host must consume it, run
this on the consuming host:

```bash
forward-from-me <mac-port> [remote-port]
```

Use the application's localhost URL directly when the application and consumer
are on the same machine. Bind every forwarded listener to `127.0.0.1`. Use the
same port at both ends when it is free; otherwise select an unused consumer
port and report it.

## Run and prove

Verify the origin first. When Anders will open the URL after the agent responds,
start the forwarding helper under the workload's existing process supervisor
and record its command, PID, and log. A foreground process is sufficient for an
automated one-time check. The helpers use `ExitOnForwardFailure` and SSH
keepalives, so an establishment failure is terminal rather than a partially
working result.

On the consumer machine, verify the loopback listener and fetch the exact path
the user needs. Complete only when the SSH process remains live and the response
comes from the intended origin. Report the consumer URL as
`http://127.0.0.1:<port>` and keep a user-facing tunnel alive for the requested
viewing session. Stop a tunnel created only for automated verification after
that verification completes.
