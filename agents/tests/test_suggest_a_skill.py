from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SKILL_DIR = REPO / "agents/skills/suggest-a-skill"
SKILL = SKILL_DIR / "SKILL.md"
MANIFEST = REPO / "agents/skill-sources.toml"


class SuggestASkillTests(unittest.TestCase):
    def test_is_a_user_invoked_local_skill(self) -> None:
        skill = SKILL.read_text()
        policy = (SKILL_DIR / "agents/openai.yaml").read_text()
        manifest = MANIFEST.read_text()

        self.assertIn("disable-model-invocation: true", skill)
        self.assertIn("allow_implicit_invocation: false", policy)
        self.assertIn("[skills.suggest-a-skill]", manifest)
        self.assertIn('local_path = "agents/skills/suggest-a-skill"', manifest)

    def test_inventories_the_complete_active_catalog(self) -> None:
        skill = " ".join(SKILL.read_text().lower().split())

        self.assertIn("every active user- and model-invoked skill", skill)
        self.assertIn("agents/skillctl list", skill)
        self.assertIn("complete `description`", skill)
        self.assertIn("off, archived, in progress, or this skill itself", skill)

    def test_ranks_five_without_invoking_them(self) -> None:
        skill = " ".join(SKILL.read_text().lower().split())

        self.assertIn("broader objective", skill)
        self.assertIn("exactly five items in ranked order", skill)
        self.assertIn("description, verbatim", skill)
        self.assertIn("why now", skill)
        self.assertIn("do not invoke or perform any recommended skill", skill)


if __name__ == "__main__":
    unittest.main()
