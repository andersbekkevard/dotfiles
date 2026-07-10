import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "agents/skills/fleet/fable-counsel/scripts/compose_packet.py"
SKILL = REPO / "agents/skills/fleet/fable-counsel/SKILL.md"


class FableCounselPacketTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        self.brief = self.base / "brief.md"
        self.brief.write_text(
            "Goal: choose the cleanest boundary.\nDirection: one deep module.\n"
        )
        self.output = self.base / "packet.md"

    def run_packet(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--root",
                str(self.root),
                "--brief",
                str(self.brief),
                "--output",
                str(self.output),
                *args,
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def packet_xml(self) -> ET.Element:
        text = self.output.read_text()
        return ET.fromstring(text[text.index("<counsel_packet") :])

    def test_minimal_packet_is_standalone_and_reports_only_metadata(self) -> None:
        result = self.run_packet()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("You are advising Sol", self.output.read_text())
        self.assertIn("Posture: plan counsel", self.output.read_text())
        packet = self.packet_xml()
        self.assertEqual(packet.attrib["posture"], "plan-counsel")
        self.assertEqual([child.tag for child in packet], ["context", "sol_brief"])
        self.assertIsNotNone(packet.find("sol_brief"))
        self.assertIsNone(packet.find("user_intent"))
        self.assertEqual(packet.find("context").tag, "context")
        self.assertNotIn("Goal: choose", result.stdout)
        self.assertIn("Packet:", result.stdout)
        self.assertIn("Posture: plan-counsel", result.stdout)

    def test_cold_read_selects_independent_prompt(self) -> None:
        result = self.run_packet("--posture", "cold-read")
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = self.output.read_text()
        self.assertIn("Posture: cold read", prompt)
        self.assertIn("Form an independent starting point", prompt)
        self.assertNotIn("Sol has supplied a proposed direction", prompt)
        self.assertEqual(self.packet_xml().attrib["posture"], "cold-read")
        self.assertIn("Posture: cold-read", result.stdout)

    def test_intent_anchors_and_evidence_are_distinct_and_precede_brief(self) -> None:
        intent = self.base / "user-intent.md"
        intent.write_text("Build a lightweight source of wise outside judgment.\n")
        anchors = self.base / "user-anchors.md"
        anchors.write_text("Fresh eyes matter more than mechanical review.\n")
        result = self.run_packet(
            "--user-intent", str(intent), "--user-anchors", str(anchors)
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.packet_xml()
        self.assertEqual(
            [child.tag for child in packet],
            ["user_intent", "verbatim_user_anchors", "context", "sol_brief"],
        )
        self.assertIn("lightweight source", packet.findtext("user_intent"))
        self.assertNotIn("Fresh eyes matter", packet.findtext("user_intent"))
        self.assertIn(
            "Fresh eyes matter", packet.findtext("verbatim_user_anchors")
        )
        self.assertEqual(
            set(packet.find("user_intent").attrib),
            {"content_encoding"},
        )
        self.assertIn("User intent:", result.stdout)
        self.assertIn("User anchors:", result.stdout)
        self.assertNotIn("Fresh eyes matter", result.stdout)

    def test_user_anchors_require_reconstructed_intent(self) -> None:
        anchors = self.base / "user-anchors.md"
        anchors.write_text("Exact user wording.\n")
        result = self.run_packet("--user-anchors", str(anchors))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requires --user-intent", result.stderr)

    def test_mixed_fidelity_preserves_xml_and_exact_excerpt(self) -> None:
        document = self.root / "plan.md"
        document.write_text("A < B & C > D\nsecond line\n")
        code = self.root / "module.py"
        code.write_text("one\ntwo\nthree\nfour\n")
        digest = self.base / "terra-runtime.md"
        digest.write_text("Summary from `module.py:1-4`: the boundary is cohesive.\n")

        result = self.run_packet(
            "--document",
            "plan.md",
            "--excerpt",
            "module.py:2-3",
            "--digest",
            str(digest),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        packet = self.packet_xml()
        self.assertEqual(
            packet.findtext("context/document"), "\nA < B & C > D\nsecond line\n\n    "
        )
        self.assertEqual(packet.findtext("context/excerpt"), "\ntwo\nthree\n\n    ")
        self.assertIn("boundary is cohesive", packet.findtext("context/digest"))
        self.assertEqual(packet.find("context/excerpt").attrib["lines"], "2-3")

    def test_excerpt_bounds_fail_without_clipping(self) -> None:
        (self.root / "module.py").write_text("one\ntwo\n")
        result = self.run_packet("--excerpt", "module.py:2-3")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeds file length", result.stderr)
        self.assertFalse(self.output.exists())

    def test_repository_evidence_must_be_relative_and_contained(self) -> None:
        outside = self.base / "outside.md"
        outside.write_text("outside\n")
        for path in (str(outside), "../outside.md"):
            with self.subTest(path=path):
                result = self.run_packet("--document", path)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("repo-relative", result.stderr)

    def test_symlinked_repository_evidence_is_rejected(self) -> None:
        target = self.root / "target.md"
        target.write_text("target\n")
        (self.root / "link.md").symlink_to(target)
        result = self.run_packet("--document", "link.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symlink component", result.stderr)

    def test_secret_paths_and_values_are_rejected(self) -> None:
        (self.root / ".env").write_text("SAFE_NAME=example\n")
        result = self.run_packet("--document", ".env")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("sensitive repository path", result.stderr)

        secret = self.root / "notes.md"
        secret.write_text("api_key = 'abcdefghijklmnopqrstuvwxyz123456'\n")
        result = self.run_packet("--document", "notes.md")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("secret-like content", result.stderr)

    def test_safe_example_env_file_is_allowed(self) -> None:
        (self.root / ".env.example").write_text("SERVICE_URL=https://example.test\n")
        result = self.run_packet("--document", ".env.example")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SERVICE_URL", self.packet_xml().findtext("context/document"))

    def test_redacted_document_preserves_fidelity_without_weakening_scan(self) -> None:
        redacted = self.base / "redacted-auth.md"
        redacted.write_text(
            "Original: src/auth.py\nRedactions: credential value\n\n"
            "credential = '[REDACTED]'\n"
        )
        result = self.run_packet("--redacted-document", str(redacted))
        self.assertEqual(result.returncode, 0, result.stderr)
        item = self.packet_xml().find("context/redacted_document")
        self.assertEqual(item.attrib["redacted"], "true")
        self.assertIn("Original: src/auth.py", item.text)

    def test_safe_mode_does_not_reopen_user_settings(self) -> None:
        skill = SKILL.read_text()
        self.assertIn("--safe-mode", skill)
        self.assertNotIn("--setting-sources", skill)

    def test_invalid_utf8_and_nul_are_rejected(self) -> None:
        for name, data, expected in (
            ("invalid.md", b"\xff\xfe", "not valid UTF-8"),
            ("binary.md", b"safe" + b"\0" + b"later", "is binary"),
        ):
            with self.subTest(name=name):
                (self.root / name).write_bytes(data)
                result = self.run_packet("--document", name)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stderr)

    def test_token_limit_failure_preserves_existing_output(self) -> None:
        self.output.write_text("existing\n")
        result = self.run_packet("--max-total-tokens", "1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeding --max-total-tokens", result.stderr)
        self.assertEqual(self.output.read_text(), "existing\n")


if __name__ == "__main__":
    unittest.main()
