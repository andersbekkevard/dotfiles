#!/usr/bin/env python3
# /// script
# dependencies = ["tiktoken>=0.7.0"]
# ///
"""Bundle selected text files into XML-safe file_context tags."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import html
import subprocess
import sys
from pathlib import Path

import tiktoken


DEFAULT_IGNORES = {
    ".git",
    ".next",
    ".turbo",
    ".venv",
    "__pycache__",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "tmp",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Wrap selected files in <file_context> XML-safe tags."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Root used for relative paths and glob expansion. Defaults to cwd.",
    )
    parser.add_argument(
        "--file",
        action="append",
        required=True,
        help="File, directory, glob, or !exclude pattern. May be repeated.",
    )
    parser.add_argument(
        "--max-file-bytes",
        type=int,
        default=750_000,
        help="Reject files larger than this. Defaults to 750000.",
    )
    parser.add_argument(
        "--max-total-chars",
        type=int,
        default=300_000,
        help="Reject bundles with more escaped content chars than this.",
    )
    parser.add_argument(
        "--max-total-tokens",
        type=int,
        help="Reject bundles with more tiktoken tokens than this.",
    )
    parser.add_argument(
        "--encoding",
        default="o200k_base",
        help="tiktoken encoding to use. Defaults to o200k_base.",
    )
    parser.add_argument(
        "--output",
        help="Write output to this file instead of stdout.",
    )
    parser.add_argument(
        "--copy",
        action="store_true",
        help="Copy output to the platform clipboard after writing.",
    )
    parser.add_argument(
        "--files-report",
        action="store_true",
        help="Print included files with per-file token counts to stderr.",
    )
    return parser.parse_args()


def format_int(value: int) -> str:
    return f"{value:,}".replace(",", " ")


def is_binary(path: Path) -> bool:
    chunk = path.read_bytes()[:4096]
    return b"\0" in chunk


def should_skip(path: Path, root: Path) -> bool:
    try:
        rel_parts = path.relative_to(root).parts
    except ValueError:
        rel_parts = path.parts
    return any(part in DEFAULT_IGNORES for part in rel_parts)


def expand_include(pattern: str, root: Path) -> list[Path]:
    candidate = (root / pattern).expanduser()
    if candidate.exists():
        if candidate.is_dir():
            return [p for p in candidate.rglob("*") if p.is_file()]
        return [candidate]

    matches = list(root.glob(pattern))
    expanded: list[Path] = []
    for match in matches:
        if match.is_dir():
            expanded.extend(p for p in match.rglob("*") if p.is_file())
        elif match.is_file():
            expanded.append(match)
    return expanded


def matches_exclude(path: Path, root: Path, excludes: list[str]) -> bool:
    rel = (
        path.relative_to(root).as_posix()
        if path.is_relative_to(root)
        else path.as_posix()
    )
    return any(fnmatch.fnmatch(rel, pattern) for pattern in excludes)


def collect_files(patterns: list[str], root: Path) -> list[Path]:
    includes = [p for p in patterns if not p.startswith("!")]
    excludes = [p[1:] for p in patterns if p.startswith("!")]

    seen: set[Path] = set()
    files: list[Path] = []
    for pattern in includes:
        for path in expand_include(pattern, root):
            resolved = path.resolve()
            if resolved in seen:
                continue
            if should_skip(resolved, root):
                continue
            if matches_exclude(resolved, root, excludes):
                continue
            seen.add(resolved)
            files.append(resolved)
    return sorted(
        files,
        key=lambda p: (
            p.relative_to(root).as_posix() if p.is_relative_to(root) else p.as_posix()
        ),
    )


def render_file(path: Path, root: Path, max_file_bytes: int) -> tuple[str, int, str]:
    size = path.stat().st_size
    if size > max_file_bytes:
        raise ValueError(
            f"{path}: {size} bytes exceeds --max-file-bytes={max_file_bytes}"
        )
    if is_binary(path):
        raise ValueError(f"{path}: appears to be binary")

    raw = path.read_bytes()
    text = raw.decode("utf-8", errors="replace")
    escaped = html.escape(text, quote=False)
    digest = hashlib.sha256(raw).hexdigest()[:16]
    rel = (
        path.relative_to(root).as_posix()
        if path.is_relative_to(root)
        else path.as_posix()
    )
    escaped_path = html.escape(rel, quote=True)
    block = (
        f'  <file path="{escaped_path}" bytes="{size}" sha256="{digest}" '
        'content_encoding="xml-escaped">\n'
        f"{escaped}\n"
        "  </file>"
    )
    return block, len(escaped), rel


def count_tokens(text: str, encoding_name: str) -> int:
    try:
        encoding = tiktoken.get_encoding(encoding_name)
    except ValueError as exc:
        raise ValueError(f"unknown tiktoken encoding: {encoding_name}") from exc
    return len(encoding.encode(text))


def copy_to_clipboard(text: str) -> None:
    commands = [["pbcopy"], ["wl-copy"], ["xclip", "-selection", "clipboard"], ["clip.exe"]]
    for command in commands:
        try:
            subprocess.run(command, input=text.encode(), check=True)
            return
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    raise RuntimeError("no supported clipboard tool found")


def main() -> int:
    args = parse_args()
    root = Path(args.root).expanduser().resolve()
    files = collect_files(args.file, root)
    if not files:
        print("No files matched.", file=sys.stderr)
        return 2

    blocks: list[str] = []
    included: list[tuple[str, int, int]] = []
    total_chars = 0
    for path in files:
        try:
            block, chars, rel = render_file(path, root, args.max_file_bytes)
        except ValueError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        total_chars += chars
        if total_chars > args.max_total_chars:
            print(
                f"error: bundle exceeds --max-total-chars={args.max_total_chars}",
                file=sys.stderr,
            )
            return 2
        try:
            block_tokens = count_tokens(block, args.encoding)
        except ValueError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2
        included.append((rel, chars, block_tokens))
        blocks.append(block)

    body = "\n".join(blocks)
    output = ""
    chars = len("<file_context>\n" + body + "\n</file_context>\n")
    try:
        tokens = count_tokens(
            "<file_context>\n" + body + "\n</file_context>\n", args.encoding
        )
        for _ in range(8):
            output = (
                f'<file_context files="{len(files)}" chars="{chars}" '
                f'tokens="{tokens}" tokenizer="tiktoken:{args.encoding}">\n'
                f"{body}\n"
                "</file_context>\n"
            )
            next_chars = len(output)
            next_tokens = count_tokens(output, args.encoding)
            if next_chars == chars and next_tokens == tokens:
                break
            chars = next_chars
            tokens = next_tokens
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.max_total_tokens is not None and tokens > args.max_total_tokens:
        print(
            "error: bundle has "
            f"{format_int(tokens)} tokens, exceeding "
            f"--max-total-tokens={format_int(args.max_total_tokens)}",
            file=sys.stderr,
        )
        return 2

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        sys.stdout.write(output)

    print(
        "Bundled "
        f"{format_int(len(files))} files, "
        f"{format_int(chars)} chars, "
        f"{format_int(tokens)} tokens "
        f"(tiktoken:{args.encoding}).",
        file=sys.stderr,
    )
    if args.files_report:
        print("Files:", file=sys.stderr)
        for rel, file_chars, file_tokens in included:
            print(
                f"- {rel} ({format_int(file_chars)} chars, "
                f"{format_int(file_tokens)} tokens)",
                file=sys.stderr,
            )

    if args.copy:
        try:
            copy_to_clipboard(output)
        except RuntimeError as exc:
            print(f"warning: {exc}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
