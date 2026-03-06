# Secrets

Secrets are expected to be tracked with `git-crypt` and stored in `.secrets`.

## Unlock flow

```bash
git-crypt unlock
```

`init.sh` does not fail if the repository is still locked. It prints a reminder and continues with non-secret setup.

`shell/.zshrc` only sources `~/.secrets` when the file exists and looks like readable text.
