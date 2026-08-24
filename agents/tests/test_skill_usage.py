from __future__ import annotations

import json
import hashlib
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "agents/skill-usage"


def write_jsonl(path: Path, records: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(record, separators=(",", ":")) + "\n" for record in records),
        encoding="utf-8",
    )


def git(cwd: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=True,
        text=True,
        capture_output=True,
    )


class SkillUsageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="skill-usage-test.")
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.state = self.root / "state"
        self.repo.mkdir()
        git(self.repo, "init", "-b", "main")
        git(self.repo, "config", "user.name", "Skill Usage Test")
        git(self.repo, "config", "user.email", "skill-usage@example.invalid")
        (self.repo / "README.md").write_text("fixture\n", encoding="utf-8")
        git(self.repo, "add", "README.md")
        git(self.repo, "commit", "-m", "fixture")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def cli(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "python3",
                str(SCRIPT),
                "--repo",
                str(self.repo),
                "--state-dir",
                str(self.state),
                *args,
            ],
            check=check,
            text=True,
            capture_output=True,
        )

    def report(self) -> dict[str, dict[str, object]]:
        result = self.cli("report", "--json")
        return {row["skill"]: row for row in json.loads(result.stdout)}

    def test_collects_four_harnesses_and_deduplicates_native_markers(self) -> None:
        self.cli("init")
        fixtures = self.root / "transcripts"

        codex = fixtures / "codex.jsonl"
        write_jsonl(
            codex,
            [
                {
                    "timestamp": "2026-08-24T09:00:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "id": "message-1",
                        "content": [
                            {
                                "type": "input_text",
                                "text": "use [$codebase-design](/tmp/skills/codebase-design/SKILL.md)",
                            }
                        ],
                        "internal_chat_message_metadata_passthrough": {
                            "turn_id": "turn-1"
                        },
                    },
                },
                {
                    "timestamp": "2026-08-24T09:00:00Z",
                    "type": "response_item",
                    "payload": {
                        "type": "message",
                        "role": "user",
                        "id": "message-2",
                        "content": [
                            {
                                "type": "input_text",
                                "text": "<skill><name>codebase-design</name></skill>",
                            }
                        ],
                        "internal_chat_message_metadata_passthrough": {
                            "turn_id": "turn-1"
                        },
                    },
                },
                {
                    "timestamp": "2026-08-24T09:00:01Z",
                    "type": "response_item",
                    "payload": {
                        "type": "custom_tool_call",
                        "id": "tool-1",
                        "name": "exec",
                        "input": "sed -n 1,80p /tmp/skills/unslop/SKILL.md",
                        "internal_chat_message_metadata_passthrough": {
                            "turn_id": "turn-1"
                        },
                    },
                },
            ],
        )

        claude = fixtures / "claude.jsonl"
        write_jsonl(
            claude,
            [
                {
                    "type": "user",
                    "sessionId": "claude-session",
                    "uuid": "user-1",
                    "promptId": "prompt-1",
                    "timestamp": "2026-08-24T09:01:00Z",
                    "message": {
                        "role": "user",
                        "content": "<command-name>/last30days:last30days</command-name>",
                    },
                },
                {
                    "type": "user",
                    "sessionId": "claude-session",
                    "uuid": "builtin-1",
                    "timestamp": "2026-08-24T09:01:00Z",
                    "message": {
                        "role": "user",
                        "content": "<command-name>/compact</command-name>",
                    },
                },
                {
                    "type": "assistant",
                    "sessionId": "claude-session",
                    "uuid": "assistant-1",
                    "timestamp": "2026-08-24T09:01:01Z",
                    "message": {
                        "role": "assistant",
                        "content": [
                            {
                                "type": "tool_use",
                                "id": "skill-tool-1",
                                "name": "Skill",
                                "input": {"skill": "codex-dispatch"},
                            }
                        ],
                    },
                },
            ],
        )

        cursor = fixtures / "cursor.jsonl"
        write_jsonl(
            cursor,
            [
                {
                    "role": "user",
                    "session_id": "cursor-session",
                    "timestamp": "2026-08-24T09:02:00Z",
                    "message": {
                        "content": [
                            {
                                "type": "text",
                                "text": "<manually_attached_skills>\nSkill Name: html\n</manually_attached_skills>",
                            }
                        ]
                    },
                },
                {
                    "role": "assistant",
                    "session_id": "cursor-session",
                    "timestamp": "2026-08-24T09:02:01Z",
                    "message": {
                        "content": [
                            {
                                "type": "tool_use",
                                "id": "cursor-read-1",
                                "name": "Read",
                                "input": {"path": "/tmp/skills/show-me/SKILL.md"},
                            }
                        ]
                    },
                },
                {
                    "role": "assistant",
                    "session_id": "cursor-session",
                    "timestamp": "2026-08-24T09:02:02Z",
                    "message": {
                        "content": [
                            {
                                "type": "tool_use",
                                "name": "ReadFile",
                                "input": {
                                    "path": "/tmp/skills/show-me/SKILL.md",
                                    "offset": 200,
                                },
                            }
                        ]
                    },
                },
            ],
        )

        grok = fixtures / "grok" / "chat_history.jsonl"
        write_jsonl(
            grok,
            [
                {
                    "type": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": "<system-reminder>Absolute path: /tmp/skills/beads/SKILL.md</system-reminder><user_query>inspect this</user_query>",
                        }
                    ],
                },
                {
                    "type": "assistant",
                    "timestamp": "2026-08-24T09:03:00Z",
                    "tool_calls": [
                        {
                            "id": "grok-read-1",
                            "name": "read_file",
                            "arguments": json.dumps(
                                {"target_file": "/tmp/skills/tufte-viz/SKILL.md"}
                            ),
                        },
                        {
                            "id": "grok-read-2",
                            "name": "ReadFile",
                            "arguments": json.dumps(
                                {
                                    "target_file": "/tmp/skills/tufte-viz/SKILL.md",
                                    "offset": 200,
                                }
                            ),
                        },
                    ],
                },
            ],
        )

        sources = [
            f"codex={codex}",
            f"claude={claude}",
            f"cursor={cursor}",
            f"grok={grok}",
        ]
        command: list[str] = ["collect", "--from-start"]
        for source in sources:
            command.extend(("--source", source))
        result = self.cli(*command)
        self.assertIn("7 new uses", result.stdout)

        report = self.report()
        self.assertEqual(report["codebase-design"]["by_invocation"], {"user": 1})
        self.assertEqual(report["unslop"]["by_invocation"], {"model": 1})
        self.assertEqual(report["last30days:last30days"]["by_invocation"], {"user": 1})
        self.assertEqual(report["codex-dispatch"]["by_invocation"], {"model": 1})
        self.assertEqual(report["html"]["by_invocation"], {"user": 1})
        self.assertEqual(report["show-me"]["by_invocation"], {"model": 1})
        self.assertEqual(report["tufte-viz"]["by_invocation"], {"model": 1})
        self.assertNotIn("beads", report)
        self.assertNotIn("compact", report)

        second = self.cli(*command)
        self.assertIn("0 new uses", second.stdout)
        self.assertEqual(self.report(), report)

    def test_collect_only_reads_complete_appended_jsonl_records(self) -> None:
        self.cli("init")
        transcript = self.root / "append.jsonl"
        transcript.write_text("", encoding="utf-8")
        source = f"codex={transcript}"
        partial = json.dumps(
            {
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "user",
                    "id": "message-1",
                    "content": [
                        {
                            "type": "input_text",
                            "text": "[$html](/tmp/skills/html/SKILL.md)",
                        }
                    ],
                },
            }
        )
        transcript.write_text(partial, encoding="utf-8")
        self.assertIn(
            "0 new uses", self.cli("collect", "--source", source).stdout
        )
        with transcript.open("a", encoding="utf-8") as handle:
            handle.write("\n")
        self.assertIn(
            "1 new uses", self.cli("collect", "--source", source).stdout
        )
        self.assertIn(
            "0 new uses", self.cli("collect", "--source", source).stdout
        )

    def test_record_and_report(self) -> None:
        self.cli("init")
        self.cli(
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
            "--count",
            "3",
        )
        report = self.report()
        self.assertEqual(report["html"]["total"], 3)
        self.assertEqual(report["html"]["by_harness"], {"codex": 3})

    def test_replayed_history_is_deduplicated_and_prebaseline_records_are_skipped(self) -> None:
        self.cli("init")
        fixtures = self.root / "replay"
        old = {
            "timestamp": "2020-01-01T00:00:00Z",
            "type": "response_item",
            "payload": {
                "type": "message",
                "role": "user",
                "id": "old-message",
                "content": [
                    {
                        "type": "input_text",
                        "text": "[$html](/tmp/skills/html/SKILL.md)",
                    }
                ],
            },
        }
        current = {
            "timestamp": "2099-01-01T00:00:00Z",
            "type": "response_item",
            "payload": {
                "type": "message",
                "role": "user",
                "id": "current-message",
                "content": [
                    {
                        "type": "input_text",
                        "text": "[$show-me](/tmp/skills/show-me/SKILL.md)",
                    }
                ],
            },
        }
        first = fixtures / "first.jsonl"
        second = fixtures / "resumed.jsonl"
        write_jsonl(first, [old, current])
        write_jsonl(second, [old, current])
        result = self.cli(
            "collect",
            "--source",
            f"codex={first}",
            "--source",
            f"codex={second}",
        )
        self.assertIn("1 new uses", result.stdout)
        report = self.report()
        self.assertNotIn("html", report)
        self.assertEqual(report["show-me"]["total"], 1)

    def test_model_reads_dedupe_within_a_turn_but_not_across_turns(self) -> None:
        self.cli("init")
        cursor = self.root / "cursor-turns.jsonl"
        first_turn = [
            {"role": "user", "message": {"content": "first"}},
            {
                "role": "assistant",
                "message": {
                    "content": [
                        {
                            "type": "tool_use",
                            "name": "Read",
                            "input": {"path": "/tmp/skills/html/SKILL.md", "offset": 1},
                        }
                    ]
                },
            },
        ]
        write_jsonl(cursor, first_turn)
        source = f"cursor={cursor}"
        self.cli("collect", "--source", source)

        followups = [
            {
                "role": "assistant",
                "message": {
                    "content": [
                        {
                            "type": "tool_use",
                            "name": "ReadFile",
                            "input": {"path": "/tmp/skills/html/SKILL.md", "offset": 200},
                        }
                    ]
                },
            },
            {"role": "user", "message": {"content": "again"}},
            {
                "role": "assistant",
                "message": {
                    "content": [
                        {
                            "type": "tool_use",
                            "name": "Read",
                            "input": {"path": "/tmp/skills/html/SKILL.md"},
                        }
                    ]
                },
            },
        ]
        with cursor.open("a", encoding="utf-8") as handle:
            for record in followups:
                handle.write(json.dumps(record, separators=(",", ":")) + "\n")
        self.cli("collect", "--source", source)
        self.assertEqual(self.report()["html"]["total"], 2)

    def test_replaced_transcript_is_rescanned_without_duplicate_counts(self) -> None:
        self.cli("init")
        transcript = self.root / "replaced.jsonl"
        first = {
            "timestamp": "2099-01-01T00:00:00Z",
            "type": "response_item",
            "payload": {
                "type": "message",
                "role": "user",
                "id": "first-message",
                "content": [{"type": "input_text", "text": "[$html](/tmp/skills/html/SKILL.md)"}],
            },
        }
        second = {
            "timestamp": "2099-01-01T00:00:01Z",
            "type": "response_item",
            "payload": {
                "type": "message",
                "role": "user",
                "id": "second-message",
                "content": [{"type": "input_text", "text": "[$talk](/tmp/skills/talk/SKILL.md)"}],
            },
        }
        write_jsonl(transcript, [first])
        source = f"codex={transcript}"
        self.assertIn("1 new uses", self.cli("collect", "--source", source).stdout)
        replacement = transcript.with_suffix(".new")
        write_jsonl(replacement, [first, second])
        os.replace(replacement, transcript)
        self.assertIn("1 new uses", self.cli("collect", "--source", source).stdout)
        self.assertEqual(
            {name: row["total"] for name, row in self.report().items()},
            {"html": 1, "talk": 1},
        )


class SkillUsageGitSyncTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="skill-usage-git-test.")
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.fake_clean = self.root / "fake-git-crypt-clean"
        self.fake_smudge = self.root / "fake-git-crypt-smudge"
        self.fake_clean.write_text(
            "#!/bin/sh\nprintf '\\000GITCRYPT\\000'\ncat\n", encoding="utf-8"
        )
        self.fake_smudge.write_text(
            "#!/bin/sh\ndd bs=1 skip=10 2>/dev/null\n", encoding="utf-8"
        )
        self.fake_clean.chmod(0o700)
        self.fake_smudge.chmod(0o700)
        subprocess.run(
            ["git", "init", "--bare", str(self.remote)], check=True, capture_output=True
        )
        self.seed = self.root / "seed"
        self.seed.mkdir()
        git(self.seed, "init", "-b", "main")
        git(self.seed, "config", "user.name", "Skill Usage Test")
        git(self.seed, "config", "user.email", "skill-usage@example.invalid")
        (self.seed / "README.md").write_text("fixture\n", encoding="utf-8")
        (self.seed / ".gitattributes").write_text(
            "agents/skill-usage-batches/** filter=git-crypt diff=git-crypt\n",
            encoding="utf-8",
        )
        (self.seed / "agents").mkdir()
        (self.seed / "agents/skill-usage").write_text("#!/bin/sh\n", encoding="utf-8")
        git(self.seed, "add", ".gitattributes", "README.md", "agents/skill-usage")
        git(self.seed, "commit", "-m", "fixture")
        git(self.seed, "remote", "add", "origin", str(self.remote))
        git(self.seed, "push", "-u", "origin", "main")
        git(self.remote, "symbolic-ref", "HEAD", "refs/heads/main")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def clone(self, name: str, *, unlocked: bool = True) -> Path:
        checkout = self.root / name
        subprocess.run(
            ["git", "clone", str(self.remote), str(checkout)],
            check=True,
            text=True,
            capture_output=True,
        )
        git(checkout, "config", "user.name", "Skill Usage Test")
        git(checkout, "config", "user.email", "skill-usage@example.invalid")
        if unlocked:
            git(checkout, "config", "filter.git-crypt.required", "true")
            git(checkout, "config", "filter.git-crypt.clean", str(self.fake_clean))
            git(checkout, "config", "filter.git-crypt.smudge", str(self.fake_smudge))
        return checkout

    def cli(
        self, repo: Path, state: Path, *args: str, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "python3",
                str(SCRIPT),
                "--repo",
                str(repo),
                "--state-dir",
                str(state),
                *args,
            ],
            check=check,
            text=True,
            capture_output=True,
        )

    def test_two_replicas_publish_without_shared_file_conflicts(self) -> None:
        first = self.clone("first")
        second = self.clone("second")
        first_state = self.root / "first-state"
        second_state = self.root / "second-state"
        git(first, "config", "remote.pushDefault", "nonexistent")
        git(first, "config", "push.default", "matching")

        self.cli(first, first_state, "init")
        self.cli(
            first,
            first_state,
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
        )
        first_sync = self.cli(first, first_state, "sync", "--no-collect")
        self.assertIn("pushed agents/skill-usage-batches/", first_sync.stdout)

        self.cli(second, second_state, "init")
        self.cli(
            second,
            second_state,
            "record",
            "show-me",
            "--harness",
            "claude",
            "--invocation",
            "model",
        )
        second_sync = self.cli(second, second_state, "sync", "--no-collect")
        self.assertIn("pushed agents/skill-usage-batches/", second_sync.stdout)

        git(first, "pull", "--ff-only")
        batches = sorted((first / "agents/skill-usage-batches").glob("*/*.json"))
        self.assertEqual(len(batches), 2)
        replicas = {path.parent.name for path in batches}
        self.assertEqual(len(replicas), 2)

        report = json.loads(self.cli(first, first_state, "report", "--json").stdout)
        totals = {row["skill"]: row["total"] for row in report}
        self.assertEqual(totals, {"html": 1, "show-me": 1})

        no_op = self.cli(second, second_state, "sync", "--no-collect")
        self.assertIn("no pending uses", no_op.stdout)

    def test_locked_checkout_refuses_to_publish(self) -> None:
        checkout = self.clone("locked", unlocked=False)
        state = self.root / "locked-state"
        self.cli(checkout, state, "init")
        self.cli(
            checkout,
            state,
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
        )
        result = self.cli(
            checkout, state, "sync", "--no-collect", check=False
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unlocked with git-crypt", result.stderr)
        self.assertEqual(git(checkout, "rev-list", "--count", "origin/main..HEAD").stdout.strip(), "0")

    def test_plaintext_passthrough_filter_is_rejected(self) -> None:
        checkout = self.clone("passthrough")
        state = self.root / "passthrough-state"
        git(checkout, "config", "filter.git-crypt.clean", "cat # git-crypt")
        git(checkout, "config", "filter.git-crypt.smudge", "cat # git-crypt")
        self.cli(checkout, state, "init")
        self.cli(
            checkout,
            state,
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
        )
        result = self.cli(
            checkout, state, "sync", "--no-collect", check=False
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not encrypt the staged", result.stderr)
        self.assertEqual(git(checkout, "diff", "--cached", "--name-only").stdout, "")

    def test_prepared_state_recovers_an_already_created_batch_commit(self) -> None:
        checkout = self.clone("crash-recovery")
        state = self.root / "crash-state"
        self.cli(checkout, state, "init")
        self.cli(
            checkout,
            state,
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
        )
        self.cli(checkout, state, "sync", "--no-collect")

        previous = git(self.remote, "rev-parse", "HEAD^").stdout.strip()
        git(self.remote, "update-ref", "refs/heads/main", previous)
        with sqlite3.connect(state / "usage.sqlite3") as database:
            database.execute(
                "UPDATE batches SET status = 'prepared', commit_hash = NULL"
            )
            database.commit()

        recovered = self.cli(checkout, state, "sync", "--no-collect")
        self.assertIn("pushed agents/skill-usage-batches/", recovered.stdout)
        self.assertEqual(
            git(checkout, "rev-list", "--count", "origin/main..HEAD").stdout.strip(),
            "0",
        )

    def test_orphaned_batch_file_is_adopted_without_double_counting(self) -> None:
        checkout = self.clone("orphan-recovery")
        state = self.root / "orphan-state"
        self.cli(checkout, state, "init")
        self.cli(
            checkout,
            state,
            "record",
            "html",
            "--harness",
            "codex",
            "--invocation",
            "user",
        )
        with sqlite3.connect(state / "usage.sqlite3") as database:
            replica = database.execute(
                "SELECT value FROM meta WHERE key = 'replica_id'"
            ).fetchone()[0]
            day = database.execute("SELECT day FROM uses").fetchone()[0]
        payload = {
            "schema_version": 1,
            "replica_id": replica,
            "sequence": 1,
            "created_at": "2099-01-01T00:00:00Z",
            "counts": [
                {
                    "skill": "html",
                    "harness": "codex",
                    "invocation": "user",
                    "day": day,
                    "count": 1,
                }
            ],
        }
        encoded = (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode()
        digest = hashlib.sha256(encoded).hexdigest()[:12]
        batch = (
            checkout
            / "agents/skill-usage-batches"
            / replica
            / f"00000001-{digest}.json"
        )
        batch.parent.mkdir(parents=True)
        batch.write_bytes(encoded)

        before = json.loads(self.cli(checkout, state, "report", "--json").stdout)
        self.assertEqual(before[0]["total"], 1)
        synced = self.cli(checkout, state, "sync", "--no-collect")
        self.assertIn("pushed agents/skill-usage-batches/", synced.stdout)
        after = json.loads(self.cli(checkout, state, "report", "--json").stdout)
        self.assertEqual(after[0]["total"], 1)


if __name__ == "__main__":
    unittest.main()
