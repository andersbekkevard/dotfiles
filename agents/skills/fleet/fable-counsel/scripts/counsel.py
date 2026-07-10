#!/usr/bin/env python3
# /// script
# dependencies = ["tiktoken>=0.7.0"]
# ///
"""Compose and run an isolated Fable counsel consultation."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        usage="%(prog)s WORK_DIR [options]",
        description=(
            "WORK_DIR: brief.md; optional user-intent.md and user-anchors.md; "
            "writes prompt.md and fable.md. Evidence flags repeat."
        ),
        add_help=False,
    )
    parser.add_argument("-h", "--help", action="help", help="Show help.")
    parser.add_argument(
        "work_dir",
        metavar="WORK_DIR",
        help="Counsel work directory.",
    )
    parser.add_argument(
        "--root", default=".", metavar="DIR", help="Repository root (cwd)."
    )
    parser.add_argument(
        "--mode",
        choices=MODES,
        required=True,
        help="Counsel mode.",
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
        help="low|medium|high|xhigh|max (high).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Write prompt.md without Claude.",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"counsel: {message}")


def sanitized_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name in SANITIZED_ENV:
        environment.pop(name, None)
    return environment


def compose(args: argparse.Namespace, work_dir: Path, prompt: Path) -> None:
    script = Path(__file__).with_name("compose_packet.py")
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
    ]
    intent = work_dir / "user-intent.md"
    anchors = work_dir / "user-anchors.md"
    if intent.exists():
        command.extend(("--user-intent", str(intent)))
    if anchors.exists():
        command.extend(("--user-anchors", str(anchors)))
    for flag, values in (
        ("--document", args.doc),
        ("--excerpt", args.excerpt),
        ("--redacted-document", args.redacted),
        ("--digest", args.digest),
    ):
        for value in values:
            command.extend((flag, value))
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


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
) -> None:
    fd, temp_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        with prompt.open("rb") as prompt_handle, os.fdopen(fd, "wb") as output_handle:
            result = subprocess.run(
                [
                    "claude",
                    "--safe-mode",
                    "--strict-mcp-config",
                    "--disallowedTools",
                    "mcp__*",
                    "--tools",
                    "",
                    "--print",
                    "--no-session-persistence",
                    "--output-format",
                    "text",
                    "--model",
                    "claude-fable-5",
                    "--effort",
                    effort,
                ],
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
    compose(args, work_dir, prompt)
    if args.dry_run:
        print("Dry run: Claude not invoked")
        return 0

    environment = sanitized_environment()
    with tempfile.TemporaryDirectory(prefix="fable-counsel-run.") as neutral:
        neutral_dir = Path(neutral)
        verify_subscription(environment, neutral_dir)
        invoke(prompt, output, args.effort, environment, neutral_dir)
    print(f"Counsel: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
