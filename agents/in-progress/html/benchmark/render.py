#!/usr/bin/env python3
"""Render neutral benchmark context plus an exact Anders prompt for one skill."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CASES = ROOT / "cases"


def case_dirs() -> list[Path]:
    return sorted(path for path in CASES.iterdir() if path.is_dir())


def render(case_dir: Path, skill_path: str) -> str:
    context = (case_dir / "context.md").read_text(encoding="utf-8").rstrip()
    prompt = (case_dir / "prompt.md").read_text(encoding="utf-8").rstrip()
    metadata = json.loads((case_dir / "metadata.json").read_text(encoding="utf-8"))
    if not metadata.get("prompt_is_verbatim"):
        raise ValueError(f"{case_dir.name}: prompt is not marked verbatim")
    return f"{context}\n\n{prompt}\n\ncall {skill_path}\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    choice = parser.add_mutually_exclusive_group(required=True)
    choice.add_argument("--case")
    choice.add_argument("--all", action="store_true")
    parser.add_argument("--skill", required=True)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    skill_path = str(Path(args.skill).expanduser().resolve())
    if not Path(skill_path).is_file():
        parser.error(f"skill path is not a file: {skill_path}")

    selected = case_dirs() if args.all else [CASES / args.case]
    for case_dir in selected:
        if not case_dir.is_dir():
            parser.error(f"unknown case: {case_dir.name}")
        output = render(case_dir, skill_path)
        if args.output_dir:
            args.output_dir.mkdir(parents=True, exist_ok=True)
            destination = args.output_dir / f"{case_dir.name}.txt"
            destination.write_text(output, encoding="utf-8")
            print(destination.resolve())
        else:
            if len(selected) > 1:
                print(f"===== {case_dir.name} =====")
            print(output, end="")


if __name__ == "__main__":
    main()
