from __future__ import annotations

import datetime as dt
import gzip
import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path

from codex_sessions import SessionError, archive_sessions, audit_sessions


NOW = dt.datetime(2026, 8, 17, 12, 0, tzinfo=dt.timezone.utc)


def record(timestamp: str, kind: str, payload: dict[str, object]) -> bytes:
    return (json.dumps({"timestamp": timestamp, "type": kind, "payload": payload}) + "\n").encode()


class CodexSessionsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "sessions"
        self.root.mkdir()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_session(self, name: str, lines: list[bytes], age_days: int) -> Path:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"".join(lines))
        modified = (NOW - dt.timedelta(days=age_days)).timestamp()
        os.utime(path, (modified, modified))
        return path

    def test_audit_retains_messages_metadata_and_invalid_lines(self) -> None:
        retained = [
            record("2026-08-01T00:00:00Z", "session_meta", {"id": "old"}),
            record(
                "2026-08-01T00:01:00Z",
                "response_item",
                {"type": "message", "role": "user", "content": "question"},
            ),
            record(
                "2026-08-01T00:02:00Z",
                "response_item",
                {"type": "message", "role": "assistant", "content": "answer"},
            ),
            record(
                "2026-08-01T00:03:00Z",
                "event_msg",
                {"type": "agent_message", "message": "status"},
            ),
            b"not-json\n",
        ]
        excluded = [
            record(
                "2026-08-01T00:04:00Z",
                "response_item",
                {"type": "function_call", "name": "shell"},
            ),
            record("2026-08-01T00:05:00Z", "event_msg", {"type": "token_count", "tokens": 10}),
            record(
                "2026-08-01T00:06:00Z",
                "event_msg",
                {"type": "agent_reasoning", "text": "private"},
            ),
        ]
        old = self.write_session("2026/08/old.jsonl", retained + excluded, age_days=10)
        self.write_session("2026/08/fresh.jsonl", retained, age_days=2)

        result = audit_sessions(self.root, now=NOW, include_sessions=True)

        self.assertEqual(result["eligible_session_count"], 1)
        self.assertEqual(result["ineligible_session_count"], 1)
        self.assertEqual(result["eligible_source_bytes"], old.stat().st_size)
        self.assertEqual(result["eligible_archive_raw_bytes"], sum(map(len, retained)))
        self.assertEqual(result["reclaimable_bytes"], sum(map(len, excluded)))
        self.assertEqual(result["invalid_lines_retained"], 1)

    def test_latest_record_and_mtime_must_both_precede_cutoff(self) -> None:
        self.write_session(
            "old-file-new-record.jsonl",
            [record("2026-08-16T00:00:00Z", "session_meta", {"id": "new"})],
            age_days=10,
        )
        self.write_session(
            "new-file-old-record.jsonl",
            [record("2026-08-01T00:00:00Z", "session_meta", {"id": "old"})],
            age_days=1,
        )
        result = audit_sessions(self.root, now=NOW)
        self.assertEqual(result["eligible_session_count"], 0)

    def test_retention_cannot_be_shorter_than_seven_days(self) -> None:
        with self.assertRaises(SessionError):
            audit_sessions(self.root, retention_days=6, now=NOW)

    def test_archive_is_verified_and_additive(self) -> None:
        lines = [
            record("2026-08-01T00:00:00Z", "session_meta", {"id": "old"}),
            record(
                "2026-08-01T00:01:00Z",
                "response_item",
                {"type": "message", "role": "user", "content": "question"},
            ),
            record(
                "2026-08-01T00:02:00Z",
                "response_item",
                {"type": "function_call", "name": "shell"},
            ),
        ]
        source = self.write_session("year/month/session.jsonl", lines, age_days=10)
        before = source.read_bytes()
        output = Path(self.temporary.name) / "archive"

        manifest = archive_sessions(self.root, output, now=NOW)

        self.assertEqual(source.read_bytes(), before)
        self.assertFalse(manifest["source_sessions_deleted"])
        self.assertTrue((output / "manifest.json").is_file())
        archived = output / manifest["entries"][0]["archive_path"]
        with gzip.open(archived, "rb") as handle:
            raw = handle.read()
        self.assertNotIn(b"function_call", raw)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), manifest["entries"][0]["retained_sha256"])

    def test_archive_cannot_contain_source_or_be_contained_by_it(self) -> None:
        with self.assertRaises(SessionError):
            archive_sessions(self.root, self.root / "archive", now=NOW)


if __name__ == "__main__":
    unittest.main()
