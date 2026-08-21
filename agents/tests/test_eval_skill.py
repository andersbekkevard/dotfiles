from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SKILL_DIR = REPO / "agents/skills/eval"
SKILL = SKILL_DIR / "SKILL.md"
UPSTREAM = REPO / "agents/references/pstack/skills/poteto-mode/playbooks/eval.md"


class EvalSkillTests(unittest.TestCase):
    def test_is_user_invoked_and_tracks_the_pstack_playbook(self) -> None:
        skill = SKILL.read_text()
        manifest = (REPO / "agents/skill-sources.toml").read_text()
        policy = (SKILL_DIR / "agents/openai.yaml").read_text()
        self.assertIn("disable-model-invocation: true", skill)
        self.assertIn("[skills.eval]", manifest)
        self.assertIn(
            'path = "pstack/skills/poteto-mode/playbooks/eval.md"', manifest
        )
        self.assertIn("allow_implicit_invocation: false", policy)

    def test_preserves_the_upstream_blinding_contract(self) -> None:
        skill = " ".join(SKILL.read_text().lower().split())
        upstream = " ".join(UPSTREAM.read_text().lower().split())
        for contract in (
            "observer effect",
            "candidates must run blind",
            "same prompt to each",
            "one judge scores both sets in a single pass on one scale",
            "grade chain-following from",
            "read every candidate output yourself",
        ):
            self.assertIn(contract, skill)
            self.assertIn(contract, upstream)

    def test_arena_reference_resolves(self) -> None:
        reference = SKILL_DIR / "references/arena.md"
        expected = REPO / "agents/references/pstack/skills/arena/SKILL.md"
        self.assertTrue(reference.is_symlink())
        self.assertEqual(reference.resolve(), expected.resolve())
        self.assertIn("(references/arena.md)", SKILL.read_text())


if __name__ == "__main__":
    unittest.main()
