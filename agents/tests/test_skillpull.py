import subprocess
import tempfile
import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "skillpull"


class SkillpullValidateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.skillpull = self.root / "skillpull"
        self.skillpull.write_bytes(SOURCE.read_bytes())
        self.skillpull.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def add_skill(self, relative_path: str, name: str) -> None:
        skill = self.root / relative_path
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text(
            f"---\nname: {name}\ndescription: Test skill.\n---\n"
        )

    def run_validate(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.skillpull), "validate"],
            capture_output=True,
            text=True,
        )

    def test_validates_active_and_in_progress_skills_only(self):
        self.add_skill("skills/active", "active")
        (self.root / "skills/private-placeholder").mkdir(parents=True)
        self.add_skill("in-progress/candidate", "candidate")
        self.add_skill("skills/.local/private", "private")
        self.add_skill("archive/retired", "retired")
        (self.root / "skill-sources.toml").write_text(
            "[skills.active]\n"
            'local_path = "agents/skills/active"\n'
            'tracking = "local"\n\n'
            "[skills.candidate]\n"
            'local_path = "agents/in-progress/candidate"\n'
            'tracking = "local"\n\n'
            "[skills.private-placeholder]\n"
            'local_path = "agents/skills/private-placeholder"\n'
            'tracking = "local"\n'
        )

        result = self.run_validate()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("validate: ok (3 skills mapped)", result.stdout)

    def test_rejects_same_name_in_active_and_in_progress(self):
        self.add_skill("skills/sample", "sample")
        self.add_skill("in-progress/sample", "sample")
        (self.root / "skill-sources.toml").write_text(
            "[skills.sample]\n"
            'local_path = "agents/skills/sample"\n'
            'tracking = "local"\n'
        )

        result = self.run_validate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "skill names present in both active and in-progress directories",
            result.stdout,
        )

    def test_rejects_manifest_path_outside_lifecycle_directory(self):
        self.add_skill("skills/sample", "sample")
        (self.root / "skill-sources.toml").write_text(
            "[skills.sample]\n"
            'local_path = "agents/skills/old-category/sample"\n'
            'tracking = "local"\n'
        )

        result = self.run_validate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(
            "manifest entries outside their lifecycle directory",
            result.stdout,
        )



if __name__ == "__main__":
    unittest.main()
