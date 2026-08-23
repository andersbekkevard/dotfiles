#!/usr/bin/env python3
"""Mechanically compress native Codex, Claude, Grok, and Cursor transcripts."""

from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
from typing import Any, Iterable


VERSION = 1
PROVIDERS = ("codex", "claude", "grok", "cursor")
MARKER_KEY = "_compressed_agent_transcript"


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def marker(value: Any, kind: str) -> dict[str, Any]:
    encoded = canonical_bytes(value)
    return {
        MARKER_KEY: {
            "kind": kind,
            "encoding": "canonical-json-utf8",
            "bytes": len(encoded),
            "sha256": sha256_bytes(encoded),
        }
    }


def fresh_stats() -> dict[str, int]:
    return {
        "records_read": 0,
        "records_written": 0,
        "records_dropped": 0,
        "records_changed": 0,
        "malformed_records_preserved": 0,
        "tool_result_fields_pruned": 0,
        "tool_result_canonical_bytes_pruned": 0,
        "telemetry_records_dropped": 0,
        "telemetry_fields_pruned": 0,
        "duplicate_compaction_items_pruned": 0,
        "environment_snapshot_fields_pruned": 0,
    }


def merge_stats(target: dict[str, int], source: dict[str, int]) -> None:
    for key, value in source.items():
        target[key] = target.get(key, 0) + value


def prune_field(
    owner: dict[str, Any],
    key: str,
    kind: str,
    stats: dict[str, int],
    *,
    counter: str = "tool_result_fields_pruned",
) -> bool:
    if key not in owner or owner[key] is None:
        return False
    if isinstance(owner[key], dict) and MARKER_KEY in owner[key]:
        return False
    encoded = canonical_bytes(owner[key])
    owner[key] = marker(owner[key], kind)
    stats[counter] += 1
    if counter == "tool_result_fields_pruned":
        stats["tool_result_canonical_bytes_pruned"] += len(encoded)
    return True


def compress_prior_payloads(
    history: list[Any],
    prior_payload_hashes: set[str],
    stats: dict[str, int],
) -> tuple[list[Any], bool]:
    output: list[Any] = []
    run: list[str] = []
    changed = False

    def flush() -> None:
        nonlocal run
        if not run:
            return
        output.append(
            {
                MARKER_KEY: {
                    "kind": "prior-payload-sequence",
                    "count": len(run),
                    "sha256": sha256_bytes(canonical_bytes(run)),
                }
            }
        )
        stats["duplicate_compaction_items_pruned"] += len(run)
        run = []

    for item in history:
        digest = sha256_bytes(canonical_bytes(item))
        if digest in prior_payload_hashes:
            run.append(digest)
            changed = True
            continue
        flush()
        output.append(item)
    flush()
    return output, changed


def transform_codex(
    record: dict[str, Any],
    stats: dict[str, int],
    context: dict[str, Any],
) -> tuple[dict[str, Any] | None, bool]:
    original_payload = copy.deepcopy(record.get("payload"))
    record_type = record.get("type")
    payload = record.get("payload") if isinstance(record.get("payload"), dict) else None

    if record_type == "world_state":
        stats["telemetry_records_dropped"] += 1
        return None, True
    if record_type == "event_msg" and payload and payload.get("type") == "token_count":
        stats["telemetry_records_dropped"] += 1
        return None, True

    changed = False
    if record_type == "response_item" and payload:
        if payload.get("type") in {"function_call_output", "custom_tool_call_output"}:
            changed |= prune_field(payload, "output", "tool-result", stats)

    if record_type == "event_msg" and payload:
        event_type = payload.get("type")
        if event_type == "mcp_tool_call_end":
            changed |= prune_field(payload, "result", "mcp-tool-result", stats)
        elif event_type == "patch_apply_end":
            for key in ("changes", "stdout", "stderr"):
                changed |= prune_field(payload, key, "patch-result", stats)
        elif event_type == "web_search_end":
            changed |= prune_field(payload, "results", "web-search-result", stats)
        elif event_type == "item_completed" and isinstance(payload.get("item"), dict):
            item = payload["item"]
            for key in ("aggregated_output", "output", "content_items"):
                changed |= prune_field(item, key, "completed-item-result", stats)

    if record_type == "compacted" and payload:
        history = payload.get("replacement_history")
        if isinstance(history, list):
            compacted, did_change = compress_prior_payloads(
                history,
                context["prior_payload_hashes"],
                stats,
            )
            if did_change:
                payload["replacement_history"] = compacted
                changed = True

    if original_payload is not None:
        context["prior_payload_hashes"].add(sha256_bytes(canonical_bytes(original_payload)))
    return record, changed


