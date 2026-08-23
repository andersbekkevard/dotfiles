from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest


SCRIPT = Path(__file__).parents[1] / "scripts" / "compress_agent_transcript.py"
SPEC = importlib.util.spec_from_file_location("compress_agent_transcript", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def write_jsonl(path: Path, records: list[object], malformed: bytes | None = None) -> None:
    with path.open("wb") as handle:
        for record in records:
            handle.write(json.dumps(record, separators=(",", ":")).encode() + b"\n")
        if malformed is not None:
            handle.write(malformed)


def archive_files(path: Path) -> tuple[dict, dict[str, bytes]]:
    with tarfile.open(path, "r:gz") as archive:
        files = {}
        for member in archive.getmembers():
            if not member.isfile():
                continue
            stream = archive.extractfile(member)
            assert stream is not None
            files[member.name] = stream.read()
    return json.loads(files["manifest.json"]), files


class CompressAgentTranscriptTests(unittest.TestCase):
    def run_fixture(self, provider: str, source: Path) -> tuple[dict, dict[str, bytes], bytes]:
        output = source.parent / f"{provider}.tar.gz"
        before = source.read_bytes() if source.is_file() else b""
        manifest = MODULE.compress(source, output, "auto", 6)
        self.assertEqual(provider, manifest["provider"])
        MODULE.verify_archive(output)
        read_manifest, files = archive_files(output)
        self.assertEqual(provider, read_manifest["provider"])
        if source.is_file():
            self.assertEqual(before, source.read_bytes())
        return read_manifest, files, output.read_bytes()

    def test_codex_preserves_history_and_prunes_results(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "rollout.jsonl"
            message = {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "hello"}]}
            records = [
                {"type": "session_meta", "payload": {"id": "c1", "base_instructions": "law"}},
                {"type": "response_item", "payload": message},
                {"type": "response_item", "payload": {"type": "reasoning", "summary": [{"text": "think"}], "encrypted_content": "cipher"}},
                {"type": "response_item", "payload": {"type": "function_call", "name": "shell", "arguments": "{\"cmd\":\"pwd\"}", "call_id": "t1"}},
                {"type": "response_item", "payload": {"type": "function_call_output", "output": "VERY_SECRET_RESULT", "call_id": "t1"}},
                {"type": "event_msg", "payload": {"type": "token_count", "info": {"total": 10}}},
                {"type": "world_state", "payload": {"state": "UI_STATE"}},
                {"type": "compacted", "payload": {"replacement_history": [message, {"type": "compaction", "encrypted_content": "unique"}]}},
                {"type": "unknown-future-record", "payload": {"value": "keep"}},
            ]
            write_jsonl(source, records, b"not-json\n")
            manifest, files, first_archive = self.run_fixture("codex", source)
            content = files["session/rollout.jsonl"]
            self.assertNotIn(b"VERY_SECRET_RESULT", content)
            self.assertNotIn(b"UI_STATE", content)
            self.assertIn(b'"encrypted_content":"cipher"', content)
            self.assertIn(b'"arguments":"{\\"cmd\\":\\"pwd\\"}"', content)
            self.assertIn(b"not-json", content)
            self.assertEqual(1, manifest["totals"]["tool_result_fields_pruned"])
            self.assertEqual(2, manifest["totals"]["telemetry_records_dropped"])
            self.assertEqual(1, manifest["totals"]["duplicate_compaction_items_pruned"])
            second = Path(temporary) / "codex-2.tar.gz"
            MODULE.compress(source, second, "auto", 6)
            self.assertEqual(first_archive, second.read_bytes())

    def test_claude_preserves_thinking_and_call(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "claude.jsonl"
            write_jsonl(
                source,
                [
                    {"type": "assistant", "sessionId": "a", "message": {"role": "assistant", "usage": {"input_tokens": 1}, "content": [{"type": "thinking", "thinking": "reason"}, {"type": "tool_use", "id": "t", "name": "Read", "input": {"file": "x"}}]}},
                    {"type": "user", "sessionId": "a", "toolUseResult": {"details": "DUPLICATE_RESULT"}, "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t", "content": "CLAUDE_RESULT"}]}},
                ],
            )
            manifest, files, _ = self.run_fixture("claude", source)
            content = files["session/claude.jsonl"]
            self.assertIn(b"reason", content)
            self.assertIn(b'"name":"Read"', content)
            self.assertNotIn(b"CLAUDE_RESULT", content)
            self.assertNotIn(b"DUPLICATE_RESULT", content)
            self.assertNotIn(b'"usage"', content)
            self.assertEqual(2, manifest["totals"]["tool_result_fields_pruned"])

    def test_cursor_native_and_streamed_results(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "cursor.jsonl"
            write_jsonl(
                source,
                [
                    {"role": "assistant", "message": {"content": [{"type": "thinking", "thinking": "reason"}, {"type": "tool_use", "id": "t1", "name": "shell", "input": {"cmd": "pwd"}}]}},
                    {"role": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "t1", "content": "CURSOR_NATIVE_RESULT"}]}},
                    {"type": "tool_call", "subtype": "completed", "tool_call": {"toolCallId": "t2", "shellToolCall": {"args": {"cmd": "ls"}, "result": {"output": "CURSOR_STREAM_RESULT"}}}},
                    {"type": "result", "result": "final answer", "usage": {"inputTokens": 1}},
                    {"type": "turn_ended", "status": "success"},
                ],
            )
            manifest, files, _ = self.run_fixture("cursor", source)
            content = files["session/cursor.jsonl"]
            self.assertIn(b'"cmd":"pwd"', content)
            self.assertIn(b'"cmd":"ls"', content)
            self.assertIn(b"final answer", content)
            self.assertNotIn(b"CURSOR_NATIVE_RESULT", content)
            self.assertNotIn(b"CURSOR_STREAM_RESULT", content)
            self.assertNotIn(b'"usage"', content)
            self.assertEqual(2, manifest["totals"]["tool_result_fields_pruned"])

    def test_grok_preserves_directory_and_prunes_duplicate_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "grok-session"
            source.mkdir()
            (source / "summary.json").write_text(json.dumps({"info": {"id": "g"}}))
            write_jsonl(
                source / "chat_history.jsonl",
                [
                    {"type": "user", "content": "question", "prompt_index": 0},
                    {"type": "reasoning", "summary": [{"text": "reason"}], "encrypted_content": "cipher"},
                    {"type": "assistant", "content": "answer", "tool_calls": [{"id": "t", "name": "bash", "arguments": {"cmd": "pwd"}}]},
                    {"type": "tool_result", "tool_call_id": "t", "content": "GROK_CHAT_RESULT"},
                ],
            )
            write_jsonl(
                source / "updates.jsonl",
                [{"method": "session/update", "params": {"update": {"toolCallId": "t", "status": "completed", "content": ["GROK_UPDATE_RESULT"], "rawOutput": {"result": "GROK_RAW_RESULT"}}}}],
            )
            write_jsonl(source / "events.jsonl", [{"type": "phase_changed", "phase": "x"}, {"type": "tool_completed", "tool_call_id": "t"}])
            write_jsonl(source / "rewind_points.jsonl", [{"prompt_index": 0, "file_snapshots": {"x": "SNAPSHOT"}}])
            (source / "signals.json").write_text(json.dumps({"contextTokensUsed": 10}))
            manifest, files, _ = self.run_fixture("grok", source)
            joined = b"\n".join(files.values())
            self.assertIn(b'"cmd":"pwd"', joined)
            self.assertIn(b'"encrypted_content":"cipher"', joined)
            self.assertNotIn(b"GROK_CHAT_RESULT", joined)
            self.assertNotIn(b"GROK_UPDATE_RESULT", joined)
            self.assertNotIn(b"GROK_RAW_RESULT", joined)
            self.assertNotIn(b"SNAPSHOT", joined)
            self.assertEqual(3, manifest["totals"]["tool_result_fields_pruned"])
            self.assertEqual(1, manifest["totals"]["telemetry_records_dropped"])

    def test_output_cannot_enter_source_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "grok-session"
            source.mkdir()
            (source / "summary.json").write_text(json.dumps({"info": {"id": "g"}}))
            write_jsonl(source / "chat_history.jsonl", [{"type": "user", "content": "hi", "prompt_index": 0}])
            with self.assertRaisesRegex(ValueError, "inside the session input"):
                MODULE.compress(source, source / "archive.tar.gz", "auto", 6)

    def test_broad_provider_home_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "codex-home"
            session = source / "sessions" / "2026" / "08" / "23"
            session.mkdir(parents=True)
            write_jsonl(
                session / "rollout.jsonl",
                [{"type": "session_meta", "payload": {"id": "c1"}}],
            )
            (source / "auth.json").write_text('{"token":"must-not-enter-archive"}')
            with self.assertRaisesRegex(ValueError, "broad provider directories"):
                MODULE.compress(source, Path(temporary) / "archive.tar.gz", "auto", 6)


if __name__ == "__main__":
    unittest.main()
