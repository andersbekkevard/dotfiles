# Operate Anders' Mac

This lane owns the current Mac endpoint and the mechanics for copying files or
executing a task-owned command there. The calling skill owns what the files are
and what the command should do.

## Connect

Use the canonical SSH target:

```bash
mac_target='andersbekkevard@anders-sin-macbook-pro.tailbcf03b.ts.net'
ssh -o BatchMode=yes -o ConnectTimeout=10 "$mac_target" /usr/bin/true
```

Treat a failed probe as unavailable connectivity. Do not silently substitute a
remembered IP address.

## Copy

Create the exact destination remotely before copying. The installed SCP uses
SFTP path semantics, so pass the remote path directly as part of the quoted
destination argument:

```bash
scp -p -- <local-files...> "$mac_target:$remote_path/"
```

The caller supplies the files and destination. Copy only its staged set.

## Run

Build the task-owned command as an argument-safe remote shell string, then pass
that one string to SSH:

```bash
remote_command=$(printf '%q ' <executable> <arg1> <arg2> ...)
ssh -o BatchMode=yes -o ConnectTimeout=10 "$mac_target" "$remote_command"
```

Use absolute executable and file paths when available. Keep dynamic values as
arguments to `printf`; do not interpolate them into shell source.

## Prove

Verify the result with a separate read-only remote command: list copied paths,
check hashes or counts, inspect the expected process or application state, or
read the exact output requested by the caller. Report the endpoint hostname and
proof without credentials or unrelated remote state.
