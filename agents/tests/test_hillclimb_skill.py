from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SKILL_DIR = REPO / "agents/skills/hillclimb"
SKILL = SKILL_DIR / "SKILL.md"
UPSTREAM = (
    REPO
    / "agents/references/pstack/skills/poteto-mode/playbooks/hillclimb.md"
)


class HillclimbSkillTests(unittest.TestCase):
    def test_is_user_invoked_and_tracks_the_pstack_playbook(self) -> None:
        skill = SKILL.read_text()
        manifest = (REPO / "agents/skill-sources.toml").read_text()
        policy = (SKILL_DIR / "agents/openai.yaml").read_text()
        self.assertIn("disable-model-invocation: true", skill)
        self.assertIn("[skills.hillclimb]", manifest)
        self.assertIn(
            'path = "pstack/skills/poteto-mode/playbooks/hillclimb.md"',
            manifest,
        )
        self.assertIn("allow_implicit_invocation: false", policy)

    def test_preserves_the_upstream_experiment_contract(self) -> None:
        skill = " ".join(SKILL.read_text().split())
        upstream = " ".join(UPSTREAM.read_text().split())
        for contract in (
            "one change, one measurement, keep or revert",
            "changing it invalidates every earlier number",
            "one row per attempt",
            "Accept only when the metric moves past noise",
            "Push past the first plateau",
            "Don't relax the predicate to declare victory",
        ):
            self.assertIn(contract, skill)
            self.assertIn(contract, upstream)

    def test_every_local_reference_resolves(self) -> None:
        references = SKILL_DIR / "references"
        expected = {
            "autonomous-run.md",
            "build-the-lever.md",
            "guard-the-context-window.md",
            "how.md",
            "laziness-protocol.md",
            "opening-a-pr.md",
            "prove-it-works.md",
            "separate-before-serializing-shared-state.md",
            "sequence-verifiable-units.md",
            "show-me-your-work.md",
        }
        self.assertEqual({path.name for path in references.iterdir()}, expected)
        for path in references.iterdir():
            with self.subTest(path=path):
                self.assertTrue(path.is_symlink())
                self.assertTrue(path.resolve().is_file())


if __name__ == "__main__":
    unittest.main()
