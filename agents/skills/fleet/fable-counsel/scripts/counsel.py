#!/usr/bin/env python3
# /// script
# dependencies = ["tiktoken>=0.7.0"]
# ///
"""Compose and run an isolated Fable counsel consultation."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path


EFFORTS = ("low", "medium", "high", "xhigh", "max")
MODES = ("propose", "challenge")
SANITIZED_ENV = (
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL",
    "CLAUDE_CODE_USE_BEDROCK",
    "CLAUDE_CODE_USE_VERTEX",
    "CLAUDE_CODE_USE_FOUNDRY",
)
THREAD_ID_PATTERN = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", re.I)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        usage="%(prog)s WORK_DIR [options]",
        description=(
            "WORK_DIR: brief.md plus optional intent/anchors/repo-model.md; "
            "writes prompt.md and fable.md."
        ),
        add_help=False,
    )
    parser.add_argument("-h", "--help", action="help", help="Show help.")
    parser.add_argument(
        "work_dir",
        metavar="WORK_DIR",
        help="Input/output directory.",
    )
    parser.add_argument(
        "--root", default=".", metavar="DIR", help="Repository root."
    )
    parser.add_argument(
        "--mode",
        choices=MODES,
        required=True,
        help="propose or challenge.",
    )
    parser.add_argument(
        "--doc",
        action="append",
        default=[],
        metavar="PATH",
        help="Whole repo file.",
    )
    parser.add_argument(
        "--excerpt",
        action="append",
        default=[],
        metavar="PATH:START-END",
        help="Exact repo line range.",
    )
    parser.add_argument(
        "--redacted",
        action="append",
        default=[],
        metavar="PATH",
        help="Sanitized authored file.",
    )
    parser.add_argument(
        "--digest",
        action="append",
        default=[],
        metavar="PATH",
        help="Agent-authored digest.",
    )
    parser.add_argument(
        "--effort",
        choices=EFFORTS,
        default="high",
        metavar="LEVEL",
        help="Reasoning effort (high).",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Enable unrestricted repository tools.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Compose only; do not invoke Claude.",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"counsel: {message}")


def sanitized_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name in SANITIZED_ENV:
        environment.pop(name, None)
    return environment


def format_int(value: int) -> str:
    return f"{value:,}".replace(",", " ")


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


def git_metadata(root: Path) -> dict[str, object]:
    try:
        commit = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            capture_output=True,
            check=False,
        )
        if commit.returncode != 0:
            return {"root": str(root), "commit": None, "dirty": None}
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
        "commit": commit.stdout.strip(),
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
    sessions = codex_home.expanduser() / "sessions"
    matches = sorted(sessions.glob(f"*/*/*/rollout-*-{thread_id}.jsonl"))
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
    root = base / "fable-counsel" / "runs"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.parent.chmod(0o700)
    root.chmod(0o700)
    return root


def begin_archive(
    args: argparse.Namespace,
    prompt: Path,
    packet: dict[str, object],
) -> tuple[Path, dict[str, object]]:
    created_at = timestamp()
    run_id = (
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        + f"-{uuid.uuid4().hex[:12]}"
    )
    run_dir = archive_root() / run_id
    run_dir.mkdir(mode=0o700)
    copy_private(prompt, run_dir / "prompt.md")
    manifest: dict[str, object] = {
        "schema_version": 4,
        "run_id": run_id,
        "created_at": created_at,
        "finished_at": None,
        "status": "running",
        "mode": args.mode,
        "access": "open" if args.open else "packet",
        "effort": args.effort,
        "prompt_tokens": packet["prompt_tokens"],
        "prompt_sections": packet["prompt_sections"],
        "token_encoding": packet.get("token_encoding"),
        "prompt_sha256": sha256(prompt),
        "response_sha256": None,
        "repository": git_metadata(Path(args.root).expanduser().resolve()),
        "codex": codex_metadata(),
        "artifacts": {"prompt": "prompt.md", "response": None},
    }
    atomic_json(run_dir / "manifest.json", manifest)
    return run_dir, manifest


def compose(
    args: argparse.Namespace, work_dir: Path, prompt: Path
) -> dict[str, object]:
    script = Path(__file__).with_name("compose_packet.py")
    metadata = work_dir / ".packet-metadata.json"
    command = [
        sys.executable,
        str(script),
        "--root",
        str(Path(args.root).expanduser().resolve()),
        "--mode",
        args.mode,
        "--brief",
        str(work_dir / "brief.md"),
        "--output",
        str(prompt),
        "--metadata-output",
        str(metadata),
    ]
    intent = work_dir / "user-intent.md"
    anchors = work_dir / "user-anchors.md"
    repository_model = work_dir / "repo-model.md"
    if intent.exists():
        command.extend(("--user-intent", str(intent)))
    if anchors.exists():
        command.extend(("--user-anchors", str(anchors)))
    if repository_model.exists():
        command.extend(("--repository-model", str(repository_model)))
    for flag, values in (
        ("--document", args.doc),
        ("--excerpt", args.excerpt),
        ("--redacted-document", args.redacted),
        ("--digest", args.digest),
    ):
        for value in values:
            command.extend((flag, value))
    if args.open:
        command.append("--open")
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    try:
        packet = json.loads(metadata.read_text())
    except (OSError, json.JSONDecodeError):
        fail("packet metadata was not valid JSON")
    finally:
        metadata.unlink(missing_ok=True)
    prompt_tokens = packet.get("prompt_tokens")
    prompt_sections = packet.get("prompt_sections")
    section_names = {
        "instructions",
        "user_intent",
        "user_anchors",
        "repository_model",
        "context",
        "sol_brief",
        "structure",
    }
    if (
        packet.get("schema_version") != 2
        or packet.get("mode") != args.mode
        or type(prompt_tokens) is not int
        or not isinstance(prompt_sections, dict)
        or set(prompt_sections) != section_names
        or any(
            type(value) is not int or value < 0 for value in prompt_sections.values()
        )
        or sum(prompt_sections.values()) != prompt_tokens
    ):
        fail("packet metadata was incomplete")
    return packet


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


def invoke(
    prompt: Path,
    output: Path,
    effort: str,
    environment: dict[str, str],
    cwd: Path,
    open_access: bool,
) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        with prompt.open("rb") as prompt_handle, os.fdopen(fd, "wb") as output_handle:
            command = [
                "claude",
                "--safe-mode",
                "--strict-mcp-config",
                "--disallowedTools",
                "mcp__*",
                "--tools",
                "default" if open_access else "",
            ]
            if open_access:
                command.append("--dangerously-skip-permissions")
            command.extend(
                [
                    "--print",
                    "--no-session-persistence",
                    "--output-format",
                    "text",
                    "--model",
                    "claude-fable-5",
                    "--effort",
                    effort,
                ]
            )
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
            fail("Claude Code returned empty counsel")
        os.replace(temp_name, output)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    args = parse_args()
    work_dir = Path(args.work_dir).expanduser().resolve()
    if not work_dir.is_dir():
        fail(f"work directory does not exist: {args.work_dir}")
    prompt = work_dir / "prompt.md"
    output = work_dir / "fable.md"
    packet = compose(args, work_dir, prompt)
    if args.dry_run:
        print("Dry run: Claude not invoked")
        return 0

    try:
        run_dir, manifest = begin_archive(args, prompt, packet)
    except OSError as exc:
        fail(f"cannot create private run archive: {exc}")

    try:
        environment = sanitized_environment()
        if args.open:
            run_cwd = Path(args.root).expanduser().resolve()
            verify_subscription(environment, run_cwd)
            invoke(prompt, output, args.effort, environment, run_cwd, True)
        else:
            with tempfile.TemporaryDirectory(prefix="fable-counsel-run.") as neutral:
                run_cwd = Path(neutral)
                verify_subscription(environment, run_cwd)
                invoke(prompt, output, args.effort, environment, run_cwd, False)
        copy_private(output, run_dir / "fable.md")
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
            "artifacts": {"prompt": "prompt.md", "response": "fable.md"},
        }
    )
    atomic_json(run_dir / "manifest.json", manifest)
    print(f"Counsel: {output}")
    print(
        f"Fable Council mode: {args.mode} | "
        f"access: {'open' if args.open else 'packet'} | "
        f"prompt: {format_int(packet['prompt_tokens'])} tokens"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
