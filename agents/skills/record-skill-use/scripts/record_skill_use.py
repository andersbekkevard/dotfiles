#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SCHEMA_VERSION = 1
SKILL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{6}Z$")


class PacketError(ValueError):
    pass


def default_evidence_root() -> Path:
    skill_dir = Path(__file__).resolve().parent.parent
    agents_dir = skill_dir.parent.parent
    return agents_dir / "skill-uses"


def validate_skill_name(value: str) -> str:
    if not SKILL_NAME.fullmatch(value):
        raise argparse.ArgumentTypeError(
            "skill names must use lowercase letters, digits, and single hyphens"
        )
    return value


def parse_timestamp(value: str) -> tuple[str, str]:
    if not TIMESTAMP.fullmatch(value):
        raise PacketError("timestamp must use YYYY-MM-DDTHHMMSSZ in UTC")
    try:
        parsed = datetime.strptime(value, "%Y-%m-%dT%H%M%SZ").replace(
            tzinfo=timezone.utc
        )
    except ValueError as exc:
        raise PacketError(f"invalid timestamp: {value}") from exc
    return value, parsed.isoformat().replace("+00:00", "Z")


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_input(path_text: str, label: str) -> Path:
    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        raise PacketError(f"{label} is not a file: {path}")
    return path


def file_record(path: Path, role: str) -> dict[str, object]:
    return {
        "path": path.name,
        "role": role,
        "sha256": hash_file(path),
        "bytes": path.stat().st_size,
    }


def validate_packet(packet: Path) -> None:
    packet = packet.resolve()
    metadata_path = packet / "metadata.json"
    evidence_path = packet / "evidence.md"
    if not metadata_path.is_file():
        raise PacketError(f"missing metadata.json: {packet}")
    if not evidence_path.is_file() or evidence_path.stat().st_size == 0:
        raise PacketError(f"missing or empty evidence.md: {packet}")

    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PacketError(f"invalid metadata.json: {exc}") from exc

    if metadata.get("schema_version") != SCHEMA_VERSION:
        raise PacketError("unsupported metadata schema_version")
    skill = metadata.get("skill")
    if not isinstance(skill, str) or not SKILL_NAME.fullmatch(skill):
        raise PacketError("metadata skill is invalid")
    if packet.parent.name != skill:
        raise PacketError("packet parent does not match metadata skill")

    directory_timestamp, captured_at = parse_timestamp(packet.name)
    if directory_timestamp != packet.name or metadata.get("captured_at") != captured_at:
        raise PacketError("packet timestamp does not match metadata captured_at")
    if not isinstance(metadata.get("feedback_provided"), bool):
        raise PacketError("feedback_provided must be a boolean")
    for field in ("harness", "model", "session_id", "source_transcript"):
        value = metadata.get(field)
        if value is not None and not isinstance(value, str):
            raise PacketError(f"{field} must be a string or null")

    related = metadata.get("related_skills")
    if not isinstance(related, list) or any(
        not isinstance(item, str) or not SKILL_NAME.fullmatch(item) for item in related
    ):
        raise PacketError("related_skills must be a list of skill names")
    if skill in related or len(related) != len(set(related)):
        raise PacketError("related_skills must be unique and exclude the primary skill")

    files = metadata.get("files")
    if not isinstance(files, list) or not files:
        raise PacketError("metadata files must be a non-empty list")
    expected_names = {"metadata.json"}
    evidence_records = 0
    for record in files:
        if not isinstance(record, dict):
            raise PacketError("each file record must be an object")
        name = record.get("path")
        if (
            not isinstance(name, str)
            or Path(name).name != name
            or name in {"", ".", "..", "metadata.json"}
        ):
            raise PacketError(f"invalid packet file path: {name!r}")
        if name in expected_names:
            raise PacketError(f"duplicate packet file path: {name}")
        expected_names.add(name)
        path = packet / name
        if not path.is_file():
            raise PacketError(f"missing packet file: {name}")
        if record.get("bytes") != path.stat().st_size:
            raise PacketError(f"size mismatch: {name}")
        if record.get("sha256") != hash_file(path):
            raise PacketError(f"hash mismatch: {name}")
        role = record.get("role")
        if role not in {"evidence", "artifact"}:
            raise PacketError(f"invalid file role for {name}: {role!r}")
        if role == "evidence":
            evidence_records += 1
            if name != "evidence.md":
                raise PacketError("the evidence record must point to evidence.md")

    entries = list(packet.iterdir())
    non_files = sorted(path.name for path in entries if not path.is_file())
    if non_files:
        raise PacketError(f"packet must be flat files; found={non_files}")
    actual_names = {path.name for path in entries}
    if actual_names != expected_names:
        extra = sorted(actual_names - expected_names)
        missing = sorted(expected_names - actual_names)
        raise PacketError(f"packet file set mismatch; extra={extra}, missing={missing}")
    if evidence_records != 1:
        raise PacketError("packet must contain exactly one evidence record")


