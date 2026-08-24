from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SKILL_DIR = REPO / "agents/skills/record-skill-use"
SKILL = SKILL_DIR / "SKILL.md"
OPENAI = SKILL_DIR / "agents/openai.yaml"
SCRIPT = SKILL_DIR / "scripts/record_skill_use.py"
MANIFEST = REPO / "agents/skill-sources.toml"
ATTRIBUTES = REPO / ".gitattributes"
ANDERS_SKILL_WRITING = REPO / "agents/skills/anders-skill-writing/SKILL.md"


class RecordSkillUseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / "skill-uses"
        self.evidence = self.base / "prepared.md"
        self.evidence.write_text(
            "# Evidence\n\n## Invocation\n\nUse /html.\n\n"
            "## Feedback\n\nNo feedback was provided. This use is ungraded.\n"
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(SCRIPT), *args],
            text=True,
            capture_output=True,
            check=False,
        )

    def create(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return self.run_script(
            "create",
            "--root",
            str(self.root),
            "--skill",
            "html",
            "--evidence",
            str(self.evidence),
            "--timestamp",
            "2026-08-23T143012Z",
            *extra,
        )

    def test_skill_is_user_invoked_local_and_evidence_is_encrypted(self) -> None:
        skill = SKILL.read_text()
        self.assertIn("disable-model-invocation: true", skill)
        self.assertIn("allow_implicit_invocation: false", OPENAI.read_text())
        self.assertIn("[skills.record-skill-use]", MANIFEST.read_text())
        self.assertIn(
            "agents/skill-uses/** filter=git-crypt diff=git-crypt",
            ATTRIBUTES.read_text(),
        )
        self.assertIn(
            "agents/skill-uses/<skill-name>/", ANDERS_SKILL_WRITING.read_text()
        )
        self.assertIn("commit it immediately", skill.lower())
        self.assertIn("git commit --only", skill)
        self.assertIn("git-crypt-check\" ready", skill)
        self.assertIn("git-crypt-check\" staged", skill)
        self.assertIn("git-crypt-check\" tree HEAD", skill)
        self.assertIn("git restore --staged", skill)
        self.assertIn(
            'skill-use: <skill> @ <UTC timestamp>', skill
        )
        self.assertIn("Then push immediately", skill)

    def test_default_root_is_derived_from_the_resolved_skill_path(self) -> None:
        specification = importlib.util.spec_from_file_location(
            "record_skill_use", SCRIPT
        )
        self.assertIsNotNone(specification)
        self.assertIsNotNone(specification.loader)
        module = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(module)
        self.assertEqual(
            module.default_evidence_root(), REPO / "agents/skill-uses"
        )

    def test_creates_harness_agnostic_ungraded_packet(self) -> None:
        artifact = self.base / "report.html"
        artifact.write_text("<html><body>Evidence</body></html>\n")
        result = self.create(
            "--harness",
            "future-harness",
            "--model",
            "model-x",
            "--session-id",
            "session-1",
            "--source-transcript",
            "source://session-1",
            "--related-skill",
            "show-me",
            "--artifact",
            str(artifact),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = Path(result.stdout.strip())
        self.assertEqual(packet, (self.root / "html/2026-08-23T143012Z").resolve())
        metadata = json.loads((packet / "metadata.json").read_text())
        self.assertEqual(metadata["harness"], "future-harness")
        self.assertEqual(metadata["model"], "model-x")
        self.assertEqual(metadata["related_skills"], ["show-me"])
        self.assertFalse(metadata["feedback_provided"])
        self.assertEqual(
            {item["path"] for item in metadata["files"]},
            {"evidence.md", "report.html"},
        )
        self.assertEqual((packet / "evidence.md").read_text(), self.evidence.read_text())
        validation = self.run_script("validate", str(packet))
        self.assertEqual(validation.returncode, 0, validation.stderr)

    def test_records_explicit_feedback_without_interpreting_it(self) -> None:
        self.evidence.write_text(
            "# Evidence\n\n## Feedback\n\nThe hierarchy was difficult to scan.\n"
        )
        result = self.create("--feedback-provided")
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = Path(result.stdout.strip())
        metadata = json.loads((packet / "metadata.json").read_text())
        self.assertTrue(metadata["feedback_provided"])
        self.assertIn("difficult to scan", (packet / "evidence.md").read_text())

    def test_rejects_unsafe_skill_names_and_duplicate_filenames(self) -> None:
        unsafe = self.run_script(
            "create",
            "--root",
            str(self.root),
            "--skill",
            "../html",
            "--evidence",
            str(self.evidence),
        )
        self.assertNotEqual(unsafe.returncode, 0)

        first = self.base / "first/same.html"
        second = self.base / "second/same.html"
        first.parent.mkdir()
        second.parent.mkdir()
        first.write_text("first\n")
        second.write_text("second\n")
        duplicate = self.create("--artifact", str(first), "--artifact", str(second))
        self.assertNotEqual(duplicate.returncode, 0)
        self.assertIn("unique destination filenames", duplicate.stderr)

    def test_refuses_overwrite_and_detects_tampering(self) -> None:
        first = self.create()
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.create()
        self.assertNotEqual(second.returncode, 0)
        self.assertIn("already exists", second.stderr)

        packet = Path(first.stdout.strip())
        (packet / "evidence.md").write_text("changed\n")
        validation = self.run_script("validate", str(packet))
        self.assertNotEqual(validation.returncode, 0)
        self.assertIn("size mismatch", validation.stderr)


if __name__ == "__main__":
    unittest.main()
