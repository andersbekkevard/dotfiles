#!/usr/bin/env python3
"""Invoke Claude Code with a ready prompt and an explicit access boundary."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


_AGENTS_LIB = Path(__file__).resolve().parents[3] / "lib"
if str(_AGENTS_LIB) not in sys.path:
    sys.path.insert(0, str(_AGENTS_LIB))
import agent_dispatch_state as dispatch_state


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


def command_for(args: argparse.Namespace, session_id: str) -> list[str]:
    command = [
        "claude",
        "--safe-mode",
        "--strict-mcp-config",
        "--disallowedTools",
        "mcp__*",
        "--tools",
        "" if args.access == "closed" else "default",
        "--session-id",
        session_id,
    ]
    if args.access == "agentic":
        command.append("--dangerously-skip-permissions")
    command.extend(
        (
            "--print",
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
    if args.dry_run:
        print(f"Access: {args.access}")
        print(f"Working root: {root if root is not None else 'isolated temporary directory'}")
        print(f"Model: {args.model}")
        print(f"Effort: {args.effort}")
        print(f"Transcript root: {dispatch_state.dispatch_root() / 'claude'}")
        print("Dry run: Claude not invoked")
        return 0

    try:
        claude_home = dispatch_state.prepare_claude_home()
    except OSError as exc:
        fail(f"cannot create isolated Claude home: {exc}")
    session_id = dispatch_state.new_session_id()
    command = command_for(args, session_id)
    environment = sanitized_environment()
    environment["CLAUDE_CONFIG_DIR"] = str(claude_home)

    if args.access == "closed":
        with tempfile.TemporaryDirectory(prefix="claude-dispatch.") as neutral:
            cwd = Path(neutral)
            verify_subscription(environment, cwd)
            invoke(command, prompt, output, environment, cwd)
    else:
        assert root is not None
        verify_subscription(environment, root)
        invoke(command, prompt, output, environment, root)
    try:
        transcript = dispatch_state.resolve_claude_transcript(claude_home, session_id)
    except FileNotFoundError as exc:
        fail(str(exc))
    print(f"Claude result: {output}")
    print(f"{dispatch_state.TRANSCRIPT_PREFIX}{transcript}")
    print(f"Claude dispatch: {args.model} | effort: {args.effort} | access: {args.access}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