def blocks(record: dict[str, Any]) -> list[Any] | None:
    message = record.get("message")
    if isinstance(message, dict) and isinstance(message.get("content"), list):
        return message["content"]
    if isinstance(record.get("content"), list):
        return record["content"]
    return None


def transform_claude(
    record: dict[str, Any],
    stats: dict[str, int],
    _context: dict[str, Any],
) -> tuple[dict[str, Any], bool]:
    changed = False
    message = record.get("message")
    if isinstance(message, dict) and "usage" in message:
        message.pop("usage")
        stats["telemetry_fields_pruned"] += 1
        changed = True
    if "toolUseResult" in record:
        changed |= prune_field(record, "toolUseResult", "claude-tool-result-detail", stats)
    content = blocks(record)
    if content is not None:
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_result":
                continue
            changed |= prune_field(block, "content", "tool-result", stats)
    return record, changed


def transform_cursor(
    record: dict[str, Any],
    stats: dict[str, int],
    _context: dict[str, Any],
) -> tuple[dict[str, Any], bool]:
    changed = False
    content = blocks(record)
    if content is not None:
        for block in content:
            if not isinstance(block, dict) or block.get("type") not in {
                "tool_result",
                "tool_use_result",
            }:
                continue
            for key in ("content", "output", "tool_use_result"):
                changed |= prune_field(block, key, "tool-result", stats)

    if record.get("type") == "tool_call" and record.get("subtype") == "completed":
        envelope = record.get("tool_call")
        if isinstance(envelope, dict):
            for key, value in envelope.items():
                if key.endswith("ToolCall") and isinstance(value, dict):
                    changed |= prune_field(value, "result", "tool-result", stats)

    if record.get("type") == "result" and "usage" in record:
        record.pop("usage")
        stats["telemetry_fields_pruned"] += 1
        changed = True
    return record, changed


def transform_grok(
    record: dict[str, Any],
    stats: dict[str, int],
    _context: dict[str, Any],
    filename: str,
) -> tuple[dict[str, Any] | None, bool]:
    record_type = record.get("type")
    if filename == "events.jsonl" and record_type in {
        "phase_changed",
        "first_token",
        "loop_started",
    }:
        stats["telemetry_records_dropped"] += 1
        return None, True

    changed = False
    if filename == "chat_history.jsonl" and record_type == "tool_result":
        changed |= prune_field(record, "content", "tool-result", stats)

    if filename == "updates.jsonl":
        params = record.get("params")
        update = params.get("update") if isinstance(params, dict) else None
        if isinstance(update, dict):
            if "usage" in update:
                update.pop("usage")
                stats["telemetry_fields_pruned"] += 1
                changed = True
            if "toolCallId" in update and ("rawOutput" in update or "status" in update):
                changed |= prune_field(update, "rawOutput", "tool-result-detail", stats)
                changed |= prune_field(update, "content", "tool-result", stats)
    if filename == "rewind_points.jsonl":
        for key in ("after_snapshots", "file_snapshots"):
            changed |= prune_field(
                record,
                key,
                "environment-snapshot",
                stats,
                counter="environment_snapshot_fields_pruned",
            )
    return record, changed


