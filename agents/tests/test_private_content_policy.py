from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]


class PrivateContentPolicyTest(unittest.TestCase):
    def attribute(self, path: str) -> str:
        result = subprocess.run(
            ["git", "-C", str(REPO), "check-attr", "filter", "--", path],
            check=True,
            text=True,
            capture_output=True,
        )
        return result.stdout.strip().rsplit(": ", 1)[-1]

    def test_anders_specific_state_and_operational_skills_are_encrypted(self) -> None:
        private_paths = (
            "shell/.secrets",
            "agents/skill-uses/html/example/evidence.md",
            "agents/skill-usage-batches/replica/batch.json",
            "agents/skills/onboard-mcps/references/registry.toml",
            "agents/skills/application-email/SKILL.md",
            "agents/skills/control-europa-desktop/scripts/control-europa-desktop",
            "agents/skills/cycle-codex-account/SKILL.md",
            "scripts/.config/fleet/machines.tsv",
            "scripts/.config/fleet/known_hosts",
            "agents/in-progress/html/benchmark/cases/01-case/context.md",
            "agents/in-progress/html/benchmark/manifest.json",
        )
        for path in private_paths:
            with self.subTest(path=path):
                self.assertEqual(self.attribute(path), "git-crypt")

    def test_reusable_mechanisms_remain_public(self) -> None:
        public_paths = (
            "agents/git-crypt-check",
            "agents/skills/record-skill-use/scripts/record_skill_use.py",
            "agents/skills/fleet/SKILL.md",
            "scripts/.local/bin/fleet",
            "agents/skills/onboard-devbox/SKILL.md",
            "agents/in-progress/html/benchmark/README.md",
            "agents/in-progress/html/benchmark/render.py",
            "agents/in-progress/html/benchmark/validate.py",
        )
        for path in public_paths:
            with self.subTest(path=path):
                self.assertEqual(self.attribute(path), "unspecified")


if __name__ == "__main__":
    unittest.main()
