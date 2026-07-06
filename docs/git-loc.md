# git-loc

`git-loc` estimates or counts lines of code in a remote Git repository without
downloading Git history.

For GitHub URLs, the default is a fast metadata estimate:

```bash
git-loc https://github.com/owner/repo
```

Use `--exact` when you need a source-content count:

## Exact count

```bash
git-loc --exact https://github.com/owner/repo
git-loc --exact https://github.com/owner/repo --ref main
git-loc --exact https://github.com/owner/repo --json
```

For GitHub URLs, exact mode defaults to a source archive snapshot. When
`python3` is available, `git-loc` streams that archive directly into the counter:
one archive download, no Git history, no `.git` directory, and no full working
tree extraction. If `python3` is unavailable, it falls back to extracting the
archive into a temporary directory before filtering/counting.

For other Git URLs, exact mode falls back to the partial Git strategy:

1. `git ls-remote` to resolve the inspected commit.
2. `git clone --depth=1 --filter=blob:none --no-checkout` to fetch commit and
   tree metadata without a checkout.
3. `git ls-tree` to enumerate files.
4. Source-file filtering to skip vendored, generated, build, cache, lock, and
   binary-like artifacts.
5. `git checkout --pathspec-from-file` to materialize selected files in one Git
   operation.
6. Local file counting inside the temporary clone.

Git does not store line counts as repository metadata. Exact counts still have
to read selected file contents somewhere. The GitHub archive strategy downloads
the current working-tree snapshot but skips all history, and its streaming path
also skips temporary checkout/extraction work. The partial strategy avoids
non-selected blobs, but can be slower on repositories with many selected files
because Git still has to negotiate promised blob contents.

To force a strategy:

```bash
git-loc https://github.com/owner/repo --strategy archive
git-loc https://github.com/owner/repo --strategy partial
```

## Estimate mode

```bash
git-loc https://github.com/owner/repo
git-loc --estimate https://github.com/owner/repo
```

Estimate mode supports GitHub URLs. It reads the GitHub languages API,
which reports bytes by language, then estimates lines as `bytes / 30`. Treat
this as a fast complexity proxy, not a source-of-truth line count.

Set `GITHUB_TOKEN` for private repositories or higher GitHub API limits:

```bash
GITHUB_TOKEN=... git-loc --estimate https://github.com/owner/private-repo
```

## Filtering options

```bash
git-loc --exact https://github.com/owner/repo --include-vendor
git-loc --exact https://github.com/owner/repo --include-docs
git-loc --exact https://github.com/owner/repo --exclude-tests
git-loc --exact https://github.com/owner/repo --max-blob-bytes 5242880
```

Exact mode includes source and test code by default, excludes common vendored and
generated paths, excludes docs, and skips individual blobs larger than 10 MiB.

## Exact benchmark

```bash
git-loc --benchmark-exact
git-loc --benchmark-exact BurntSushi/ripgrep sharkdp/fd
git-loc --benchmark-exact https://github.com/pallets/flask
```

The benchmark mode runs `git-loc --exact --no-cache --json` for each repository
and prints a compact timing table with exact LOC, counted files, skipped files,
and elapsed time. With no repositories supplied, it uses a representative public
GitHub set:

- `BurntSushi/ripgrep`
- `sharkdp/fd`
- `pallets/flask`
- `expressjs/express`
- `tokio-rs/axum`
- `rust-lang/rustlings`

## Cache

Results are cached under:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/git-loc/
```

The cache key includes the repository URL, ref, resolved commit, mode, and
filter options. Use `--no-cache` to force a fresh run.
