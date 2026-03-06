# Secrets

Secrets are tracked with `git-crypt` in `shell/.secrets`, which stows to `~/.secrets`.

## Unlock flow

```bash
git-crypt unlock <keyfile>
```

`init.sh` does not fail if the repository is still locked. It prints a reminder and continues with non-secret setup.

`shell/.zshrc` only sources `~/.secrets` when the file exists and looks like readable text.

Export a symmetric key from an already-authorized clone when onboarding a new machine:

```bash
git-crypt export-key /secure/location/dotfiles-git-crypt.key
```
