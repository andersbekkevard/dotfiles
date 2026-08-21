import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


AGENTS = Path(__file__).resolve().parents[1]
REPO = AGENTS.parent


class InstructionctlTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.agents = self.repo / "agents"
        self.home = self.root / "home"
        (self.agents / ".local").mkdir(parents=True)
        (self.repo / "setup").mkdir()
        (self.home / ".codex").mkdir(parents=True)
        (self.home / ".claude").mkdir(parents=True)

        shutil.copy2(AGENTS / "instructionctl", self.agents / "instructionctl")
        shutil.copy2(REPO / "setup/agents.sh", self.repo / "setup/agents.sh")
        (self.agents / "SHARED.global.md").write_text("shared rule\n")
        (self.agents / "AGENTS.global.md").write_text("codex rule\n")
        (self.agents / "CLAUDE.global.md").write_text("claude rule\n")

    def tearDown(self):
        self.temp.cleanup()

    def render(self, harness: str) -> str:
        harness_file = "AGENTS.global.md" if harness == "codex" else "CLAUDE.global.md"
        harness_local = "AGENTS.md" if harness == "codex" else "CLAUDE.md"
        chunks = [
            "<!-- dotfiles-managed: composed global agent instructions -->\n",
            (self.agents / "SHARED.global.md").read_text(),
            "\n",
            (self.agents / harness_file).read_text(),
        ]
        for source in (
            self.agents / ".local/SHARED.md",
            self.agents / ".local" / harness_local,
        ):
            if source.exists() and source.stat().st_size:
                chunks.extend(("\n", source.read_text()))
        return "".join(chunks)

    def write_targets(self) -> None:
        (self.home / ".codex/AGENTS.md").write_text(self.render("codex"))
        (self.home / ".claude/CLAUDE.md").write_text(self.render("claude"))

    def run_ctl(self, command: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        return subprocess.run(
            [str(self.agents / "instructionctl"), command],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_verify_reports_current_sources_and_local_state(self):
        (self.agents / ".local/SHARED.md").write_text("shared local rule\n")
        (self.agents / ".local/AGENTS.md").write_text("codex local rule\n")
        self.write_targets()

        result = self.run_ctl("verify")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("codex   current", result.stdout)
        self.assertIn("claude  current", result.stdout)
        self.assertIn("agents/.local/SHARED.md (active)", result.stdout)
        self.assertIn("agents/.local/CLAUDE.md (absent)", result.stdout)
        self.assertNotIn("shared local rule", result.stdout)
        self.assertNotIn("codex local rule", result.stdout)

    def test_verify_fails_for_stale_and_missing_targets(self):
        (self.home / ".codex/AGENTS.md").write_text("stale\n")

        result = self.run_ctl("verify")

        self.assertEqual(result.returncode, 1)
        self.assertIn("codex   stale", result.stdout)
        self.assertIn("claude  missing", result.stdout)
        self.assertIn("repair: ./setup.sh agents", result.stderr)

    def test_status_reports_drift_without_failing(self):
        result = self.run_ctl("status")

        self.assertEqual(result.returncode, 0)
        self.assertIn("codex   missing", result.stdout)
        self.assertIn("claude  missing", result.stdout)


if __name__ == "__main__":
    unittest.main()
