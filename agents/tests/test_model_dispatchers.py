from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CLAUDE = REPO / "agents/skills/claude-dispatch/scripts/invoke.py"
CODEX = REPO / "agents/skills/codex-dispatch/scripts/invoke.py"


class DispatcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.prompt = self.base / "prompt.md"
        self.prompt.write_text("Give a compact answer.\n")
        self.output = self.base / "result.md"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def fake_cli(self, name: str) -> tuple[dict[str, str], Path]:
        bin_dir = self.base / f"{name}-bin"
        bin_dir.mkdir()
        log = self.base / f"{name}.jsonl"
        script = bin_dir / name
        script.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "log = pathlib.Path(os.environ['FAKE_LOG'])\n"
            "with log.open('a') as h:\n"
            "  h.write(json.dumps({'args': sys.argv[1:], 'cwd': os.getcwd(), "
            "'sensitive': [k for k in ('ANTHROPIC_API_KEY','ANTHROPIC_BASE_URL') if k in os.environ]}) + '\\n')\n"
            "if sys.argv[1:3] == ['auth', 'status']:\n"
            "  print(json.dumps({'loggedIn': True, 'authMethod': 'claude.ai', 'subscriptionType': 'max'}))\n"
            "  raise SystemExit(0)\n"
            "data = sys.stdin.buffer.read()\n"
            "if os.environ.get('FAKE_FAIL') == '1': raise SystemExit(7)\n"
            "if pathlib.Path(sys.argv[0]).name == 'codex':\n"
            "  out = pathlib.Path(sys.argv[sys.argv.index('-o') + 1]); out.write_text('codex result')\n"
            "else:\n"
            "  sys.stdout.write('claude result')\n"
        )
        script.chmod(0o755)
        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{bin_dir}{os.pathsep}{env['PATH']}",
                "FAKE_LOG": str(log),
                "XDG_STATE_HOME": str(self.base / "state"),
                "HOME": str(self.base / "home"),
                "ANTHROPIC_API_KEY": "must-not-reach-child",
                "ANTHROPIC_BASE_URL": "https://wrong.example",
            }
        )
        return env, log

    def run_claude(self, *extra: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(CLAUDE),
                str(self.prompt),
                "--output",
                str(self.output),
                *extra,
            ],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    def test_claude_closed_is_hard_tool_off_and_isolated(self) -> None:
        env, log = self.fake_cli("claude")
        result = self.run_claude(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), "claude result")
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0]["sensitive"], [])
        self.assertEqual(calls[1]["sensitive"], [])
        self.assertEqual(calls[0]["cwd"], calls[1]["cwd"])
        self.assertNotEqual(calls[1]["cwd"], str(self.root))
        invocation = calls[1]["args"]
        self.assertEqual(invocation[invocation.index("--tools") + 1], "")
        self.assertNotIn("--dangerously-skip-permissions", invocation)

    def test_claude_agentic_is_unrestricted(self) -> None:
        env, log = self.fake_cli("claude")
        result = self.run_claude(
            "--access",
            "agentic",
            "--root",
            str(self.root),
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(Path(calls[1]["cwd"]), self.root.resolve())
        invocation = calls[1]["args"]
        self.assertIn("--dangerously-skip-permissions", invocation)
        self.assertNotIn("--permission-mode", invocation)

    def test_claude_archives_private_prompt_and_result(self) -> None:
        env, _ = self.fake_cli("claude")
        result = self.run_claude(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        runs = list((self.base / "state/claude-dispatch/runs").iterdir())
        self.assertEqual(len(runs), 1)
        run = runs[0]
        manifest = json.loads((run / "manifest.json").read_text())
        self.assertEqual(manifest["status"], "completed")
        self.assertEqual(
            manifest["prompt_sha256"], hashlib.sha256(self.prompt.read_bytes()).hexdigest()
        )
        self.assertEqual(run.stat().st_mode & 0o777, 0o700)
        for artifact in ("prompt.md", "result.md", "manifest.json"):
            self.assertEqual((run / artifact).stat().st_mode & 0o777, 0o600)

    def test_failed_claude_preserves_existing_output(self) -> None:
        env, _ = self.fake_cli("claude")
        env["FAKE_FAIL"] = "1"
        self.output.write_text("existing\n")
        result = self.run_claude(env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), "existing\n")

    def test_codex_closed_applies_best_effort_boundary(self) -> None:
        env, log = self.fake_cli("codex")
        result = subprocess.run(
            [
                sys.executable,
                str(CODEX),
                str(self.prompt),
                "--output",
                str(self.output),
            ],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(log.read_text().splitlines()[0])
        args = call["args"]
        for flag in ("--ephemeral", "--ignore-user-config", "--ignore-rules", "read-only"):
            self.assertIn(flag, args)
        self.assertNotEqual(call["cwd"], str(self.root))

    def test_codex_agentic_is_unrestricted(self) -> None:
        env, log = self.fake_cli("codex")
        result = subprocess.run(
            [
                sys.executable,
                str(CODEX),
                str(self.prompt),
                "--output",
                str(self.output),
                "--access",
                "agentic",
                "--root",
                str(self.root),
            ],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(log.read_text().splitlines()[0])
        args = call["args"]
        self.assertEqual(Path(args[args.index("-C") + 1]), self.root.resolve())
        self.assertIn("--dangerously-bypass-approvals-and-sandbox", args)
        self.assertNotIn("--approve-for-me", args)

    def test_removed_unrestricted_mode_is_rejected(self) -> None:
        for script in (CLAUDE, CODEX):
            with self.subTest(script=script):
                result = subprocess.run(
                    [
                        sys.executable,
                        str(script),
                        str(self.prompt),
                        "--output",
                        str(self.output),
                        "--access",
                        "unrestricted",
                    ],
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 2)
                self.assertIn("invalid choice", result.stderr)

    def test_both_skills_are_user_invoked_and_prompt_only(self) -> None:
        for name in ("claude-dispatch", "codex-dispatch"):
            skill = (REPO / f"agents/skills/{name}/SKILL.md").read_text()
            policy = (REPO / f"agents/skills/{name}/agents/openai.yaml").read_text()
            self.assertIn("disable-model-invocation: true", skill)
            self.assertIn("ready prompt file", skill)
            self.assertIn("allow_implicit_invocation: false", policy)


if __name__ == "__main__":
    unittest.main()