def create_packet(args: argparse.Namespace) -> Path:
    root = (
        Path(args.root).expanduser().resolve()
        if args.root
        else default_evidence_root().resolve()
    )
    timestamp_text = args.timestamp or datetime.now(timezone.utc).strftime(
        "%Y-%m-%dT%H%M%SZ"
    )
    timestamp, captured_at = parse_timestamp(timestamp_text)
    evidence_source = resolve_input(args.evidence, "evidence")
    if evidence_source.stat().st_size == 0:
        raise PacketError(f"evidence is empty: {evidence_source}")

    artifact_sources = [resolve_input(item, "artifact") for item in args.artifact]
    destination_names = ["evidence.md", *(path.name for path in artifact_sources)]
    if len(destination_names) != len(set(destination_names)):
        raise PacketError("packet inputs must have unique destination filenames")
    if "metadata.json" in destination_names:
        raise PacketError("metadata.json is reserved")

    related_skills = list(dict.fromkeys(args.related_skill))
    if args.skill in related_skills:
        raise PacketError("the primary skill cannot also be a related skill")

    skill_root = root / args.skill
    packet = skill_root / timestamp
    if packet.exists():
        raise PacketError(f"packet already exists: {packet}")
    skill_root.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{timestamp}.", dir=skill_root))

    try:
        evidence_destination = temporary / "evidence.md"
        shutil.copy2(evidence_source, evidence_destination)
        records = [file_record(evidence_destination, "evidence")]
        for source in artifact_sources:
            destination = temporary / source.name
            shutil.copy2(source, destination)
            records.append(file_record(destination, "artifact"))

        metadata = {
            "schema_version": SCHEMA_VERSION,
            "skill": args.skill,
            "related_skills": related_skills,
            "captured_at": captured_at,
            "harness": args.harness,
            "model": args.model,
            "session_id": args.session_id,
            "source_transcript": args.source_transcript,
            "feedback_provided": args.feedback_provided,
            "files": records,
        }
        (temporary / "metadata.json").write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        temporary.rename(packet)
        validate_packet(packet)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        if packet.exists():
            shutil.rmtree(packet)
        if skill_root.exists() and not any(skill_root.iterdir()):
            skill_root.rmdir()
        raise
    return packet


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create and validate durable skill-use evidence packets."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    create = subparsers.add_parser("create", help="create one evidence packet")
    create.add_argument("--skill", required=True, type=validate_skill_name)
    create.add_argument("--evidence", required=True)
    create.add_argument("--artifact", action="append", default=[])
    create.add_argument(
        "--related-skill", action="append", default=[], type=validate_skill_name
    )
    create.add_argument("--harness")
    create.add_argument("--model")
    create.add_argument("--session-id")
    create.add_argument("--source-transcript")
    create.add_argument("--feedback-provided", action="store_true")
    create.add_argument("--timestamp", help="UTC timestamp: YYYY-MM-DDTHHMMSSZ")
    create.add_argument("--root", help=argparse.SUPPRESS)

    validate = subparsers.add_parser("validate", help="validate one evidence packet")
    validate.add_argument("packet")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        if args.command == "create":
            packet = create_packet(args)
            print(packet.resolve())
        else:
            packet = Path(args.packet).expanduser().resolve()
            validate_packet(packet)
            print(f"valid: {packet}")
    except (OSError, PacketError) as exc:
        print(f"record-skill-use: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
