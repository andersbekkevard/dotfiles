import os
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

    def test_sync_preserves_category_structure(self):
        self.run_skillctl("sync")
        link = self.home / ".codex" / "skills" / "test" / "sample"
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), self.skill.resolve())
        self.assertFalse((self.home / ".codex" / "skills" / "sample").exists())


if __name__ == "__main__":
    unittest.main()
