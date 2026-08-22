from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CLAUDE = REPO / "agents/skills/claude-dispatch/scripts/invoke.py"
CODEX = REPO / "agents/skills/codex-dispatch/scripts/invoke.py"
GROK = REPO / "agents/skills/grok-dispatch/scripts/invoke.py"
sys.path.insert(0, str(REPO / "agents/lib"))
import agent_dispatch_state as dispatch_state


FAKE_CLI = r"""#!/usr/bin/env python3
import json, os, pathlib, sys, uuid
from datetime import datetime, timezone
from urllib.parse import quote

log = pathlib.Path(os.environ["FAKE_LOG"])
with log.open("a") as h:
    h.write(json.dumps({
        "args": sys.argv[1:],
        "cwd": os.getcwd(),
        "CODEX_HOME": os.environ.get("CODEX_HOME"),
        "CLAUDE_CONFIG_DIR": os.environ.get("CLAUDE_CONFIG_DIR"),
        "GROK_HOME": os.environ.get("GROK_HOME"),
        "GROK_DISABLE_API_KEY_AUTH": os.environ.get("GROK_DISABLE_API_KEY_AUTH"),
        "sensitive": [k for k in (
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_BASE_URL",
            "XAI_API_KEY",
            "XAI_API_BASE_URL",
            "GROK_CODE_XAI_API_KEY",
            "GROK_CLI_CHAT_PROXY_BASE_URL",
        ) if k in os.environ],
    }) + "\n")
if sys.argv[1:3] == ["auth", "status"]:
    print(json.dumps({"loggedIn": True, "authMethod": "claude.ai", "subscriptionType": "max"}))
    raise SystemExit(0)
if sys.argv[1:] == ["models"]:
    print("You are logged in with grok.com.")
    raise SystemExit(0)
if os.environ.get("FAKE_FAIL") == "1":
    raise SystemExit(7)

name = pathlib.Path(sys.argv[0]).name
prompt = sys.stdin.buffer.read()
now = datetime.now(timezone.utc)


def assigned_session_id():
    args = sys.argv[1:]
    for flag in ("--session-id", "-s"):
        if flag in args:
            return args[args.index(flag) + 1]
    raise SystemExit("missing --session-id")


if name == "codex":
    out = pathlib.Path(sys.argv[sys.argv.index("-o") + 1])
    out.write_text("codex result")
    if os.environ.get("FAKE_NO_SESSION") == "1":
        raise SystemExit(0)
    home = pathlib.Path(os.environ["CODEX_HOME"])
    parent_id = str(uuid.uuid4())
    child_id = str(uuid.uuid4())
    day = home / "sessions" / f"{now:%Y}" / f"{now:%m}" / f"{now:%d}"
    day.mkdir(parents=True)
    stamp = now.strftime("%Y-%m-%dT%H-%M-%S")
    parent = day / f"rollout-{stamp}-{parent_id}.jsonl"
    child = day / f"rollout-{stamp}-{child_id}.jsonl"
    parent.write_text(
        json.dumps({
            "timestamp": now.isoformat(),
            "type": "session_meta",
            "payload": {
                "id": parent_id,
                "session_id": parent_id,
                "originator": "codex_exec",
                "source": "exec",
                "thread_source": "user",
                "cwd": os.getcwd(),
            },
        })
        + "\n"
        + json.dumps({"type": "response_item", "payload": {"text": prompt.decode(errors="replace")}})
        + "\n"
    )
    child.write_text(
        json.dumps({
            "timestamp": now.isoformat(),
            "type": "session_meta",
            "payload": {
                "id": child_id,
                "session_id": child_id,
                "originator": "codex_exec",
                "source": {"subagent": {"thread_spawn": {"parent_thread_id": parent_id, "depth": 1}}},
                "thread_source": "subagent",
            },
        })
        + "\n"
    )
elif name == "grok":
    sys.stdout.write("grok result")
    if os.environ.get("FAKE_NO_SESSION") == "1":
        raise SystemExit(0)
    session_id = assigned_session_id()
    home = pathlib.Path(os.environ["GROK_HOME"])
    cwd = pathlib.Path(os.getcwd()).resolve()
    session = home / "sessions" / quote(str(cwd), safe="") / session_id
    session.mkdir(parents=True)
    (session / "summary.json").write_text(json.dumps({"info": {"id": session_id, "cwd": str(cwd)}}))
    (session / "chat_history.jsonl").write_text(prompt.decode(errors="replace") + "\ngrok result\n")
    child = session / "subagents" / "child-id"
    child.mkdir(parents=True)
    (child / "meta.json").write_text(json.dumps({
        "parent_session_id": session_id,
        "child_session_id": "child-id",
    }))
else:
    sys.stdout.write("claude result")
    if os.environ.get("FAKE_NO_SESSION") == "1":
        raise SystemExit(0)
    session_id = assigned_session_id()
    home = pathlib.Path(os.environ["CLAUDE_CONFIG_DIR"])
    cwd = pathlib.Path(os.getcwd()).resolve()
    project = home / "projects" / str(cwd).replace("/", "-")
    project.mkdir(parents=True)
    (project / f"{session_id}.jsonl").write_text(json.dumps({
        "type": "user",
        "sessionId": session_id,
        "content": prompt.decode(errors="replace"),
    }) + "\n")
    (project / session_id / "subagents").mkdir(parents=True)
    (project / session_id / "subagents" / "agent-child.jsonl").write_text("{}\n")
    (project / session_id / "tool-results").mkdir(parents=True)
"""


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
        self.home = self.base / "home"
        self.state = self.base / "state"
        self.home.mkdir()
        self._write_auth()
        self._write_personal_decoys()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _write_secret(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        path.chmod(0o600)

    def _write_auth(self) -> None:
        self._write_secret(
            self.home / ".codex/auth.json",
            json.dumps({"auth_mode": "chatgpt", "tokens": {"access_token": "must-not-leak-codex"}}),
        )
        self._write_secret(
            self.home / ".claude/.credentials.json",
            json.dumps({"claudeAiOauth": {"accessToken": "must-not-leak-claude", "subscriptionType": "max"}}),
        )
        self._write_secret(self.home / ".claude.json", json.dumps({"hasCompletedOnboarding": True}))
        self._write_secret(
            self.home / ".grok/auth.json",
            json.dumps({"https://auth.x.ai::x": {"key": "must-not-leak-grok"}}),
        )
        self._write_secret(self.home / ".grok/agent_id", "agent-id\n")

    def _write_personal_decoys(self) -> None:
        decoy_codex = self.home / ".codex/sessions/1999/01/01"
        decoy_codex.mkdir(parents=True)
        (decoy_codex / "rollout-1999-01-01T23-59-59-decoy-parent.jsonl").write_text(
            json.dumps({
                "timestamp": "1999-01-01T23:59:59Z",
                "type": "session_meta",
                "payload": {
                    "id": "decoy-parent",
                    "originator": "codex_exec",
                    "source": "exec",
                    "thread_source": "user",
                },
            })
            + "\n"
        )
        decoy_claude = self.home / ".claude/projects/-tmp"
        decoy_claude.mkdir(parents=True)
        (decoy_claude / "decoy-session.jsonl").write_text("{}\n")
        decoy_grok = self.home / ".grok/sessions/%2Ftmp/decoy-session"
        decoy_grok.mkdir(parents=True)
        (decoy_grok / "summary.json").write_text(json.dumps({"info": {"id": "decoy-session"}}))

    def fake_cli(self, name: str) -> tuple[dict[str, str], Path]:
        bin_dir = self.base / f"{name}-bin"
        bin_dir.mkdir()
        log = self.base / f"{name}.jsonl"
        script = bin_dir / name
        script.write_text(FAKE_CLI)
        script.chmod(0o755)
        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{bin_dir}{os.pathsep}{env['PATH']}",
                "FAKE_LOG": str(log),
                "XDG_STATE_HOME": str(self.state),
                "HOME": str(self.home),
                "ANTHROPIC_API_KEY": "must-not-reach-child",
                "ANTHROPIC_BASE_URL": "https://wrong.example",
                "XAI_API_KEY": "must-not-reach-child",
                "XAI_API_BASE_URL": "https://wrong.example",
                "GROK_CODE_XAI_API_KEY": "must-not-reach-child",
                "GROK_CLI_CHAT_PROXY_BASE_URL": "https://wrong.example",
            }
        )
        env.pop("CODEX_HOME", None)
        env.pop("CLAUDE_CONFIG_DIR", None)
        env.pop("GROK_HOME", None)
        return env, log

    def run_script(
        self, script: Path, *extra: str, env: dict[str, str], output: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(script),
                str(self.prompt),
                "--output",
                str(output or self.output),
                *extra,
            ],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    def run_claude(self, *extra: str, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return self.run_script(CLAUDE, *extra, env=env)

    def transcript_line(self, result: subprocess.CompletedProcess[str]) -> Path:
        prefix = dispatch_state.TRANSCRIPT_PREFIX
        lines = [line[len(prefix) :] for line in result.stdout.splitlines() if line.startswith(prefix)]
        self.assertEqual(len(lines), 1, result.stdout)
        path = Path(lines[0])
        self.assertTrue(path.exists(), result.stdout)
        return path

    def assert_mode(self, path: Path, mode: int) -> None:
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), mode)

    def assert_isolated(self, path: Path) -> None:
        resolved = path.resolve()
        root = (self.state / "agent-dispatch").resolve()
        self.assertTrue(root in resolved.parents or resolved == root, resolved)
        self.assertNotIn(str(self.home / ".codex/sessions"), str(resolved))
        self.assertNotIn(str(self.home / ".claude/projects"), str(resolved))
        self.assertNotIn(str(self.home / ".grok/sessions"), str(resolved))

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
        self.assertNotIn("--no-session-persistence", invocation)
        self.assertIn("--session-id", invocation)
        self.assertTrue(Path(calls[1]["CLAUDE_CONFIG_DIR"]).is_relative_to(self.state / "agent-dispatch/claude"))

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

    def test_claude_prints_native_parent_transcript(self) -> None:
        env, log = self.fake_cli("claude")
        result = self.run_claude(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        transcript = self.transcript_line(result)
        self.assert_isolated(transcript)
        self.assertTrue(transcript.name.endswith(".jsonl"))
        self.assertIn("Give a compact answer.", transcript.read_text())
        session_id = json.loads(log.read_text().splitlines()[1])["args"]
        assigned = session_id[session_id.index("--session-id") + 1]
        self.assertEqual(transcript.stem, assigned)
        self.assertTrue((transcript.parent / assigned / "subagents" / "agent-child.jsonl").is_file())
        self.assertTrue((transcript.parent / assigned / "tool-results").is_dir())
        self.assertFalse((self.state / "claude-dispatch").exists())
        self.assert_mode(self.state / "agent-dispatch", 0o700)
        self.assert_mode(self.state / "agent-dispatch/claude", 0o700)
        self.assertNotIn("must-not-leak", result.stdout + result.stderr)

    def test_failed_claude_preserves_existing_output(self) -> None:
        env, _ = self.fake_cli("claude")
        env["FAKE_FAIL"] = "1"
        self.output.write_text("existing\n")
        result = self.run_claude(env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), "existing\n")

    def test_codex_closed_applies_best_effort_boundary(self) -> None:
        env, log = self.fake_cli("codex")
        result = self.run_script(CODEX, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(log.read_text().splitlines()[0])
        args = call["args"]
        for flag in ("--ignore-user-config", "--ignore-rules", "read-only"):
            self.assertIn(flag, args)
        self.assertNotIn("--ephemeral", args)
        self.assertNotEqual(call["cwd"], str(self.root))
        self.assertTrue(Path(call["CODEX_HOME"]).is_relative_to(self.state / "agent-dispatch/codex"))

    def test_codex_agentic_is_unrestricted(self) -> None:
        env, log = self.fake_cli("codex")
        result = self.run_script(
            CODEX,
            "--access",
            "agentic",
            "--root",
            str(self.root),
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        call = json.loads(log.read_text().splitlines()[0])
        args = call["args"]
        self.assertEqual(Path(args[args.index("-C") + 1]), self.root.resolve())
        self.assertIn("--dangerously-bypass-approvals-and-sandbox", args)
        self.assertNotIn("--approve-for-me", args)
        self.assertNotIn("--ephemeral", args)

    def test_codex_prints_parent_rollout_not_child_or_personal_decoy(self) -> None:
        env, _ = self.fake_cli("codex")
        result = self.run_script(CODEX, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        transcript = self.transcript_line(result)
        self.assert_isolated(transcript)
        meta = json.loads(transcript.read_text().splitlines()[0])
        self.assertEqual(meta["payload"]["thread_source"], "user")
        self.assertEqual(self.output.read_text(), "codex result")
        self.assertIn("Give a compact answer.", transcript.read_text())
        children = list(transcript.parent.glob("rollout-*.jsonl"))
        self.assertEqual(len(children), 2)
        self.assertNotEqual(transcript, self.home / ".codex/sessions/1999/01/01/rollout-1999-01-01T23-59-59-decoy-parent.jsonl")
        self.assert_mode(self.state / "agent-dispatch/codex", 0o700)
        self.assertEqual(stat.S_IMODE((self.state / "agent-dispatch/codex").iterdir().__next__().joinpath("auth.json").stat().st_mode), 0o600)
        self.assertNotIn("must-not-leak", result.stdout + result.stderr)

    def test_grok_closed_is_tool_off_isolated_and_subscription_routed(self) -> None:
        env, log = self.fake_cli("grok")
        result = self.run_script(GROK, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), "grok result")
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0]["args"], ["models"])
        self.assertEqual(calls[0]["sensitive"], [])
        self.assertEqual(calls[1]["sensitive"], [])
        self.assertEqual(calls[1]["GROK_DISABLE_API_KEY_AUTH"], "1")
        self.assertEqual(Path(calls[1]["GROK_HOME"]), (self.state / "agent-dispatch/grok").resolve())
        self.assertNotEqual(calls[1]["cwd"], str(self.root))
        invocation = calls[1]["args"]
        self.assertEqual(invocation[invocation.index("--tools") + 1], "")
        self.assertIn("--no-subagents", invocation)
        self.assertIn("--disable-web-search", invocation)
        self.assertIn("--verbatim", invocation)
        self.assertIn("--session-id", invocation)
        self.assertNotIn("--always-approve", invocation)

    def test_grok_agentic_is_unrestricted(self) -> None:
        env, log = self.fake_cli("grok")
        result = self.run_script(
            GROK,
            "--access",
            "agentic",
            "--root",
            str(self.root),
            env=env,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        invocation = calls[1]["args"]
        self.assertEqual(Path(calls[1]["cwd"]), self.root.resolve())
        self.assertEqual(Path(calls[1]["GROK_HOME"]), (self.state / "agent-dispatch/grok").resolve())
        self.assertIn("--always-approve", invocation)
        self.assertIn("bypassPermissions", invocation)
        self.assertNotIn("--no-subagents", invocation)
        self.assertNotIn("--disable-web-search", invocation)

    def test_grok_prints_assigned_session_not_personal_decoy(self) -> None:
        env, log = self.fake_cli("grok")
        result = self.run_script(GROK, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        transcript = self.transcript_line(result)
        self.assert_isolated(transcript)
        self.assertEqual(transcript.name, "summary.json")
        assigned = json.loads(log.read_text().splitlines()[1])["args"]
        session_id = assigned[assigned.index("--session-id") + 1]
        self.assertEqual(transcript.parent.name, session_id)
        self.assertTrue((transcript.parent / "subagents/child-id/meta.json").is_file())
        self.assertNotEqual(transcript, self.home / ".grok/sessions/%2Ftmp/decoy-session/summary.json")
        self.assert_mode(self.state / "agent-dispatch/grok/auth.json", 0o600)
        self.assertNotIn("must-not-leak", result.stdout + result.stderr)

    def test_missing_native_transcript_fails_closed(self) -> None:
        for script in (CLAUDE, CODEX, GROK):
            with self.subTest(script=script):
                env, _ = self.fake_cli(script.parents[1].name.removesuffix("-dispatch"))
                env["FAKE_NO_SESSION"] = "1"
                output = self.base / f"missing-{script.parents[1].name}.md"
                result = self.run_script(script, env=env, output=output)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn(dispatch_state.TRANSCRIPT_PREFIX, result.stdout)

    def test_concurrent_runs_resolve_assigned_sessions(self) -> None:
        env, _ = self.fake_cli("grok")

        def launch(index: int) -> subprocess.CompletedProcess[str]:
            output = self.base / f"concurrent-{index}.md"
            return self.run_script(GROK, env=env, output=output)

        with ThreadPoolExecutor(max_workers=2) as pool:
            first, second = tuple(pool.map(launch, (1, 2)))
        self.assertEqual(first.returncode, 0, first.stderr or first.stdout)
        self.assertEqual(second.returncode, 0, second.stderr or second.stdout)
        paths = {
            line[len(dispatch_state.TRANSCRIPT_PREFIX) :]
            for stdout in (first.stdout, second.stdout)
            for line in stdout.splitlines()
            if line.startswith(dispatch_state.TRANSCRIPT_PREFIX)
        }
        self.assertEqual(len(paths), 2)
        for raw in paths:
            path = Path(raw)
            self.assert_isolated(path)
            self.assertTrue(path.is_file())

    def test_claude_resolution_uses_session_id_not_cwd_guess(self) -> None:
        home = self.base / "isolated-claude"
        session_id = "4ea9b9c1-58a3-4f25-a308-df1d0217de1d"
        actual = home / "projects/-tmp-claude-dispatch-9p8w-cat" / f"{session_id}.jsonl"
        actual.parent.mkdir(parents=True)
        actual.write_text("{}\n")
        guessed = dispatch_state.claude_transcript_path(
            home, Path("/tmp/claude-dispatch.9p8w_cat"), session_id
        )
        self.assertNotEqual(guessed, actual)
        self.assertEqual(
            dispatch_state.resolve_claude_transcript(home, session_id), actual.resolve()
        )

    def test_codex_parent_resolution_rejects_ambiguity(self) -> None:
        home = self.base / "ambiguous-codex"
        day = home / "sessions/2026/08/22"
        day.mkdir(parents=True)
        for name in ("aaaa", "bbbb"):
            (day / f"rollout-2026-08-22T00-00-00-{name}.jsonl").write_text(
                json.dumps({
                    "type": "session_meta",
                    "payload": {
                        "id": name,
                        "originator": "codex_exec",
                        "source": "exec",
                        "thread_source": "user",
                    },
                })
                + "\n"
            )
        with self.assertRaises(FileNotFoundError):
            dispatch_state.resolve_codex_parent_rollout(home)

    def test_codex_parent_resolution_ignores_child_and_foreign_homes(self) -> None:
        home = self.base / "isolated-codex"
        day = home / "sessions/2026/08/22"
        day.mkdir(parents=True)
        parent = day / "rollout-2026-08-22T00-00-00-parent.jsonl"
        parent.write_text(
            json.dumps({
                "type": "session_meta",
                "payload": {
                    "id": "parent",
                    "originator": "codex_exec",
                    "source": "exec",
                    "thread_source": "user",
                },
            })
            + "\n"
        )
        (day / "rollout-2026-08-22T00-00-01-child.jsonl").write_text(
            json.dumps({
                "type": "session_meta",
                "payload": {
                    "id": "child",
                    "originator": "codex_exec",
                    "source": {"subagent": {"thread_spawn": {"parent_thread_id": "parent"}}},
                    "thread_source": "subagent",
                },
            })
            + "\n"
        )
        foreign = self.home / ".codex/sessions/2026/08/22/rollout-2026-08-22T23-59-59-newer.jsonl"
        foreign.parent.mkdir(parents=True)
        foreign.write_text(
            json.dumps({
                "type": "session_meta",
                "payload": {
                    "id": "newer",
                    "originator": "codex_exec",
                    "source": "exec",
                    "thread_source": "user",
                },
            })
            + "\n"
        )
        self.assertEqual(dispatch_state.resolve_codex_parent_rollout(home), parent.resolve())

    def test_removed_unrestricted_mode_is_rejected(self) -> None:
        for script in (CLAUDE, CODEX, GROK):
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

    def test_dispatchers_are_prompt_only_and_native_surface_aware(self) -> None:
        claude = (REPO / "agents/skills/claude-dispatch/SKILL.md").read_text()
        codex = (REPO / "agents/skills/codex-dispatch/SKILL.md").read_text()
        grok = (REPO / "agents/skills/grok-dispatch/SKILL.md").read_text()

        for skill in (claude, codex, grok):
            self.assertIn("ready prompt file", skill)
            self.assertIn("`Transcript: <absolute path>`", skill)
            self.assertIn("`result.md` remains the handoff", skill)
            self.assertIn("~/.local/state/agent-dispatch/", skill)
            self.assertIn("(references/transcripts.md)", skill)

        self.assertIn("disable-model-invocation: true", claude)
        self.assertIn("disable-codex-model-invocation: false", claude)
        self.assertNotIn("disable-model-invocation: true", codex)
        self.assertIn("disable-codex-model-invocation: true", codex)
        self.assertNotIn("disable-model-invocation", grok)
        self.assertNotIn("disable-codex-model-invocation", grok)
        self.assertIn("harness-owned execution session", grok)

    def test_detached_reference_resolves_inside_each_projected_skill(self) -> None:
        shared = (REPO / "agents/references/model-dispatch-detached.md").resolve()
        for name in ("claude-dispatch", "codex-dispatch", "grok-dispatch"):
            with self.subTest(name=name):
                skill_dir = REPO / f"agents/skills/{name}"
                reference = skill_dir / "references/detached.md"
                self.assertTrue(reference.is_symlink())
                self.assertEqual(reference.resolve(), shared)
                self.assertIn(
                    "(references/detached.md)",
                    (skill_dir / "SKILL.md").read_text(),
                )
                self.assertTrue((skill_dir / "references/transcripts.md").is_file())


if __name__ == "__main__":
    unittest.main()
