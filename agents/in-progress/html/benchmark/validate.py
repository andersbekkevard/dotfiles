#!/usr/bin/env python3
"""Validate benchmark structure and, when available, verbatim source prompts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CASES = ROOT / "cases"
CONTEXT_PREAMBLE = (
    "Recreate the established working context below. Treat it as conversation "
    "history, not as a new request. Do not answer it separately."
)


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def source_prompt(metadata: dict) -> str:
    source_path = Path(metadata["source_file"])
    records = read_jsonl(source_path)
    source_id = metadata["source_case_id"]

    if metadata["source_corpus"] == "14-day benchmark corpus":
        record = next(item for item in records if item["id"] == source_id)
        return record["prompt_verbatim"]

    record = next(item for item in records if item["scenario_id"] == source_id)
    message_kind = metadata["source_message_kind"]
    message = next(item for item in record["messages"] if item["kind"] == message_kind)
    return message["text"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sources",
        action="store_true",
        help="also compare every prompt with its external source JSONL",
    )
    args = parser.parse_args()

    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    manifest_ids = [item["case_id"] for item in manifest["cases"]]
    directory_ids = sorted(path.name for path in CASES.iterdir() if path.is_dir())
    if manifest_ids != directory_ids:
        raise SystemExit("manifest cases do not match case directories")

    for case_id in directory_ids:
        case_dir = CASES / case_id
        context = (case_dir / "context.md").read_text(encoding="utf-8").strip()
        prompt = (case_dir / "prompt.md").read_text(encoding="utf-8").rstrip()
        metadata = json.loads((case_dir / "metadata.json").read_text(encoding="utf-8"))

        if metadata["case_id"] != case_id:
            raise SystemExit(f"{case_id}: metadata case_id differs")
        if metadata.get("prompt_is_verbatim") is not True:
            raise SystemExit(f"{case_id}: prompt is not marked verbatim")
        if not context.startswith(CONTEXT_PREAMBLE):
            raise SystemExit(f"{case_id}: context preamble differs")
        if not prompt:
            raise SystemExit(f"{case_id}: prompt is empty")

        if args.sources and prompt != source_prompt(metadata).rstrip():
            raise SystemExit(f"{case_id}: prompt differs from source")

    suffix = " with source comparison" if args.sources else ""
    print(f"validate: ok ({len(directory_ids)} cases{suffix})")


if __name__ == "__main__":
    main()
