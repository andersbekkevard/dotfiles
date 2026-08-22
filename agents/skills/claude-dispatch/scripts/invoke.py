#!/usr/bin/env python3
"""Invoke Claude Code with an explicit prompt, access boundary, and audit trail."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path


EFFORTS = ("low", "medium", "high", "xhigh", "max")
ACCESS_MODES = ("closed", "agentic")
SANITIZED_ENV = (
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL",
    "CLAUDE_CODE_USE_BEDROCK",
    "CLAUDE_CODE_USE_VERTEX",
    "CLAUDE_CODE_USE_FOUNDRY",
    "XAI_API_KEY",
    "XAI_API_BASE_URL",
    "GROK_CODE_XAI_API_KEY",
    "GROK_XAI_API_BASE_URL",
    "GROK_CLI_BASE_URL",
    "CLI_CHAT_PROXY_BASE_URL",
    "GROK_CLI_CHAT_PROXY_BASE_URL",
)
THREAD_ID_PATTERN = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", re.I)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a ready prompt through Claude Code without assembling it."
    )
    parser.add_argument("prompt_file", metavar="PROMPT_FILE")
    parser.add_argument("--output", required=True, metavar="PATH")
    parser.add_argument(
        "--access",
        choices=ACCESS_MODES,
        default="closed",
        help="Tool boundary: closed (default) or unrestricted agentic.",
    )
    parser.add_argument(
        "--root",
        metavar="DIR",
        help="Starting directory; required for agentic access but not a containment boundary.",
    )
    parser.add_argument("--model", default="claude-fable-5")
    parser.add_argument("--effort", choices=EFFORTS, default="high")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and print the effective boundary without invoking Claude.",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"claude-dispatch: {message}")


def timestamp() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sanitized_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name in SANITIZED_ENV:
        environment.pop(name, None)
    return environment


def validate_file(raw_path: str, label: str) -> Path:
    path = Path(raw_path).expanduser()
    if path.is_symlink():
        fail(f"{label} must not be a symlink: {raw_path}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        fail(f"cannot read {label} {raw_path}: {exc}")
    if not resolved.is_file():
        fail(f"{label} is not a regular file: {raw_path}")
    if b"\0" in resolved.read_bytes()[:4096]:
        fail(f"{label} is binary: {raw_path}")
    return resolved


def validate_root(args: argparse.Namespace) -> Path | None:
    if args.access != "closed" and not args.root:
        fail(f"--root is required for --access {args.access}")
    if not args.root:
        return None
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"--root is not a directory: {args.root}")
    return root


def command_for(args: argparse.Namespace) -> list[str]:
    command = [
        "claude",
        "--safe-mode",
        "--strict-mcp-config",
        "--disallowedTools",
        "mcp__*",
        "--tools",
        "" if args.access == "closed" else "default",
    ]
    if args.access == "agentic":
        command.append("--dangerously-skip-permissions")
    command.extend(
        (
            "--print",
            "--no-session-persistence",
            "--output-format",
            "text",
            "--model",
            args.model,
            "--effort",
            args.effort,
        )
    )
    return command


def verify_subscription(environment: dict[str, str], cwd: Path) -> None:
    try:
        result = subprocess.run(
            ["claude", "auth", "status"],
            cwd=cwd,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        fail("claude is not available on PATH")
    if result.returncode != 0:
        fail("Claude Code authentication check failed")
    try:
        status = json.loads(result.stdout)
    except json.JSONDecodeError:
        fail("Claude Code authentication status was not valid JSON")
    subscription = status.get("subscriptionType")
    if not (
        status.get("loggedIn") is True
        and status.get("authMethod") == "claude.ai"
        and isinstance(subscription, str)
        and subscription
    ):
        fail("Claude Code must use a claude.ai subscription")


def atomic_json(path: Path, data: dict[str, object]) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def copy_private(source: Path, destination: Path) -> None:
    shutil.copyfile(source, destination)
    destination.chmod(0o600)


def git_metadata(root: Path | None) -> dict[str, object] | None:
    if root is None:
        return None
    try:
        commit = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            capture_output=True,
            check=False,
        )
        status = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain"],
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        return {"root": str(root), "commit": None, "dirty": None}
    return {
        "root": str(root),
        "commit": commit.stdout.strip() if commit.returncode == 0 else None,
        "dirty": bool(status.stdout) if status.returncode == 0 else None,
    }


def codex_metadata() -> dict[str, object]:
    thread_id = os.environ.get("CODEX_THREAD_ID")
    metadata: dict[str, object] = {
        "thread_id": thread_id,
        "rollout_path": None,
        "rollout_byte_offset": None,
        "resolution": "unavailable",
    }
    if not thread_id:
        return metadata
    if not THREAD_ID_PATTERN.fullmatch(thread_id):
        metadata["resolution"] = "invalid-thread-id"
        return metadata
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    matches = sorted(
        (codex_home.expanduser() / "sessions").glob(
            f"*/*/*/rollout-*-{thread_id}.jsonl"
        )
    )
    if len(matches) != 1:
        metadata["resolution"] = "missing" if not matches else "ambiguous"
        return metadata
    rollout = matches[0].resolve()
    metadata.update(
        {
            "rollout_path": str(rollout),
            "rollout_byte_offset": rollout.stat().st_size,
            "resolution": "resolved",
        }
    )
    return metadata


def archive_root() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME")
    base = Path(state_home).expanduser() if state_home else Path.home() / ".local/state"
    root = base / "claude-dispatch" / "runs"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.parent.chmod(0o700)
    root.chmod(0o700)
    return root


def begin_archive(
    args: argparse.Namespace, prompt: Path, root: Path | None
) -> tuple[Path, dict[str, object]]:
    run_id = (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        + f"-{uuid.uuid4().hex[:12]}"
    )
    run_dir = archive_root() / run_id
    run_dir.mkdir(mode=0o700)
    copy_private(prompt, run_dir / "prompt.md")
    manifest: dict[str, object] = {
        "schema_version": 1,
        "run_id": run_id,
        "created_at": timestamp(),
        "finished_at": None,
        "status": "running",
        "access": args.access,
        "model": args.model,
        "effort": args.effort,
        "prompt_sha256": sha256(prompt),
        "response_sha256": None,
        "repository": git_metadata(root),
        "codex": codex_metadata(),
        "artifacts": {"prompt": "prompt.md", "response": None},
    }
    atomic_json(run_dir / "manifest.json", manifest)
    return run_dir, manifest


def invoke(
    command: list[str],
    prompt: Path,
    output: Path,
    environment: dict[str, str],
    cwd: Path,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        with prompt.open("rb") as prompt_handle, os.fdopen(fd, "wb") as output_handle:
            result = subprocess.run(
                command,
                cwd=cwd,
                env=environment,
                stdin=prompt_handle,
                stdout=output_handle,
                check=False,
            )
        if result.returncode != 0:
            fail(f"Claude Code exited with status {result.returncode}")
        if os.path.getsize(temp_name) == 0:
            fail("Claude Code returned an empty result")
        os.replace(temp_name, output)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    args = parse_args()
    prompt = validate_file(args.prompt_file, "prompt")
    output = Path(args.output).expanduser().resolve()
    root = validate_root(args)
    command = command_for(args)
    if args.dry_run:
        print(f"Access: {args.access}")
        print(f"Working root: {root if root is not None else 'isolated temporary directory'}")
        print(f"Model: {args.model}")
        print(f"Effort: {args.effort}")
        print("Dry run: Claude not invoked")
        return 0

    try:
        run_dir, manifest = begin_archive(args, prompt, root)
    except OSError as exc:
        fail(f"cannot create private run archive: {exc}")

    try:
        environment = sanitized_environment()
        if args.access == "closed":
            with tempfile.TemporaryDirectory(prefix="claude-dispatch.") as neutral:
                cwd = Path(neutral)
                verify_subscription(environment, cwd)
                invoke(command, prompt, output, environment, cwd)
        else:
            assert root is not None
            verify_subscription(environment, root)
            invoke(command, prompt, output, environment, root)
        copy_private(output, run_dir / "result.md")
    except BaseException as exc:
        manifest.update(
            {
                "finished_at": timestamp(),
                "status": "failed",
                "failure_type": type(exc).__name__,
                "failure": str(exc.code) if isinstance(exc, SystemExit) else None,
            }
        )
        atomic_json(run_dir / "manifest.json", manifest)
        raise

    manifest.update(
        {
            "finished_at": timestamp(),
            "status": "completed",
            "response_sha256": sha256(output),
            "artifacts": {"prompt": "prompt.md", "response": "result.md"},
        }
    )
    atomic_json(run_dir / "manifest.json", manifest)
    print(f"Claude result: {output}")
    print(f"Claude dispatch: {args.model} | effort: {args.effort} | access: {args.access}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
