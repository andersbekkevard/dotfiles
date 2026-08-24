# /// script
# dependencies = ["requests>=2.32.0"]
# ///

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import requests


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transcribe audio with Groq.")
    parser.add_argument("audio", type=Path, help="Audio or video file to transcribe.")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("transcript.json"),
        help="Where to write Groq's JSON response.",
    )
    parser.add_argument(
        "--model",
        default="whisper-large-v3",
        help="Groq transcription model.",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="Optional ISO language code, for example no or en.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        raise SystemExit("GROQ_API_KEY is not set")
    if not args.audio.is_file():
        raise SystemExit(f"Audio file does not exist: {args.audio}")

    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.audio.open("rb") as audio_handle:
        response = requests.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": (args.audio.name, audio_handle)},
            data={
                "model": args.model,
                "response_format": "verbose_json",
                **({"language": args.language} if args.language else {}),
            },
            timeout=120,
        )

    if response.status_code >= 400:
        raise SystemExit(f"Groq returned {response.status_code}: {response.text}")

    payload = response.json()
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(payload.get("text", ""))


if __name__ == "__main__":
    main()
