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
        self.skill = self.root / "skills" / "sample"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: sample\ndescription: Sample skill.\n---\n\n# Sample\n"
        )
        self.local_skill = self.root / "skills" / ".local" / "private"
        self.local_skill.mkdir(parents=True)
        (self.local_skill / "SKILL.md").write_text(
            "---\nname: private\ndescription: Private skill.\n---\n\n# Private\n"
        )
        self.candidate = self.root / "in-progress" / "candidate"
        self.candidate.mkdir(parents=True)
        (self.candidate / "SKILL.md").write_text(
            "---\nname: candidate\ndescription: Candidate skill.\n---\n\n# Candidate\n"
        )
        self.locked_skill = self.root / "skills" / "locked-private"
        self.locked_skill.mkdir()
        (self.locked_skill / "SKILL.md").write_bytes(b"\x00GITCRYPT\x00ciphertext")

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

    def run_skillctl_result(self, *args):
        env = os.environ.copy()
        env["HOME"] = str(self.home)
        return subprocess.run(
            [str(self.skillctl), *args],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

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

    def test_sync_migrates_legacy_nested_links(self):
        codex_skills = self.home / ".codex" / "skills"
        nested_link = codex_skills / "test" / "sample"
        nested_link.parent.mkdir(parents=True)
        nested_link.symlink_to(self.skill)
        nested_local_link = codex_skills / ".local" / "private"
        nested_local_link.parent.mkdir(parents=True)
        nested_local_link.symlink_to(self.local_skill)
        unrelated = codex_skills / "run-on-mac"
        unrelated.mkdir()

        self.run_skillctl("sync")
        flat_link = codex_skills / "sample"
        self.assertTrue(flat_link.is_symlink())
        self.assertEqual(flat_link.resolve(), self.skill.resolve())
        self.assertFalse(nested_link.exists())
        self.assertFalse(nested_link.parent.exists())
        self.assertTrue(unrelated.is_dir())
        local_link = codex_skills / "private"
        self.assertTrue(local_link.is_symlink())
        self.assertEqual(local_link.resolve(), self.local_skill.resolve())
        self.assertFalse(nested_local_link.exists())
        self.assertFalse(nested_local_link.parent.exists())

    def test_in_progress_skills_are_not_discoverable(self):
        output = self.run_skillctl("list")
        self.assertNotIn("candidate", output)

        self.run_skillctl("sync")
        self.assertFalse((self.home / ".codex" / "skills" / "candidate").exists())

    def test_locked_private_skills_are_skipped_and_stale_links_are_pruned(self):
        codex_skills = self.home / ".codex" / "skills"
        codex_skills.mkdir(parents=True)
        locked_link = codex_skills / "locked-private"
        locked_link.symlink_to(self.locked_skill)

        output = self.run_skillctl("list")
        self.assertNotIn("locked-private", output)
        self.run_skillctl("sync")
        self.assertFalse(locked_link.exists())

        result = self.run_skillctl_result("disable-model", "locked-private")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("private skill 'locked-private' is locked", result.stderr)

    def test_verify_is_read_only_and_detects_generated_policy_drift(self):
        self.run_skillctl("disable-model", "sample", "codex")
        self.assertIn("verify: ok", self.run_skillctl("verify"))

        yaml_path = self.skill / "agents" / "openai.yaml"
        yaml_path.write_text("policy:\n  allow_implicit_invocation: true\n")
        before = yaml_path.read_text()
        result = self.run_skillctl_result("verify")

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stale generated Codex policy", result.stdout)
        self.assertEqual(yaml_path.read_text(), before)

    def test_local_skills_share_the_global_name_namespace(self):
        duplicate = self.root / "skills" / ".local" / "sample"
        duplicate.mkdir()
        (duplicate / "SKILL.md").write_text(
            "---\nname: sample\ndescription: Duplicate.\n---\n"
        )

        env = os.environ.copy()
        env["HOME"] = str(self.home)
        result = subprocess.run(
            [str(self.skillctl), "list"],
            capture_output=True,
            text=True,
            env=env,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate skill names", result.stderr)


class ClaudeSkillProjectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.skills = self.root / "skills"
        self.skill = self.skills / "sample"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: sample\ndescription: Sample skill.\n---\n"
        )
        self.local_skill = self.skills / ".local" / "private"
        self.local_skill.mkdir(parents=True)
        (self.local_skill / "SKILL.md").write_text(
            "---\nname: private\ndescription: Private skill.\n---\n"
        )
        self.candidate = self.root / "in-progress" / "candidate"
        self.candidate.mkdir(parents=True)
        (self.candidate / "SKILL.md").write_text(
            "---\nname: candidate\ndescription: Candidate skill.\n---\n"
        )
        self.locked_skill = self.skills / "locked-private"
        self.locked_skill.mkdir()
        (self.locked_skill / "SKILL.md").write_bytes(b"\x00GITCRYPT\x00ciphertext")

    def tearDown(self):
        self.temp.cleanup()

    def test_sync_migrates_legacy_nested_link(self):
        claude_skills = self.home / ".claude" / "skills"
        nested_link = claude_skills / "fleet" / "sample"
        nested_link.parent.mkdir(parents=True)
        nested_link.symlink_to(self.skill)
        unrelated = claude_skills / "run-on-mac"
        unrelated.mkdir()
        locked_link = claude_skills / "locked-private"
        locked_link.symlink_to(self.locked_skill)

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
        local_link = claude_skills / "private"
        self.assertTrue(local_link.is_symlink())
        self.assertEqual(local_link.resolve(), self.local_skill.resolve())
        self.assertFalse((claude_skills / "candidate").exists())
        self.assertFalse(locked_link.exists())


if __name__ == "__main__":
    unittest.main()
