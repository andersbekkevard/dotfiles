from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SKILL = REPO / "agents/skills/model-brief/SKILL.md"
OPENAI = REPO / "agents/skills/model-brief/agents/openai.yaml"
COMPOSER = REPO / "agents/skills/model-brief/scripts/compose_prompt.py"
BUNDLER = REPO / "agents/skills/model-brief/scripts/bundle_files.py"


class ModelBriefTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        self.brief = self.base / "brief.md"
        self.brief.write_text("Which boundary should we choose?\n")
        self.output = self.base / "prompt.md"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def compose(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "uv",
                "run",
                str(COMPOSER),
                "--root",
                str(self.root),
                "--mode",
                "guidance",
                "--brief",
                str(self.brief),
                "--output",
                str(self.output),
                *extra,
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def prompt_xml(self) -> ET.Element:
        text = self.output.read_text()
        return ET.fromstring(text[text.index("<model_brief ") :])

    def test_guidance_prompt_is_self_contained_and_metadata_balances(self) -> None:
        metadata = self.base / "prompt.json"
        result = self.compose("--metadata-output", str(metadata))
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.prompt_xml()
        self.assertEqual(packet.attrib, {"mode": "guidance"})
        self.assertIn("Which boundary", packet.findtext("briefing"))
        values = json.loads(metadata.read_text())
        self.assertEqual(values["schema_version"], 3)
        self.assertEqual(sum(values["prompt_sections"].values()), values["prompt_tokens"])

    def test_all_decision_modes_are_available(self) -> None:
        for mode in ("guidance", "propose", "challenge"):
            with self.subTest(mode=mode):
                result = subprocess.run(
                    [
                        "uv",
                        "run",
                        str(COMPOSER),
                        "--root",
                        str(self.root),
                        "--mode",
                        mode,
                        "--brief",
                        str(self.brief),
                        "--output",
                        str(self.output),
                    ],
                    text=True,
                    capture_output=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.prompt_xml().attrib, {"mode": mode})

    def test_mixed_fidelity_preserves_exact_evidence_and_xml_escaping(self) -> None:
        (self.root / "plan.md").write_text("A < B & C > D\nsecond\n")
        (self.root / "code.py").write_text("one\ntwo\nthree\n")
        digest = self.base / "digest.md"
        digest.write_text("Runtime summary with src provenance.\n")
        result = self.compose(
            "--document",
            "plan.md",
            "--excerpt",
            "code.py:2-3",
            "--digest",
            str(digest),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.prompt_xml()
        self.assertIn("A < B & C > D", packet.findtext("context/document"))
        self.assertIn("two\nthree", packet.findtext("context/excerpt"))
        self.assertIn("Runtime summary", packet.findtext("context/digest"))

    def test_user_anchors_require_intent(self) -> None:
        anchors = self.base / "anchors.md"
        anchors.write_text("Keep this exact wording.\n")
        result = self.compose("--user-anchors", str(anchors))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --user-intent", result.stderr)

    def test_secret_paths_and_values_are_rejected(self) -> None:
        (self.root / ".env").write_text("SAFE=example\n")
        result = self.compose("--document", ".env")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sensitive repository path", result.stderr)
        (self.root / "notes.md").write_text(
            "api_key = 'abcdefghijklmnopqrstuvwxyz123456'\n"
        )
        result = self.compose("--document", "notes.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("secret-like content", result.stderr)

    def test_token_limit_failure_preserves_existing_output(self) -> None:
        self.output.write_text("existing\n")
        result = self.compose("--max-total-tokens", "1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_text(), "existing\n")

    def test_exact_file_bundler_survives_the_split(self) -> None:
        (self.root / "a.md").write_text("A < B & C\n")
        bundled = self.base / "files.xml"
        result = subprocess.run(
            [
                "uv",
                "run",
                str(BUNDLER),
                "--root",
                str(self.root),
                "--file",
                "a.md",
                "--files-report",
                "--output",
                str(bundled),
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('path="a.md"', bundled.read_text())
        self.assertIn("a.md", result.stderr)

    def test_skill_is_prompt_only_and_user_invoked(self) -> None:
        skill = SKILL.read_text()
        self.assertIn("Stop at the prompt", skill)
        self.assertIn("neither chooses nor invokes a model", skill)
        self.assertIn("disable-model-invocation: true", skill)
        self.assertIn("allow_implicit_invocation: false", OPENAI.read_text())


if __name__ == "__main__":
    unittest.main()