def detect_from_record(record: dict[str, Any], filename: str) -> dict[str, int]:
    scores = {provider: 0 for provider in PROVIDERS}
    record_type = record.get("type")
    payload = record.get("payload")
    message = record.get("message")

    if record_type in {"session_meta", "response_item", "turn_context", "event_msg", "world_state"}:
        scores["codex"] += 8
    if isinstance(payload, dict) and payload.get("type") in {
        "message",
        "reasoning",
        "function_call",
        "custom_tool_call",
    }:
        scores["codex"] += 3

    if "sessionId" in record and record_type in {
        "assistant",
        "user",
        "system",
        "summary",
        "queue-operation",
    }:
        scores["claude"] += 8
    if isinstance(message, dict) and message.get("role") in {"assistant", "user"}:
        scores["claude"] += 3

    if filename in {"chat_history.jsonl", "events.jsonl", "updates.jsonl", "summary.json"}:
        scores["grok"] += 10
    if record_type == "tool_result" and "tool_call_id" in record:
        scores["grok"] += 5
    if record_type == "reasoning" and "encrypted_content" in record and "payload" not in record:
        scores["grok"] += 3
    if record_type == "assistant" and isinstance(record.get("tool_calls"), list):
        scores["grok"] += 3

    if record_type == "turn_ended":
        scores["cursor"] += 8
    if isinstance(record.get("role"), str) and isinstance(message, dict):
        scores["cursor"] += 8
    if record_type == "tool_call" and isinstance(record.get("tool_call"), dict):
        scores["cursor"] += 8
    if record_type == "system" and record.get("subtype") == "init" and "apiKeySource" in record:
        scores["cursor"] += 8
    return scores


def candidate_json_files(source: Path) -> Iterable[Path]:
    if source.is_file():
        yield source
        return
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"session input contains a symlink: {path}")
        if path.is_file() and path.suffix in {".json", ".jsonl"}:
            yield path


def detect_provider(source: Path) -> str:
    if source.is_dir() and (source / "summary.json").is_file() and (
        source / "chat_history.jsonl"
    ).is_file():
        return "grok"

    totals = {provider: 0 for provider in PROVIDERS}
    parsed = 0
    for path in candidate_json_files(source):
        if path.suffix == ".json":
            try:
                records = [json.loads(path.read_text(encoding="utf-8"))]
            except (OSError, UnicodeDecodeError, json.JSONDecodeError):
                continue
        else:
            records = []
            with path.open("rb") as handle:
                for raw in handle:
                    if len(records) >= 200:
                        break
                    try:
                        value = json.loads(raw)
                    except (UnicodeDecodeError, json.JSONDecodeError):
                        continue
                    records.append(value)
        for record in records:
            if not isinstance(record, dict):
                continue
            parsed += 1
            for provider, score in detect_from_record(record, path.name).items():
                totals[provider] += score
        if parsed >= 400:
            break
    best = max(totals, key=totals.get)
    tied = [provider for provider, score in totals.items() if score == totals[best]]
    if totals[best] == 0 or len(tied) != 1:
        raise ValueError(f"could not detect one transcript provider: {totals}")
    return best


def transform_jsonl(
    source: Path,
    destination: Path,
    provider: str,
) -> dict[str, int]:
    stats = fresh_stats()
    context: dict[str, Any] = {"prior_payload_hashes": set()}
    with source.open("rb") as reader, destination.open("wb") as writer:
        for raw in reader:
            stats["records_read"] += 1
            try:
                record = json.loads(raw)
            except (UnicodeDecodeError, json.JSONDecodeError):
                writer.write(raw)
                stats["records_written"] += 1
                stats["malformed_records_preserved"] += 1
                continue
            if not isinstance(record, dict):
                writer.write(raw)
                stats["records_written"] += 1
                continue
            working = copy.deepcopy(record)
            if provider == "codex":
                transformed, changed = transform_codex(working, stats, context)
            elif provider == "claude":
                transformed, changed = transform_claude(working, stats, context)
            elif provider == "cursor":
                transformed, changed = transform_cursor(working, stats, context)
            elif provider == "grok":
                transformed, changed = transform_grok(working, stats, context, source.name)
            else:
                raise AssertionError(provider)
            if transformed is None:
                stats["records_dropped"] += 1
                continue
            if changed:
                writer.write(canonical_bytes(transformed) + b"\n")
                stats["records_changed"] += 1
            else:
                writer.write(raw)
            stats["records_written"] += 1
    return stats


