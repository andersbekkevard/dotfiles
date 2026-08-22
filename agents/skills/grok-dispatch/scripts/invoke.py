#!/usr/bin/env python3
"""Invoke Grok with a ready prompt and an explicit access boundary."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


EFFORTS = ("low", "medium", "high", "xhigh")
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
        description="Run a ready prompt through Grok without assembling it."
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
    parser.add_argument("--model", default="grok-4.6")
    parser.add_argument("--effort", choices=EFFORTS, default="high")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"grok-dispatch: {message}")


def validate_file(raw_path: str) -> Path:
    path = Path(raw_path).expanduser()
    if path.is_symlink():
        fail(f"prompt must not be a symlink: {raw_path}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        fail(f"cannot read prompt {raw_path}: {exc}")
    if not resolved.is_file():
        fail(f"prompt is not a regular file: {raw_path}")
    if b"\0" in resolved.read_bytes()[:4096]:
        fail(f"prompt is binary: {raw_path}")
    return resolved


def validate_root(args: argparse.Namespace) -> Path | None:
    if args.access == "agentic" and not args.root:
        fail("--root is required for --access agentic")
    if not args.root:
        return None
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"--root is not a directory: {args.root}")
    return root


def sanitized_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name in SANITIZED_ENV:
        environment.pop(name, None)
    environment["GROK_DISABLE_API_KEY_AUTH"] = "1"
    return environment


def command_for(args: argparse.Namespace, prompt: Path, cwd: Path) -> list[str]:
    command = [
        "grok",
        "--prompt-file",
        str(prompt),
        "--output-format",
        "plain",
        "--model",
        args.model,
        "--reasoning-effort",
        args.effort,
        "--verbatim",
        "--cwd",
        str(cwd),
    ]
    if args.access == "closed":
        command.extend(("--tools", "", "--no-subagents", "--disable-web-search"))
    else:
        command.extend(("--permission-mode", "bypassPermissions", "--always-approve"))
    return command


def verify_subscription(environment: dict[str, str], cwd: Path) -> None:
    try:
        result = subprocess.run(
            ["grok", "models"],
            cwd=cwd,
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        fail("grok is not available on PATH")
    if result.returncode != 0 or "logged in with grok.com" not in result.stdout.lower():
        fail("Grok must use grok.com authentication")


def seed_closed_home(destination: Path) -> None:
    configured = os.environ.get("GROK_HOME")
    source = Path(configured).expanduser() if configured else Path.home() / ".grok"
    for name in ("auth.json", "agent_id"):
        candidate = source / name
        if candidate.is_file() and not candidate.is_symlink():
            shutil.copyfile(candidate, destination / name)
            (destination / name).chmod(0o600)


def invoke(
    command: list[str], output: Path, environment: dict[str, str], cwd: Path
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        with os.fdopen(fd, "wb") as output_handle:
            result = subprocess.run(
                command,
                cwd=cwd,
                env=environment,
                stdout=output_handle,
                check=False,
            )
        if result.returncode != 0:
            fail(f"Grok exited with status {result.returncode}")
        if os.path.getsize(temp_name) == 0:
            fail("Grok returned an empty result")
        os.replace(temp_name, output)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    args = parse_args()
    prompt = validate_file(args.prompt_file)
    output = Path(args.output).expanduser().resolve()
    root = validate_root(args)
    if args.dry_run:
        print(f"Access: {args.access}")
        print(f"Working root: {root if root is not None else 'isolated temporary directory'}")
        print(f"Model: {args.model}")
        print(f"Effort: {args.effort}")
        print("Dry run: Grok not invoked")
        return 0

    environment = sanitized_environment()
    if args.access == "closed":
        with tempfile.TemporaryDirectory(prefix="grok-dispatch.") as neutral_name:
            neutral = Path(neutral_name)
            home = neutral / "home"
            home.mkdir(mode=0o700)
            seed_closed_home(home)
            environment["GROK_HOME"] = str(home)
            verify_subscription(environment, neutral)
            invoke(command_for(args, prompt, neutral), output, environment, neutral)
    else:
        assert root is not None
        verify_subscription(environment, root)
        invoke(command_for(args, prompt, root), output, environment, root)
    print(f"Grok result: {output}")
    print(f"Grok dispatch: {args.model} | effort: {args.effort} | access: {args.access}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
