# Raindrop

The `scripts` Stow package installs `raindrop` into `~/.local/bin` on macOS
and Linux. The command is a thin authenticated wrapper around Raindrop's REST
API; it does not encode a collection, tagging, or bookmark workflow.

Authentication comes from `RAINDROP_API_TOKEN` in the git-crypt-managed
`shell/.secrets`, stowed as `~/.secrets`. The command sources that file when the
variable is absent, so non-interactive agents do not depend on interactive
shell startup.

After cloning or pulling dotfiles on an authorized machine:

```bash
git-crypt unlock <keyfile>
./dotfiles.sh stow shell scripts
./dotfiles.sh agents sync
raindrop user
```

`raindrop user` is the authentication health check. General access uses
`raindrop request METHOD PATH [JSON|-]`; run `raindrop --help` for examples.
Absolute request URLs are rejected so the bearer token can only be sent to the
configured Raindrop API origin.