def transform_json_file(
    source: Path,
    destination: Path,
    provider: str,
) -> dict[str, int]:
    stats = fresh_stats()
    if provider == "grok" and source.name == "signals.json":
        try:
            value = json.loads(source.read_bytes())
        except (UnicodeDecodeError, json.JSONDecodeError):
            destination.write_bytes(source.read_bytes())
            stats["malformed_records_preserved"] += 1
            return stats
        destination.write_bytes(canonical_bytes(marker(value, "telemetry-file")) + b"\n")
        stats["telemetry_fields_pruned"] += 1
        stats["records_read"] += 1
        stats["records_written"] += 1
        stats["records_changed"] += 1
        return stats
    destination.write_bytes(source.read_bytes())
    return stats


def source_files(source: Path) -> list[tuple[Path, Path]]:
    if source.is_file():
        return [(source, Path(source.name))]
    found: list[tuple[Path, Path]] = []
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"session input contains a symlink: {path}")
        if path.is_file():
            found.append((path, path.relative_to(source)))
    return found


def validate_input_shape(source: Path, provider: str) -> None:
    if source.is_file():
        return
    if provider == "grok":
        if not (source / "summary.json").is_file() or not (
            source / "chat_history.jsonl"
        ).is_file():
            raise ValueError("pass one Grok session directory, not a Grok home or sessions root")
        return
    if provider == "cursor" and any(source.glob("*.jsonl")):
        return
    raise ValueError(
        f"pass one {provider} session JSONL file; broad provider directories are refused"
    )


def write_deterministic_archive(stage: Path, output: Path, level: int) -> None:
    with output.open("xb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=level, mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for path in sorted(stage.rglob("*")):
                    if not path.is_file():
                        continue
                    relative = path.relative_to(stage).as_posix()
                    info = tarfile.TarInfo(relative)
                    info.size = path.stat().st_size
                    info.mode = 0o644
                    info.mtime = 0
                    info.uid = 0
                    info.gid = 0
                    info.uname = ""
                    info.gname = ""
                    with path.open("rb") as handle:
                        archive.addfile(info, handle)


def compress(source: Path, output: Path, provider_arg: str, level: int) -> dict[str, Any]:
    source = source.resolve()
    output = output.resolve()
    if not source.exists():
        raise ValueError(f"session input does not exist: {source}")
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    if source.is_file() and output == source:
        raise ValueError("output cannot replace the session input")
    if source.is_dir() and output.is_relative_to(source):
        raise ValueError("output cannot be written inside the session input directory")
    if output.suffixes[-2:] != [".tar", ".gz"]:
        raise ValueError("output must end in .tar.gz")
    provider = detect_provider(source) if provider_arg == "auto" else provider_arg
    validate_input_shape(source, provider)
    files = source_files(source)
    if not files:
        raise ValueError("session input contains no files")

    aggregate = fresh_stats()
    manifest_files: list[dict[str, Any]] = []
    source_stat_before = [(path, path.stat().st_size, path.stat().st_mtime_ns, sha256_file(path)) for path, _ in files]
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="compress-agent-transcript.") as temporary:
        stage = Path(temporary)
        session_root = stage / "session"
        for original, relative in files:
            destination = session_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if original.suffix == ".jsonl":
                stats = transform_jsonl(original, destination, provider)
            elif original.suffix == ".json":
                stats = transform_json_file(original, destination, provider)
            else:
                destination.write_bytes(original.read_bytes())
                stats = fresh_stats()
            merge_stats(aggregate, stats)
            manifest_files.append(
                {
                    "path": f"session/{relative.as_posix()}",
                    "source_bytes": original.stat().st_size,
                    "source_sha256": source_stat_before[len(manifest_files)][3],
                    "archived_bytes": destination.stat().st_size,
                    "archived_sha256": sha256_file(destination),
                    "stats": stats,
                }
            )

        source_stat_after = [(path.stat().st_size, path.stat().st_mtime_ns, sha256_file(path)) for path, *_ in source_stat_before]
        for before, after in zip(source_stat_before, source_stat_after, strict=True):
            if (before[1], before[2], before[3]) != after:
                raise RuntimeError(f"source changed during compression: {before[0]}")

        manifest: dict[str, Any] = {
            "schema": "compressed-agent-transcript-v1",
            "compressor_version": VERSION,
            "provider": provider,
            "source_name": source.name,
            "sanitizes_content": False,
            "resumable_by_provider": False,
            "policy": {
                "messages": "kept",
                "reasoning": "kept",
                "tool_calls_and_arguments": "kept",
                "tool_result_bodies": "replaced-with-hash-and-byte-count",
                "known_telemetry": "removed-or-replaced",
                "unknown_records": "kept",
                "malformed_records": "kept",
            },
            "totals": aggregate,
            "files": manifest_files,
        }
        (stage / "manifest.json").write_bytes(canonical_bytes(manifest) + b"\n")
        write_deterministic_archive(stage, output, level)
    return manifest


