from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
WAVE = REPO / "agents/skills/model-wave/scripts/run.py"


class ModelWaveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.skills = self.base / "skills"
        self.skills.mkdir()
        self.prompt = self.base / "prompt.md"
        self.prompt.write_text("Give an independent answer.\n")
        self.results = self.base / "wave.json"
        self.calls = self.base / "calls.jsonl"
        for provider in ("claude", "codex", "grok"):
            script_dir = self.skills / f"{provider}-dispatch/scripts"
            script_dir.mkdir(parents=True)
            script = script_dir / "invoke.py"
            script.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, pathlib, sys, time\n"
                "args = sys.argv[1:]\n"
                "with pathlib.Path(os.environ['WAVE_CALLS']).open('a') as h:\n"
                "  h.write(json.dumps({'provider': pathlib.Path(__file__).parents[1].name, 'args': args}) + '\\n')\n"
                "time.sleep(float(os.environ.get('WAVE_SLEEP', '0')))\n"
                "provider = pathlib.Path(__file__).parents[1].name.removesuffix('-dispatch')\n"
                "if os.environ.get('WAVE_FAIL') in (provider, 'all'): raise SystemExit(7)\n"
                "out = pathlib.Path(args[args.index('--output') + 1])\n"
                "out.parent.mkdir(parents=True, exist_ok=True)\n"
                "out.write_text(provider + ' result')\n"
            )
            script.chmod(0o755)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def manifest(self) -> Path:
        manifest = self.base / "wave-input.json"
        manifest.write_text(
            json.dumps(
                {
                    "runs": [
                        {
                            "id": provider,
                            "provider": provider,
                            "prompt": str(self.prompt),
                            "output": str(self.base / f"{provider}.md"),
                            "access": "closed",
                            "model": f"{provider}-model",
                            "effort": "high",
                        }
                        for provider in ("claude", "codex", "grok")
                    ]
                }
            )
        )
        return manifest

    def run_wave(
        self,
        *extra: str,
        fail: str | None = None,
        sleep: str = "0",
        manifest: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment.update(
            {
                "MODEL_WAVE_SKILLS_ROOT": str(self.skills),
                "WAVE_CALLS": str(self.calls),
                "WAVE_SLEEP": sleep,
            }
        )
        if fail:
            environment["WAVE_FAIL"] = fail
        return subprocess.run(
            [
                sys.executable,
                str(WAVE),
                str(manifest or self.manifest()),
                "--result",
                str(self.results),
                *extra,
            ],
            text=True,
            capture_output=True,
            env=environment,
            check=False,
        )

    def test_runs_all_lanes_concurrently_through_provider_dispatchers(self) -> None:
        started = time.monotonic()
        result = self.run_wave(sleep="0.25")
        elapsed = time.monotonic() - started

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(elapsed, 0.65)
        report = json.loads(self.results.read_text())
        self.assertEqual(report["status"], "completed")
        self.assertEqual(
            {lane["status"] for lane in report["runs"]}, {"completed"}
        )
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), 3)
        for call in calls:
            args = call["args"]
            self.assertIn("--access", args)
            self.assertIn("closed", args)
            self.assertIn("--model", args)
            self.assertIn("--effort", args)

    def test_partial_failure_is_visible_without_discarding_other_results(self) -> None:
        result = self.run_wave(fail="grok")

        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.results.read_text())
        self.assertEqual(report["status"], "partial")
        statuses = {lane["id"]: lane["status"] for lane in report["runs"]}
        self.assertEqual(
            statuses, {"claude": "completed", "codex": "completed", "grok": "failed"}
        )
        self.assertEqual((self.base / "claude.md").read_text(), "claude result")
        self.assertEqual((self.base / "codex.md").read_text(), "codex result")
        self.assertFalse((self.base / "grok.md").exists())

    def test_all_failed_wave_returns_nonzero_with_a_result(self) -> None:
        result = self.run_wave(fail="all")

        self.assertNotEqual(result.returncode, 0)
        report = json.loads(self.results.read_text())
        self.assertEqual(report["status"], "failed")
        self.assertEqual(
            {lane["status"] for lane in report["runs"]}, {"failed"}
        )

    def test_agentic_lane_requires_an_explicit_root(self) -> None:
        manifest = self.manifest()
        data = json.loads(manifest.read_text())
        data["runs"][0]["access"] = "agentic"
        manifest.write_text(json.dumps(data))

        result = self.run_wave(manifest=manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root", result.stderr.lower())
        self.assertFalse(self.results.exists())

    def test_artifacts_cannot_overwrite_an_input(self) -> None:
        manifest = self.manifest()
        data = json.loads(manifest.read_text())
        data["runs"][0]["output"] = str(self.prompt)
        manifest.write_text(json.dumps(data))

        result = self.run_wave(manifest=manifest)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("overwrite inputs", result.stderr)
        self.assertEqual(self.prompt.read_text(), "Give an independent answer.\n")

    def test_callers_delegate_execution_without_losing_their_workflow(self) -> None:
        arena = (REPO / "agents/skills/arena/SKILL.md").read_text()
        how = (REPO / "agents/skills/how/SKILL.md").read_text()
        reflect = (REPO / "agents/skills/independent-reflect/SKILL.md").read_text()

        for skill in (arena, how, reflect):
            self.assertIn("../model-wave/SKILL.md", skill)
            self.assertNotIn("fable-counsel/scripts/counsel.py", skill)
        self.assertIn("Judge", arena)
        self.assertIn("Graft", arena)
        self.assertIn("Critique", how)
        self.assertIn("Synthesize independently", reflect)
        self.assertIn("claude-dispatch", reflect)


if __name__ == "__main__":
    unittest.main()
