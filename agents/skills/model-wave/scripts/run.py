#!/usr/bin/env python3
"""Run ready prompts concurrently through registered model dispatchers."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


PROVIDERS = frozenset(("claude", "codex", "grok"))
ACCESS_MODES = frozenset(("closed", "agentic"))
ALLOWED_FIELDS = frozenset(
    ("id", "provider", "prompt", "output", "access", "model", "effort", "root")
)
ID_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run explicit model-dispatch lanes concurrently."
    )
    parser.add_argument("manifest", metavar="MANIFEST")
    parser.add_argument("--result", required=True, metavar="PATH")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"model-wave: {message}")


def regular_file(raw: str, label: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        fail(f"{label} must be an absolute path: {raw}")
    if path.is_symlink():
        fail(f"{label} must not be a symlink: {raw}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        fail(f"cannot read {label} {raw}: {exc}")
    if not resolved.is_file():
        fail(f"{label} is not a regular file: {raw}")
    if b"\0" in resolved.read_bytes()[:4096]:
        fail(f"{label} is binary: {raw}")
    return resolved


def absolute_output(raw: str, label: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        fail(f"{label} must be an absolute path: {raw}")
    if path.is_symlink():
        fail(f"{label} must not be a symlink: {raw}")
    resolved = path.resolve()
    if resolved.exists() and not resolved.is_file():
        fail(f"{label} is not a regular file path: {raw}")
    return resolved


def skills_root() -> Path:
    override = os.environ.get("MODEL_WAVE_SKILLS_ROOT")
    if override:
        return Path(override).expanduser().resolve()
    return Path(__file__).resolve().parents[2]


def load_runs(manifest_path: Path, result_path: Path) -> list[dict[str, Any]]:
    try:
        data = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"manifest is not valid JSON: {exc}")
    if not isinstance(data, dict) or set(data) != {"runs"}:
        fail("manifest must contain only a runs array")
    if not isinstance(data["runs"], list) or not data["runs"]:
        fail("runs must be a nonempty array")

    prepared: list[dict[str, Any]] = []
    ids: set[str] = set()
    outputs: set[Path] = set()
    inputs: set[Path] = {manifest_path}
    for index, raw in enumerate(data["runs"]):
        label = f"runs[{index}]"
        if not isinstance(raw, dict):
            fail(f"{label} must be an object")
        unknown = set(raw) - ALLOWED_FIELDS
        if unknown:
            fail(f"{label} has unknown fields: {', '.join(sorted(unknown))}")
        for required in ("id", "provider", "prompt", "output"):
            if not isinstance(raw.get(required), str) or not raw[required]:
                fail(f"{label}.{required} must be a nonempty string")
        lane_id = raw["id"]
        if not ID_PATTERN.fullmatch(lane_id):
            fail(f"{label}.id is not a safe lane id: {lane_id}")
        if lane_id in ids:
            fail(f"duplicate lane id: {lane_id}")
        ids.add(lane_id)
        provider = raw["provider"]
        if provider not in PROVIDERS:
            fail(f"{label}.provider is not registered: {provider}")
        access = raw.get("access", "closed")
        if access not in ACCESS_MODES:
            fail(f"{label}.access must be closed or agentic")
        prompt = regular_file(raw["prompt"], f"{label}.prompt")
        inputs.add(prompt)
        output = absolute_output(raw["output"], f"{label}.output")
        if output in outputs:
            fail(f"duplicate output path: {output}")
        outputs.add(output)
        root: Path | None = None
        if "root" in raw:
            if not isinstance(raw["root"], str) or not Path(raw["root"]).is_absolute():
                fail(f"{label}.root must be an absolute directory")
            root = Path(raw["root"]).resolve()
            if not root.is_dir():
                fail(f"{label}.root is not a directory: {root}")
        if access == "agentic" and root is None:
            fail(f"{label}.root is required for agentic access")
        for optional in ("model", "effort"):
            if optional in raw and (
                not isinstance(raw[optional], str) or not raw[optional]
            ):
                fail(f"{label}.{optional} must be a nonempty string")
        script = skills_root() / f"{provider}-dispatch/scripts/invoke.py"
        if not script.is_file():
            fail(f"registered dispatcher is missing: {script}")
        command = [
            sys.executable,
            str(script),
            str(prompt),
            "--output",
            str(output),
            "--access",
            access,
        ]
        for optional in ("model", "effort"):
            if optional in raw:
                command.extend((f"--{optional}", raw[optional]))
        if root is not None:
            command.extend(("--root", str(root)))
        prepared.append(
            {
                "id": lane_id,
                "provider": provider,
                "prompt": prompt,
                "output": output,
                "log": Path(f"{output}.log"),
                "command": command,
            }
        )
    logs = {lane["log"] for lane in prepared}
    artifacts = outputs | logs | {result_path}
    if len(artifacts) != len(outputs) + len(logs) + 1:
        fail("lane outputs, logs, and the wave result must be distinct")
    if artifacts & inputs:
        fail("outputs, logs, and the wave result must not overwrite inputs")
    return prepared


def atomic_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
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


def run_wave(runs: list[dict[str, Any]], result_path: Path) -> int:
    processes: list[tuple[dict[str, Any], subprocess.Popen[bytes], Any]] = []
    try:
        for lane in runs:
            lane["log"].parent.mkdir(parents=True, exist_ok=True)
            log_handle = lane["log"].open("wb")
            try:
                process = subprocess.Popen(
                    lane["command"], stdout=log_handle, stderr=subprocess.STDOUT
                )
            except BaseException:
                log_handle.close()
                raise
            processes.append((lane, process, log_handle))
    except BaseException:
        for _, process, log_handle in processes:
            process.terminate()
            process.wait()
            log_handle.close()
        raise

    results: list[dict[str, Any]] = []
    for lane, process, log_handle in processes:
        return_code = process.wait()
        log_handle.close()
        output = lane["output"]
        completed = return_code == 0 and output.is_file() and output.stat().st_size > 0
        results.append(
            {
                "id": lane["id"],
                "provider": lane["provider"],
                "status": "completed" if completed else "failed",
                "return_code": return_code,
                "output": str(output),
                "log": str(lane["log"]),
            }
        )
    completed_count = sum(item["status"] == "completed" for item in results)
    status = (
        "completed"
        if completed_count == len(results)
        else "partial"
        if completed_count
        else "failed"
    )
    atomic_json(result_path, {"status": status, "runs": results})
    return 0 if completed_count else 1


def main() -> int:
    args = parse_args()
    manifest = regular_file(args.manifest, "manifest")
    result = absolute_output(args.result, "result")
    runs = load_runs(manifest, result)
    if args.dry_run:
        for lane in runs:
            print(f"{lane['id']}: {shlex.join(lane['command'])}")
        print("Dry run: no model invoked")
        return 0
    return run_wave(runs, result)


if __name__ == "__main__":
    raise SystemExit(main())
