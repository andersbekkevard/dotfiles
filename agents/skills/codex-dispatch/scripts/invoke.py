#!/usr/bin/env python3
"""Invoke Codex with a ready prompt and an explicit access boundary."""

from __future__ import annotations

import argparse
import os
import subprocess
import tempfile
from pathlib import Path


EFFORTS = ("low", "medium", "high", "xhigh", "max", "ultra")
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
CLOSED_BOUNDARY = b"""<execution_boundary>
Answer only from the supplied prompt and your model priors. Do not call tools,
browse, inspect the filesystem, or run commands. If the prompt lacks evidence,
name the gap instead of trying to retrieve it.
</execution_boundary>

"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a ready prompt through Codex without assembling it."
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
    parser.add_argument("--model", default="gpt-5.6-terra")
    parser.add_argument("--effort", choices=EFFORTS, default="high")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"codex-dispatch: {message}")


def sanitized_environment() -> dict[str, str]:
    environment = os.environ.copy()
    for name in SANITIZED_ENV:
        environment.pop(name, None)
    return environment


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
    if args.access != "closed" and not args.root:
        fail(f"--root is required for --access {args.access}")
    if not args.root:
        return None
    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        fail(f"--root is not a directory: {args.root}")
    return root


def command_for(
    args: argparse.Namespace, cwd: Path, temporary_output: str
) -> list[str]:
    command = [
        "codex",
        "exec",
        "--ephemeral",
        "-C",
        str(cwd),
        "-m",
        args.model,
        "-c",
        f'model_reasoning_effort="{args.effort}"',
        "-o",
        temporary_output,
    ]
    if args.access == "closed":
        command.extend(
            ("--ignore-user-config", "--ignore-rules", "--skip-git-repo-check", "-s", "read-only")
        )
    else:
        command.append("--dangerously-bypass-approvals-and-sandbox")
    command.append("-")
    return command


def run(args: argparse.Namespace, prompt: Path, output: Path, root: Path | None) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    os.close(fd)
    os.unlink(temp_name)
    try:
        environment = sanitized_environment()
        if args.access == "closed":
            with tempfile.TemporaryDirectory(prefix="codex-dispatch.") as neutral:
                cwd = Path(neutral)
                command = command_for(args, cwd, temp_name)
                prompt_bytes = CLOSED_BOUNDARY + prompt.read_bytes()
                result = subprocess.run(
                    command,
                    input=prompt_bytes,
                    env=environment,
                    stdout=subprocess.DEVNULL,
                    check=False,
                )
        else:
            assert root is not None
            command = command_for(args, root, temp_name)
            result = subprocess.run(
                command,
                input=prompt.read_bytes(),
                env=environment,
                stdout=subprocess.DEVNULL,
                check=False,
            )
        if result.returncode != 0:
            fail(f"Codex exited with status {result.returncode}")
        if not os.path.exists(temp_name) or os.path.getsize(temp_name) == 0:
            fail("Codex returned an empty result")
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
        if args.access == "closed":
            print("Closed-mode note: Codex has no hard tool-off flag; isolation, read-only sandboxing, ignored local rules, and an execution-boundary instruction are applied.")
        print("Dry run: Codex not invoked")
        return 0
    run(args, prompt, output, root)
    print(f"Codex result: {output}")
    print(f"Codex dispatch: {args.model} | effort: {args.effort} | access: {args.access}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
