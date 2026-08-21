#!/usr/bin/env python3
"""Deterministically audit or archive old Codex JSONL sessions.

Archive creation is additive: source sessions are never edited or removed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
import shutil
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any

MIN_RETENTION_DAYS = 7


class SessionError(RuntimeError):
    pass


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def parse_time(value: str | None) -> dt.datetime | None:
    if not value or not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def cutoff_for(
    retention_days: int,
    *,
    now: dt.datetime | None = None,
    cutoff_at: dt.datetime | None = None,
) -> dt.datetime:
    if retention_days < MIN_RETENTION_DAYS:
        raise SessionError(
            f"retention_days must be at least {MIN_RETENTION_DAYS}, got {retention_days}"
        )
    current = (now or utc_now()).astimezone(dt.timezone.utc)
    maximum = current - dt.timedelta(days=MIN_RETENTION_DAYS)
    if cutoff_at is not None:
        chosen = cutoff_at.astimezone(dt.timezone.utc)
        if chosen > maximum:
            raise SessionError(
                f"cutoff {iso(chosen)} is newer than the seven-day safety boundary {iso(maximum)}"
            )
        return chosen
    return current - dt.timedelta(days=retention_days)


def record_category(record: dict[str, Any]) -> str:
    top = str(record.get("type", "unknown"))
    payload = record.get("payload")
    if not isinstance(payload, dict):
        return top
    subtype = str(payload.get("type", ""))
    role = str(payload.get("role", ""))
    return "/".join(part for part in (top, subtype, role) if part)


def retain_record(record: dict[str, Any]) -> bool:
    top = record.get("type")
    if top == "session_meta" or top == "inter_agent_communication_metadata":
        return True
    payload = record.get("payload")
    if not isinstance(payload, dict):
        return False
    subtype = payload.get("type")
    role = payload.get("role")
    if top == "response_item":
        if subtype == "message" and role in {"user", "assistant"}:
            return True
        if subtype == "agent_message":
            return True
        # Preserve schema-drifted user/assistant records conservatively.
        if role in {"user", "assistant"} and "message" in str(subtype):
            return True
    if top == "event_msg" and subtype in {"user_message", "agent_message"}:
        return True
    return False


def iter_session_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    if not root.is_dir() or root.is_symlink():
        raise SessionError(f"sessions root must be a real directory: {root}")
    return sorted(
        path for path in root.rglob("*.jsonl") if path.is_file() and not path.is_symlink()
    )


def inspect_session(path: Path, root: Path, cutoff: dt.datetime) -> dict[str, Any]:
    before = path.stat()
    source_hash = hashlib.sha256()
    retained_hash = hashlib.sha256()
    source_bytes = 0
    retained_bytes = 0
    line_count = 0
    retained_lines = 0
    invalid_lines = 0
    counts: Counter[str] = Counter()
    latest = dt.datetime.fromtimestamp(before.st_mtime, tz=dt.timezone.utc)

    with path.open("rb") as handle:
        for raw in handle:
            line_count += 1
            source_bytes += len(raw)
            source_hash.update(raw)
            keep = False
            try:
                record = json.loads(raw)
            except (json.JSONDecodeError, UnicodeDecodeError):
                invalid_lines += 1
                counts["invalid"] += 1
                keep = True
            else:
                counts[record_category(record)] += 1
                timestamp = parse_time(record.get("timestamp"))
                if timestamp is not None and timestamp > latest:
                    latest = timestamp
                keep = retain_record(record)
            if keep:
                retained_lines += 1
                retained_bytes += len(raw)
                retained_hash.update(raw)

    after = path.stat()
    changed = (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns)
    eligible = not changed and latest < cutoff
    return {
        "path": str(path),
        "relative_path": str(path.relative_to(root)),
        "source_bytes": source_bytes,
        "retained_bytes": retained_bytes,
        "reclaimable_bytes": source_bytes - retained_bytes if eligible else 0,
        "line_count": line_count,
        "retained_lines": retained_lines,
        "invalid_lines": invalid_lines,
        "latest_at": iso(latest),
        "eligible": eligible,
        "blocked_reason": "changed_during_scan" if changed else None,
        "source_sha256": source_hash.hexdigest(),
        "retained_sha256": retained_hash.hexdigest(),
        "record_counts": dict(sorted(counts.items())),
    }


def audit_sessions(
    sessions_root: Path,
    *,
    retention_days: int = MIN_RETENTION_DAYS,
    now: dt.datetime | None = None,
    cutoff_at: dt.datetime | None = None,
    include_sessions: bool = False,
) -> dict[str, Any]:
    root = sessions_root.expanduser().resolve()
    cutoff = cutoff_for(retention_days, now=now, cutoff_at=cutoff_at)
    sessions = [inspect_session(path, root, cutoff) for path in iter_session_files(root)]
    eligible = [item for item in sessions if item["eligible"]]
    source_bytes = sum(item["source_bytes"] for item in eligible)
    retained_bytes = sum(item["retained_bytes"] for item in eligible)
    result: dict[str, Any] = {
        "schema_version": 1,
        "sessions_root": str(root),
        "retention_days": retention_days,
        "cutoff_at": iso(cutoff),
        "session_count": len(sessions),
        "eligible_session_count": len(eligible),
        "ineligible_session_count": len(sessions) - len(eligible),
        "eligible_source_bytes": source_bytes,
        "eligible_archive_raw_bytes": retained_bytes,
        "reclaimable_bytes": source_bytes - retained_bytes,
        "invalid_lines_retained": sum(item["invalid_lines"] for item in eligible),
        "changed_during_scan": sum(
            item["blocked_reason"] == "changed_during_scan" for item in sessions
        ),
    }
    if include_sessions:
        result["sessions"] = sessions
    return result


def copy_retained(source: Path, destination: Path) -> tuple[int, str]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    retained_hash = hashlib.sha256()
    retained_bytes = 0
    with source.open("rb") as input_handle, destination.open("wb") as output_handle:
        with gzip.GzipFile(fileobj=output_handle, mode="wb", filename="", mtime=0) as zipped:
            for raw in input_handle:
                try:
                    record = json.loads(raw)
                except (json.JSONDecodeError, UnicodeDecodeError):
                    keep = True
                else:
                    keep = retain_record(record)
                if keep:
                    zipped.write(raw)
                    retained_hash.update(raw)
                    retained_bytes += len(raw)
    return retained_bytes, retained_hash.hexdigest()


def archive_sessions(
    sessions_root: Path,
    output: Path,
    *,
    retention_days: int = MIN_RETENTION_DAYS,
    cutoff_at: dt.datetime | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    root = sessions_root.expanduser().resolve()
    destination = output.expanduser().resolve()
    if is_relative_to(destination, root) or is_relative_to(root, destination):
        raise SessionError("archive destination and sessions root must not contain each other")
    if destination.exists() or destination.is_symlink():
        raise SessionError(f"archive destination already exists: {destination}")
    audit = audit_sessions(
        root,
        retention_days=retention_days,
        now=now,
        cutoff_at=cutoff_at,
        include_sessions=True,
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=f".{destination.name}.", dir=destination.parent))
    entries: list[dict[str, Any]] = []
    try:
        for item in audit["sessions"]:
            if not item["eligible"]:
                continue
            source = Path(item["path"])
            relative = Path(item["relative_path"] + ".gz")
            archived = temporary / "sessions" / relative
            retained_bytes, retained_sha = copy_retained(source, archived)
            after = inspect_session(
                source,
                root,
                parse_time(audit["cutoff_at"]) or utc_now(),
            )
            if after["source_sha256"] != item["source_sha256"]:
                raise SessionError(f"source changed while archiving: {source}")
            if retained_bytes != item["retained_bytes"] or retained_sha != item["retained_sha256"]:
                raise SessionError(f"archive verification failed: {source}")
            entries.append(
                {
                    **item,
                    "archive_path": str(Path("sessions") / relative),
                    "archive_compressed_bytes": archived.stat().st_size,
                }
            )

        manifest = {
            key: value for key, value in audit.items() if key != "sessions"
        }
        manifest.update(
            {
                "created_at": iso(utc_now()),
                "source_sessions_deleted": False,
                "entries": entries,
                "archive_compressed_bytes": sum(
                    item["archive_compressed_bytes"] for item in entries
                ),
            }
        )
        manifest_path = temporary / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        os.replace(temporary, destination)
        return manifest
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def human_bytes(value: int) -> str:
    size = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if size < 1024 or unit == "TiB":
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TiB"


def print_audit(result: dict[str, Any]) -> None:
    print(f"Codex sessions: {result['sessions_root']}")
    print(f"Cutoff: {result['cutoff_at']} ({result['retention_days']} days)")
    print(
        f"Eligible: {result['eligible_session_count']}/{result['session_count']} sessions; "
        f"source {human_bytes(result['eligible_source_bytes'])}; "
        f"archive {human_bytes(result['eligible_archive_raw_bytes'])}; "
        f"reclaim {human_bytes(result['reclaimable_bytes'])}"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("audit", "archive"):
        command = sub.add_parser(name)
        command.add_argument("--sessions-root", type=Path, required=True)
        command.add_argument("--retention-days", type=int, default=MIN_RETENTION_DAYS)
        command.add_argument("--cutoff-at", type=str)
        command.add_argument("--json", action="store_true")
        if name == "audit":
            command.add_argument("--details", action="store_true")
        else:
            command.add_argument("--output", type=Path, required=True)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    cutoff = parse_time(args.cutoff_at) if args.cutoff_at else None
    if args.cutoff_at and cutoff is None:
        raise SystemExit(f"invalid --cutoff-at: {args.cutoff_at}")
    try:
        if args.command == "audit":
            result = audit_sessions(
                args.sessions_root,
                retention_days=args.retention_days,
                cutoff_at=cutoff,
                include_sessions=args.details,
            )
        else:
            result = archive_sessions(
                args.sessions_root,
                args.output,
                retention_days=args.retention_days,
                cutoff_at=cutoff,
            )
    except SessionError as exc:
        raise SystemExit(f"codex_sessions: {exc}") from exc
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    elif args.command == "audit":
        print_audit(result)
    else:
        print(
            f"Archived {result['eligible_session_count']} sessions to {args.output}; "
            "source sessions retained"
        )


if __name__ == "__main__":
    main()
