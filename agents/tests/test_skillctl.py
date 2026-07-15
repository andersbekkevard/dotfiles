import os
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "skillctl"


class SkillctlHarnessModesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.skillctl = self.root / "skillctl"
        shutil.copy2(SOURCE, self.skillctl)
        self.skill = self.root / "skills" / "test" / "sample"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: sample\ndescription: Sample skill.\n---\n\n# Sample\n"
        )

    def tearDown(self):
        self.temp.cleanup()

    def run_skillctl(self, *args):
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        return subprocess.run(
            [str(self.skillctl), *args],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        ).stdout

    def frontmatter(self):
        return (self.skill / "SKILL.md").read_text().split("---", 2)[1]

    def test_each_harness_can_be_toggled_independently(self):
        self.run_skillctl("disable-model", "sample", "codex")
        self.assertNotIn("disable-model-invocation", self.frontmatter())
        self.assertIn("disable-codex-model-invocation: true", self.frontmatter())
        self.assertIn(
            "allow_implicit_invocation: false",
            (self.skill / "agents" / "openai.yaml").read_text(),
        )

        self.run_skillctl("disable-model", "sample", "claude")
        self.assertIn("disable-model-invocation: true", self.frontmatter())
        self.assertNotIn("disable-codex-model-invocation", self.frontmatter())

        self.run_skillctl("enable-model", "sample", "codex")
        self.assertIn("disable-model-invocation: true", self.frontmatter())
        self.assertIn("disable-codex-model-invocation: false", self.frontmatter())
        self.assertFalse((self.skill / "agents" / "openai.yaml").exists())

        output = self.run_skillctl("enable-model", "sample")
        self.assertNotIn("disable-model-invocation", self.frontmatter())
        self.assertNotIn("disable-codex-model-invocation", self.frontmatter())
        self.assertIn("sample: claude=model codex=model", output)

    def test_sync_preserves_category_path_and_migrates_flat_link(self):
        codex_skills = self.home / ".codex" / "skills"
        codex_skills.mkdir(parents=True)
        flat_link = codex_skills / "sample"
        flat_link.symlink_to(self.skill)
        unrelated = codex_skills / "run-on-mac"
        unrelated.mkdir()

        self.run_skillctl("sync")
        nested_link = codex_skills / "test" / "sample"
        self.assertTrue(nested_link.is_symlink())
        self.assertEqual(nested_link.resolve(), self.skill.resolve())
        self.assertFalse(flat_link.exists())
        self.assertTrue(unrelated.is_dir())


class ClaudeSkillProjectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.skills = self.root / "skills"
        self.skill = self.skills / "fleet" / "sample"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: sample\ndescription: Sample skill.\n---\n"
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_sync_flattens_category_path_and_migrates_nested_link(self):
        claude_skills = self.home / ".claude" / "skills"
        nested_link = claude_skills / "fleet" / "sample"
        nested_link.parent.mkdir(parents=True)
        nested_link.symlink_to(self.skill)
        unrelated = claude_skills / "run-on-mac"
        unrelated.mkdir()

        script = f"""\\
set -euo pipefail
export HOME={shlex.quote(str(self.home))}
DRY_RUN=0
log_info() {{ :; }}
log_warn() {{ :; }}
run_cmd() {{ local description=\"$1\"; shift; \"$@\"; }}
backup_path() {{ return 1; }}
source {shlex.quote(str(SOURCE.parent.parent / "setup" / "agents.sh"))}
sync_claude_skill_links {shlex.quote(str(self.skills))}
"""
        subprocess.run(["bash", "-c", script], check=True)

        flat_link = claude_skills / "sample"
        self.assertTrue(flat_link.is_symlink())
        self.assertEqual(flat_link.resolve(), self.skill.resolve())
        self.assertFalse(nested_link.exists())
        self.assertFalse(nested_link.parent.exists())
        self.assertTrue(unrelated.is_dir())


if __name__ == "__main__":
    unittest.main()
