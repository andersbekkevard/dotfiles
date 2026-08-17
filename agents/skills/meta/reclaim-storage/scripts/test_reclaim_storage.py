from __future__ import annotations

import datetime as dt
import json
import os
import tempfile
import unittest
from pathlib import Path

from reclaim_storage import run_audit


NOW = dt.datetime.now(dt.timezone.utc)


class ReclaimStorageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.home.mkdir()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def make_cargo_target(self) -> Path:
        target = self.home / "project" / "target"
        (target / "debug").mkdir(parents=True)
        (target / ".rustc_info.json").write_text("{}\n")
        (target / "debug" / "artifact").write_bytes(b"x" * 8192)
        return target

    def make_session(self) -> Path:
        sessions = self.home / ".codex" / "sessions"
        sessions.mkdir(parents=True)
        path = sessions / "old.jsonl"
        records = [
            {"timestamp": "2020-01-01T00:00:00Z", "type": "session_meta", "payload": {"id": "old"}},
            {
                "timestamp": "2020-01-01T00:00:01Z",
                "type": "response_item",
                "payload": {"type": "message", "role": "user", "content": "hello"},
            },
            {
                "timestamp": "2020-01-01T00:00:02Z",
                "type": "response_item",
                "payload": {
                    "type": "function_call",
                    "name": "shell",
                    "arguments": "large" * 100,
                },
            },
        ]
        path.write_text("".join(json.dumps(item) + "\n" for item in records))
        modified = (NOW - dt.timedelta(days=10)).timestamp()
        os.utime(path, (modified, modified))
        return path

    def write_config(self) -> Path:
        config = self.root / "machine.toml"
        config.write_text(
            f'''version = 1
machine = "test"

[inventory]
roots = ["{self.home}"]
min_report_bytes = 1

[cargo]
search_roots = ["{self.home}"]
exclude_names = [".git"]

[codex]
sessions_root = "{self.home / '.codex' / 'sessions'}"
archive_root = "{self.root / 'archive'}"
retention_days = 7

[[candidates]]
id = "cache"
path = "{self.home / '.cache'}"
category = "network-cache"
recreation = "Download again."
'''
        )
        return config

    def test_audit_classifies_without_mutating(self) -> None:
        cache = self.home / ".cache"
        cache.mkdir()
        cache_file = cache / "download"
        cache_file.write_bytes(b"a" * 4096)
        target = self.make_cargo_target()
        session = self.make_session()
        unique = self.home / "unique-work"
        unique.mkdir()
        (unique / "data").write_bytes(b"z" * 4096)
        before = {path: path.stat().st_mtime_ns for path in (cache_file, target, session, unique)}

        result = run_audit(self.write_config())

        self.assertEqual(result["mode"], "audit-only")
        self.assertFalse(result["mutations_performed"])
        ids = {item["id"] for item in result["candidates"]}
        self.assertIn("cache", ids)
        self.assertIn("codex-sessions-older-than-cutoff", ids)
        self.assertTrue(any(item.startswith("cargo-target-") for item in ids))
        self.assertTrue(any(item["path"] == str(unique) for item in result["unknown_large_paths"]))
        self.assertGreater(result["codex_sessions"]["reclaimable_bytes"], 0)
        codex_candidate = next(
            item
            for item in result["candidates"]
            if item["id"] == "codex-sessions-older-than-cutoff"
        )
        self.assertEqual(codex_candidate["activity_scope"], "eligible_session_files_only")
        self.assertTrue(codex_candidate["decision_uncertainty"])
        after = {path: path.stat().st_mtime_ns for path in before}
        self.assertEqual(before, after)

    def test_parent_candidate_prevents_double_counting_child_target(self) -> None:
        cache = self.home / ".cache"
        target = cache / "project" / "target"
        target.mkdir(parents=True)
        (target / ".rustc_info.json").write_text("{}\n")
        (target / "artifact").write_bytes(b"x" * 4096)
        self.make_session()

        result = run_audit(self.write_config())

        parent = next(item for item in result["candidates"] if item["id"] == "cache")
        child = next(item for item in result["candidates"] if item["path"] == str(target))
        self.assertEqual(child["covered_by"], "cache")
        self.assertEqual(child["counted_reclaimable_bytes"], 0)
        counted = sum(item["counted_reclaimable_bytes"] for item in result["candidates"])
        self.assertEqual(result["reclaimable_bytes_non_overlapping"], counted)
        self.assertGreaterEqual(parent["counted_reclaimable_bytes"], child["reclaimable_bytes"])


if __name__ == "__main__":
    unittest.main()
