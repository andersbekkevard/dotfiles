import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import tiktoken


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "agents/skills/fleet/fable-counsel/scripts/counsel.py"
COMPOSER = REPO / "agents/skills/fleet/fable-counsel/scripts/compose_packet.py"
SKILL = REPO / "agents/skills/fleet/fable-counsel/SKILL.md"
OPENAI = REPO / "agents/skills/fleet/fable-counsel/agents/openai.yaml"


class FableCounselPacketTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        self.work = self.base / "counsel"
        self.work.mkdir()
        self.brief = self.work / "brief.md"
        self.brief.write_text(
            "Goal: choose the cleanest boundary.\nDirection: one deep module.\n"
        )
        self.output = self.work / "prompt.md"
        self.counsel = self.work / "fable.md"

    def run_packet(
        self,
        *args: str,
        mode: str | None = "challenge",
        dry_run: bool = True,
        env: dict[str, str] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        command = [
            sys.executable,
            str(SCRIPT),
            str(self.work),
            "--root",
            str(self.root),
        ]
        if mode is not None:
            command.extend(("--mode", mode))
        command.extend(args)
        if dry_run:
            command.append("--dry-run")
        return subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            env=env,
        )

    def packet_xml(self) -> ET.Element:
        text = self.output.read_text()
        return ET.fromstring(text[text.index("<counsel_packet") :])

    def fake_claude_environment(
        self, *, auth: str = "ok", response: str = "intercepted counsel"
    ) -> tuple[dict[str, str], Path]:
        fake_bin = self.base / "bin"
        fake_bin.mkdir(exist_ok=True)
        log = self.base / "claude-log.jsonl"
        claude = fake_bin / "claude"
        claude.write_text(
            """#!/usr/bin/env python3
import json
import os
import sys

entry = {
    "args": sys.argv[1:],
    "cwd": os.getcwd(),
    "sensitive": sorted(
        name for name in (
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_AUTH_TOKEN",
            "ANTHROPIC_BASE_URL",
            "CLAUDE_CODE_USE_BEDROCK",
            "CLAUDE_CODE_USE_VERTEX",
            "CLAUDE_CODE_USE_FOUNDRY",
        ) if name in os.environ
    ),
}
with open(os.environ["FAKE_CLAUDE_LOG"], "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry) + "\\n")
if sys.argv[1:] == ["auth", "status"]:
    if os.environ["FAKE_CLAUDE_AUTH"] == "ok":
        print(json.dumps({
            "loggedIn": True,
            "authMethod": "claude.ai",
            "subscriptionType": "pro",
        }))
    else:
        print(json.dumps({"loggedIn": False, "authMethod": "api"}))
    raise SystemExit(0)
sys.stdin.read()
response = os.environ["FAKE_CLAUDE_RESPONSE"]
if response == "FAIL":
    raise SystemExit(7)
print(response, end="")
"""
        )
        claude.chmod(0o755)
        environment = os.environ.copy()
        home = self.base / "home"
        home.mkdir(exist_ok=True)
        environment.update(
            {
                "HOME": str(home),
                "PATH": f"{fake_bin}{os.pathsep}{environment.get('PATH', '')}",
                "XDG_STATE_HOME": str(self.base / "state"),
                "FAKE_CLAUDE_LOG": str(log),
                "FAKE_CLAUDE_AUTH": auth,
                "FAKE_CLAUDE_RESPONSE": response,
                "ANTHROPIC_API_KEY": "must-not-pass",
                "ANTHROPIC_AUTH_TOKEN": "must-not-pass",
                "ANTHROPIC_BASE_URL": "must-not-pass",
                "CLAUDE_CODE_USE_BEDROCK": "1",
                "CLAUDE_CODE_USE_VERTEX": "1",
                "CLAUDE_CODE_USE_FOUNDRY": "1",
            }
        )
        environment.pop("CODEX_HOME", None)
        environment.pop("CODEX_THREAD_ID", None)
        return environment, log

    def archive_dirs(self) -> list[Path]:
        root = self.base / "state/fable-counsel/runs"
        return sorted(path for path in root.glob("*") if path.is_dir())

    def test_minimal_packet_is_standalone_and_reports_only_metadata(self) -> None:
        result = self.run_packet()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("You are advising Sol", self.output.read_text())
        self.assertIn("Mode: challenge", self.output.read_text())
        packet = self.packet_xml()
        self.assertEqual(packet.attrib["mode"], "challenge")
        self.assertEqual([child.tag for child in packet], ["context", "sol_brief"])
        self.assertIsNotNone(packet.find("sol_brief"))
        self.assertEqual(packet.find("sol_brief").attrib, {})
        self.assertIsNone(packet.find("user_intent"))
        self.assertEqual(packet.find("context").tag, "context")
        self.assertNotIn("Goal: choose", result.stdout)
        self.assertEqual(result.stdout, "Dry run: Claude not invoked\n")

    def test_propose_selects_independent_prompt(self) -> None:
        result = self.run_packet(mode="propose")
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = self.output.read_text()
        self.assertIn("Mode: propose", prompt)
        self.assertIn("Form an independent direction", prompt)
        self.assertIn("outside this packet", prompt)
        self.assertNotIn("Sol has supplied a formed direction", prompt)
        self.assertEqual(self.packet_xml().attrib["mode"], "propose")
        self.assertEqual(result.stdout, "Dry run: Claude not invoked\n")

    def test_prompt_exposes_independent_judgment_and_claim_provenance(self) -> None:
        result = self.run_packet()
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = self.output.read_text()
        for contract in (
            "Understanding: reconstruct the user's decision",
            "Independent view: state the direction you would choose",
            "Assessment of Sol: compare your view with Sol's causal case",
            "credible better direction absent from Sol's brief",
            "[packet-grounded], [inference], or [model-prior]",
            "observed facts through assumptions and mechanism",
            "verification signals, and falsifiers",
        ):
            self.assertIn(contract, prompt)

    def test_runner_requires_an_explicit_mode(self) -> None:
        result = self.run_packet(mode=None)
        self.assertEqual(result.returncode, 2)
        self.assertIn("--mode", result.stderr)
        self.assertFalse(self.output.exists())

    def test_modes_compose_in_parallel_without_cross_talk(self) -> None:
        runs = {}
        for mode, brief in (
            ("propose", "Goal: choose the cleanest boundary.\n"),
            (
                "challenge",
                "Goal: choose the cleanest boundary.\nDirection: one deep module.\n",
            ),
        ):
            work = self.base / mode
            work.mkdir()
            (work / "brief.md").write_text(brief)
            command = [
                sys.executable,
                str(SCRIPT),
                str(work),
                "--root",
                str(self.root),
                "--mode",
                mode,
                "--dry-run",
            ]
            runs[mode] = (
                work,
                subprocess.Popen(
                    command,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                ),
            )

        for mode, (work, process) in runs.items():
            stdout, stderr = process.communicate()
            self.assertEqual(process.returncode, 0, stderr)
            packet_text = (work / "prompt.md").read_text()
            packet = ET.fromstring(packet_text[packet_text.index("<counsel_packet") :])
            self.assertEqual(packet.attrib["mode"], mode)
            self.assertEqual(stdout, "Dry run: Claude not invoked\n")

        propose = (runs["propose"][0] / "prompt.md").read_text()
        challenge = (runs["challenge"][0] / "prompt.md").read_text()
        self.assertNotIn("Direction: one deep module", propose)
        self.assertIn("Direction: one deep module", challenge)

    def test_intent_anchors_and_evidence_are_distinct_and_precede_brief(self) -> None:
        intent = self.work / "user-intent.md"
        intent.write_text("Build a lightweight source of wise outside judgment.\n")
        anchors = self.work / "user-anchors.md"
        anchors.write_text("Fresh eyes matter more than mechanical review.\n")
        result = self.run_packet()
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.packet_xml()
        self.assertEqual(
            [child.tag for child in packet],
            ["user_intent", "verbatim_user_anchors", "context", "sol_brief"],
        )
        self.assertIn("lightweight source", packet.findtext("user_intent"))
        self.assertNotIn("Fresh eyes matter", packet.findtext("user_intent"))
        self.assertIn("Fresh eyes matter", packet.findtext("verbatim_user_anchors"))
        self.assertEqual(packet.find("user_intent").attrib, {})
        self.assertEqual(packet.find("verbatim_user_anchors").attrib, {})
        self.assertEqual(result.stdout, "Dry run: Claude not invoked\n")
        self.assertNotIn("Fresh eyes matter", result.stdout)

    def test_repository_model_is_distinct_and_precedes_evidence_and_brief(self) -> None:
        (self.work / "repo-model.md").write_text(
            "Module: planner.py:10-40\nInvariant: one owner for scheduling.\n"
        )
        (self.root / "planner.py").write_text(
            "def schedule():\n    return 'one owner'\n"
        )
        result = self.run_packet("--doc", "planner.py")
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.packet_xml()
        self.assertEqual(
            [child.tag for child in packet],
            ["repository_model", "context", "sol_brief"],
        )
        self.assertIn("one owner for scheduling", packet.findtext("repository_model"))
        self.assertEqual(packet.find("repository_model").attrib, {})

    def test_user_anchors_require_reconstructed_intent(self) -> None:
        anchors = self.work / "user-anchors.md"
        anchors.write_text("Exact user wording.\n")
        result = self.run_packet()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --user-intent", result.stderr)

    def test_mixed_fidelity_preserves_xml_and_exact_excerpt(self) -> None:
        document = self.root / "plan.md"
        document.write_text("A < B & C > D\nsecond line\n")
        code = self.root / "module.py"
        code.write_text("one\ntwo\nthree\nfour\n")
        digest = self.base / "terra-runtime.md"
        digest.write_text("Summary from `module.py:1-4`: the boundary is cohesive.\n")

        result = self.run_packet(
            "--doc",
            "plan.md",
            "--excerpt",
            "module.py:2-3",
            "--digest",
            str(digest),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.packet_xml()
        self.assertEqual(
            packet.findtext("context/document"), "\nA < B & C > D\nsecond line\n\n    "
        )
        self.assertEqual(packet.findtext("context/excerpt"), "\ntwo\nthree\n\n    ")
        self.assertIn("boundary is cohesive", packet.findtext("context/digest"))
        self.assertEqual(
            packet.find("context/document").attrib,
            {"path": "plan.md"},
        )
        self.assertEqual(
            packet.find("context/excerpt").attrib,
            {"path": "module.py", "lines": "2-3"},
        )
        self.assertEqual(
            packet.find("context/digest").attrib,
            {"name": "terra-runtime"},
        )
        for noise in ("bytes=", "sha256=", "content_encoding="):
            self.assertNotIn(noise, self.output.read_text())

    def test_excerpt_bounds_fail_without_clipping(self) -> None:
        (self.root / "module.py").write_text("one\ntwo\n")
        result = self.run_packet("--excerpt", "module.py:2-3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeds file length", result.stderr)
        self.assertFalse(self.output.exists())

    def test_repository_evidence_must_be_relative_and_contained(self) -> None:
        outside = self.base / "outside.md"
        outside.write_text("outside\n")
        for path in (str(outside), "../outside.md"):
            with self.subTest(path=path):
                result = self.run_packet("--doc", path)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("repo-relative", result.stderr)

    def test_symlinked_repository_evidence_is_rejected(self) -> None:
        target = self.root / "target.md"
        target.write_text("target\n")
        (self.root / "link.md").symlink_to(target)
        result = self.run_packet("--doc", "link.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink component", result.stderr)

    def test_secret_paths_and_values_are_rejected(self) -> None:
        (self.root / ".env").write_text("SAFE_NAME=example\n")
        result = self.run_packet("--doc", ".env")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sensitive repository path", result.stderr)

        secret = self.root / "notes.md"
        secret.write_text("api_key = 'abcdefghijklmnopqrstuvwxyz123456'\n")
        result = self.run_packet("--doc", "notes.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("secret-like content", result.stderr)

    def test_safe_example_env_file_is_allowed(self) -> None:
        (self.root / ".env.example").write_text("SERVICE_URL=https://example.test\n")
        result = self.run_packet("--doc", ".env.example")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SERVICE_URL", self.packet_xml().findtext("context/document"))

    def test_redacted_document_preserves_fidelity_without_weakening_scan(self) -> None:
        redacted = self.base / "redacted-auth.md"
        redacted.write_text(
            "Original: src/auth.py\nRedactions: credential value\n\n"
            "credential = '[REDACTED]'\n"
        )
        result = self.run_packet("--redacted", str(redacted))
        self.assertEqual(result.returncode, 0, result.stderr)
        item = self.packet_xml().find("context/redacted_document")
        self.assertEqual(
            item.attrib,
            {"name": "redacted-auth", "redacted": "true"},
        )
        self.assertIn("Original: src/auth.py", item.text)

    def test_runner_sanitizes_and_isolates_both_claude_calls(self) -> None:
        environment, log = self.fake_claude_environment()
        result = self.run_packet(dry_run=False, env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.counsel.read_text(), "intercepted counsel")
        prompt_tokens = len(
            tiktoken.get_encoding("o200k_base").encode(self.output.read_text())
        )
        self.assertEqual(
            result.stdout,
            (
                f"Counsel: {self.counsel.resolve()}\n"
                "Fable Council mode: challenge | access: packet | "
                f"prompt: {prompt_tokens:,} tokens\n"
            ).replace(",", " "),
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0]["args"], ["auth", "status"])
        self.assertEqual(calls[0]["sensitive"], [])
        self.assertEqual(calls[1]["sensitive"], [])
        self.assertEqual(calls[0]["cwd"], calls[1]["cwd"])
        self.assertNotEqual(Path(calls[0]["cwd"]), self.root)
        self.assertNotEqual(Path(calls[0]["cwd"]), self.work)
        invocation = calls[1]["args"]
        self.assertIn("--safe-mode", invocation)
        self.assertIn("--strict-mcp-config", invocation)
        self.assertNotIn("--setting-sources", invocation)
        self.assertEqual(invocation[invocation.index("--tools") + 1], "")
        self.assertNotIn("--dangerously-skip-permissions", invocation)
        self.assertEqual(invocation[invocation.index("--model") + 1], "claude-fable-5")
        self.assertEqual(invocation[invocation.index("--effort") + 1], "high")

    def test_open_runner_uses_repo_root_and_unrestricted_builtin_tools(self) -> None:
        environment, log = self.fake_claude_environment()
        result = self.run_packet("--open", dry_run=False, env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.counsel.read_text(), "intercepted counsel")
        self.assertIn("Access: open", self.output.read_text())
        self.assertIn("as many tool calls", self.output.read_text())
        self.assertIn("[tool-grounded]", self.output.read_text())

        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0]["cwd"], str(self.root.resolve()))
        self.assertEqual(calls[1]["cwd"], str(self.root.resolve()))
        invocation = calls[1]["args"]
        self.assertIn("--safe-mode", invocation)
        self.assertIn("--strict-mcp-config", invocation)
        self.assertIn("--disallowedTools", invocation)
        self.assertEqual(invocation[invocation.index("--tools") + 1], "default")
        self.assertIn("--dangerously-skip-permissions", invocation)
        self.assertNotIn("--permission-mode", invocation)
        self.assertIn("Fable Council mode: challenge | access: open |", result.stdout)

        manifest = json.loads(
            (self.archive_dirs()[0] / "manifest.json").read_text()
        )
        self.assertEqual(manifest["access"], "open")

    def test_completed_run_is_privately_archived_with_codex_attribution(self) -> None:
        environment, _ = self.fake_claude_environment()
        (self.work / "user-intent.md").write_text("Choose a durable boundary.\n")
        (self.work / "user-anchors.md").write_text("Keep the feedback loop private.\n")
        (self.work / "repo-model.md").write_text(
            "Archive owner: counsel.py. Verified by test_fable_counsel.py.\n"
        )
        (self.root / "evidence.md").write_text(
            "Observed behavior: one archive per run.\n"
        )
        thread_id = "019f58ed-db1c-7ca3-aeec-fbf3d70a2a0a"
        rollout = (
            Path(environment["HOME"])
            / ".codex/sessions/2026/07/13"
            / f"rollout-2026-07-13T02-43-31-{thread_id}.jsonl"
        )
        rollout.parent.mkdir(parents=True)
        rollout.write_text('{"event":"before counsel"}\n')
        environment["CODEX_THREAD_ID"] = thread_id

        result = self.run_packet("--doc", "evidence.md", dry_run=False, env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        archives = self.archive_dirs()
        self.assertEqual(len(archives), 1)
        run = archives[0]
        manifest = json.loads((run / "manifest.json").read_text())
        prompt_tokens = len(
            tiktoken.get_encoding("o200k_base").encode(self.output.read_text())
        )

        self.assertEqual(manifest["schema_version"], 4)
        self.assertEqual(manifest["status"], "completed")
        self.assertEqual(manifest["mode"], "challenge")
        self.assertEqual(manifest["access"], "packet")
        self.assertEqual(manifest["effort"], "high")
        self.assertEqual(manifest["prompt_tokens"], prompt_tokens)
        self.assertEqual(
            set(manifest["prompt_sections"]),
            {
                "instructions",
                "user_intent",
                "user_anchors",
                "repository_model",
                "context",
                "sol_brief",
                "structure",
            },
        )
        self.assertEqual(sum(manifest["prompt_sections"].values()), prompt_tokens)
        for section in (
            "instructions",
            "user_intent",
            "user_anchors",
            "repository_model",
            "context",
            "sol_brief",
            "structure",
        ):
            self.assertGreater(manifest["prompt_sections"][section], 0)
        self.assertEqual(manifest["token_encoding"], "o200k_base")
        self.assertEqual(
            manifest["prompt_sha256"],
            hashlib.sha256(self.output.read_bytes()).hexdigest(),
        )
        self.assertEqual(
            manifest["response_sha256"],
            hashlib.sha256(b"intercepted counsel").hexdigest(),
        )
        self.assertEqual(manifest["repository"]["root"], str(self.root.resolve()))
        self.assertEqual(manifest["codex"]["thread_id"], thread_id)
        self.assertEqual(manifest["codex"]["resolution"], "resolved")
        self.assertEqual(manifest["codex"]["rollout_path"], str(rollout.resolve()))
        self.assertEqual(
            manifest["codex"]["rollout_byte_offset"], rollout.stat().st_size
        )
        self.assertEqual((run / "prompt.md").read_text(), self.output.read_text())
        self.assertEqual((run / "fable.md").read_text(), "intercepted counsel")
        self.assertEqual(run.stat().st_mode & 0o777, 0o700)
        for artifact in (run / "prompt.md", run / "fable.md", run / "manifest.json"):
            self.assertEqual(artifact.stat().st_mode & 0o777, 0o600)

    def test_dry_run_writes_packet_without_calling_claude(self) -> None:
        environment, log = self.fake_claude_environment()
        result = self.run_packet(env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.output.is_file())
        self.assertFalse(self.counsel.exists())
        self.assertFalse(log.exists())
        self.assertIn("Dry run: Claude not invoked", result.stdout)
        self.assertFalse((self.work / ".packet-metadata.json").exists())
        self.assertEqual(self.archive_dirs(), [])

    def test_subscription_failure_stops_before_counsel(self) -> None:
        environment, log = self.fake_claude_environment(auth="bad")
        result = self.run_packet(dry_run=False, env=environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must use a claude.ai subscription", result.stderr)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual([call["args"] for call in calls], [["auth", "status"]])
        self.assertFalse(self.counsel.exists())
        archives = self.archive_dirs()
        self.assertEqual(len(archives), 1)
        manifest = json.loads((archives[0] / "manifest.json").read_text())
        self.assertEqual(manifest["status"], "failed")
        self.assertIn("claude.ai subscription", manifest["failure"])
        self.assertFalse((archives[0] / "fable.md").exists())

    def test_failed_counsel_preserves_existing_output(self) -> None:
        self.counsel.write_text("existing\n")
        environment, _ = self.fake_claude_environment(response="FAIL")
        result = self.run_packet(dry_run=False, env=environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exited with status 7", result.stderr)
        self.assertEqual(self.counsel.read_text(), "existing\n")
        archives = self.archive_dirs()
        self.assertEqual(len(archives), 1)
        manifest = json.loads((archives[0] / "manifest.json").read_text())
        self.assertEqual(manifest["status"], "failed")
        self.assertIn("exited with status 7", manifest["failure"])
        self.assertFalse((archives[0] / "fable.md").exists())

    def test_concurrent_runs_get_distinct_archives(self) -> None:
        environment, _ = self.fake_claude_environment()
        processes = []
        for mode in ("propose", "challenge"):
            work = self.base / f"archive-{mode}"
            work.mkdir()
            (work / "brief.md").write_text(f"Goal: test {mode}.\n")
            command = [
                sys.executable,
                str(SCRIPT),
                str(work),
                "--root",
                str(self.root),
                "--mode",
                mode,
            ]
            processes.append(
                (
                    mode,
                    subprocess.Popen(
                        command,
                        text=True,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        env=environment,
                    ),
                )
            )

        for mode, process in processes:
            stdout, stderr = process.communicate()
            self.assertEqual(process.returncode, 0, stderr)
            self.assertIn(
                f"Fable Council mode: {mode} | access: packet | prompt: ", stdout
            )

        archives = self.archive_dirs()
        self.assertEqual(len(archives), 2)
        manifests = [
            json.loads((run / "manifest.json").read_text()) for run in archives
        ]
        self.assertEqual({item["mode"] for item in manifests}, {"propose", "challenge"})
        self.assertEqual(len({item["run_id"] for item in manifests}), 2)

    def test_runner_rejects_model_override(self) -> None:
        result = self.run_packet("--model", "other")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unrecognized arguments", result.stderr)

    def test_help_is_compact_and_complete(self) -> None:
        outputs = []
        for flag in ("-h", "--help"):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), flag],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            outputs.append(result.stdout)
        self.assertEqual(outputs[0], outputs[1])
        help_text = outputs[0]
        for fragment in (
            "WORK_DIR",
            "--root",
            "--mode",
            "propose",
            "challenge",
            "--doc",
            "--excerpt",
            "--redacted",
            "--digest",
            "--effort",
            "--open",
            "--dry-run",
            "repo-model.md",
        ):
            self.assertIn(fragment, help_text)
        tokens = len(tiktoken.get_encoding("o200k_base").encode(help_text))
        self.assertLessEqual(tokens, 160)

    def test_skill_makes_runner_an_opaque_execution_boundary(self) -> None:
        skill = SKILL.read_text()
        self.assertIn("repo-relative evidence paths", skill)
        self.assertIn("Treat the runner as opaque", skill)
        self.assertIn("open `scripts/` only to change or audit the runner", skill)
        self.assertIn(
            "reproducing the runner's `Fable Council mode` line verbatim", skill
        )

    def test_skill_requires_explicit_anders_authorization_for_open_access(self) -> None:
        skill = SKILL.read_text()
        for contract in (
            "Open execution is an explicit Anders-only authorization",
            "Pass `--open` only",
            "`allow tool calls`",
            "Never infer",
            "open execution from task size",
            "`--dangerously-skip-permissions`",
            "no tool-call or turn limit",
        ):
            self.assertIn(contract, skill)

    def test_skill_requires_decision_local_model_and_causal_challenge(self) -> None:
        skill = SKILL.read_text()
        for contract in (
            "write `repo-model.md` as",
            "relevant modules and interfaces",
            "`Causal case`: observed facts, assumptions, mechanism",
            "verification signals, and falsifiers",
            "credible missing alternative",
            "`[packet-grounded]`, `[inference]`, or `[model-prior]`",
        ):
            self.assertIn(contract, skill)

    def test_explicitly_invoked_skill_routes_mode_from_decision_state(self) -> None:
        skill = SKILL.read_text()
        self.assertIn("if Fable were unavailable", skill)
        self.assertIn("yes selects `challenge`; a no selects `propose`", skill)
        self.assertIn("Ambiguity selects `propose`", skill)
        self.assertIn("disable-model-invocation: true", skill)
        self.assertNotIn("disable-codex-model-invocation", skill)
        self.assertIn("infer the mode from context", OPENAI.read_text())
        self.assertIn("allow_implicit_invocation: false", OPENAI.read_text())

    def test_legacy_modes_are_absent_from_the_runtime_surface(self) -> None:
        for path in (SKILL, SCRIPT, COMPOSER, OPENAI):
            text = path.read_text().lower()
            with self.subTest(path=path):
                self.assertNotIn("cold-read", text)
                self.assertNotIn("cold read", text)
                self.assertNotIn("plan-counsel", text)
                self.assertNotIn("plan counsel", text)

    def test_invalid_utf8_and_nul_are_rejected(self) -> None:
        for name, data, expected in (
            ("invalid.md", b"\xff\xfe", "not valid UTF-8"),
            ("binary.md", b"safe" + b"\0" + b"later", "is binary"),
        ):
            with self.subTest(name=name):
                (self.root / name).write_bytes(data)
                result = self.run_packet("--doc", name)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stderr)

    def test_token_limit_failure_preserves_existing_output(self) -> None:
        self.output.write_text("existing\n")
        result = subprocess.run(
            [
                sys.executable,
                str(COMPOSER),
                "--root",
                str(self.root),
                "--mode",
                "challenge",
                "--brief",
                str(self.brief),
                "--output",
                str(self.output),
                "--max-total-tokens",
                "1",
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeding --max-total-tokens", result.stderr)
        self.assertEqual(self.output.read_text(), "existing\n")


if __name__ == "__main__":
    unittest.main()