def verify_archive(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ValueError(f"archive does not exist: {path}")
    with tarfile.open(path, mode="r:gz") as archive:
        members = {member.name: member for member in archive.getmembers() if member.isfile()}
        manifest_member = members.get("manifest.json")
        if manifest_member is None:
            raise ValueError("archive has no manifest.json")
        manifest_stream = archive.extractfile(manifest_member)
        if manifest_stream is None:
            raise ValueError("cannot read archive manifest")
        manifest = json.load(manifest_stream)
        if manifest.get("schema") != "compressed-agent-transcript-v1":
            raise ValueError("unknown archive manifest schema")
        expected = {entry["path"]: entry for entry in manifest.get("files", [])}
        actual_paths = set(members) - {"manifest.json"}
        if actual_paths != set(expected):
            raise ValueError("archive file set does not match manifest")
        for name, entry in expected.items():
            stream = archive.extractfile(members[name])
            if stream is None:
                raise ValueError(f"cannot read archived file: {name}")
            digest = hashlib.sha256()
            total = 0
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                total += len(chunk)
                digest.update(chunk)
            if total != entry["archived_bytes"] or digest.hexdigest() != entry["archived_sha256"]:
                raise ValueError(f"archived file failed manifest verification: {name}")
    return manifest


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        prog="compress-agent-transcript",
        description="Mechanically compress native agent transcripts. This does not sanitize content.",
    )
    commands = root.add_subparsers(dest="command", required=True)
    compress_parser = commands.add_parser("compress", help="write one verified native-format archive")
    compress_parser.add_argument("input", type=Path)
    compress_parser.add_argument("--output", type=Path, required=True)
    compress_parser.add_argument("--provider", choices=("auto", *PROVIDERS), default="auto")
    compress_parser.add_argument("--compression-level", type=int, choices=range(1, 10), default=6)
    verify_parser = commands.add_parser("verify", help="verify archive contents against its manifest")
    verify_parser.add_argument("archive", type=Path)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "compress":
            manifest = compress(args.input, args.output, args.provider, args.compression_level)
            verified = verify_archive(args.output)
            result = {
                "status": "ok",
                "provider": manifest["provider"],
                "output": str(args.output.resolve()),
                "archive_bytes": args.output.stat().st_size,
                "source_bytes": sum(entry["source_bytes"] for entry in manifest["files"]),
                "files": len(manifest["files"]),
                "tool_result_fields_pruned": verified["totals"]["tool_result_fields_pruned"],
                "telemetry_records_dropped": verified["totals"]["telemetry_records_dropped"],
                "sanitizes_content": False,
            }
        else:
            manifest = verify_archive(args.archive)
            result = {
                "status": "ok",
                "provider": manifest["provider"],
                "archive": str(args.archive.resolve()),
                "files": len(manifest["files"]),
            }
    except (OSError, RuntimeError, ValueError, tarfile.TarError) as error:
        print(json.dumps({"status": "error", "error": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
