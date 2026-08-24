from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "git-crypt-check"


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=check,
        text=True,
        capture_output=True,
    )


class GitCryptCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="git-crypt-check.")
        self.repo = Path(self.temp.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-b", "main")
        git(self.repo, "config", "user.name", "Git Crypt Check Test")
        git(self.repo, "config", "user.email", "git-crypt-check@example.invalid")
        self.clean = self.repo / "fake-clean"
        self.smudge = self.repo / "fake-smudge"
        self.clean.write_text("#!/bin/sh\nprintf '\\000GITCRYPT\\000'\ncat\n")
        self.smudge.write_text("#!/bin/sh\ndd bs=1 skip=10 2>/dev/null\n")
        self.clean.chmod(0o700)
        self.smudge.chmod(0o700)
        agents = self.repo / "agents"
        agents.mkdir()
        self.checker = agents / "git-crypt-check"
        shutil.copy2(SOURCE, self.checker)
        self.checker.chmod(0o700)
        (self.repo / ".gitattributes").write_text(
            "private/** filter=git-crypt diff=git-crypt\n"
        )
        (self.repo / "README.md").write_text("fixture\n")
        git(self.repo, "add", ".gitattributes", "README.md", "agents/git-crypt-check")
        git(self.repo, "commit", "-m", "fixture")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_checker(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.checker), *args],
            cwd=self.repo,
            check=check,
            text=True,
            capture_output=True,
        )

    def unlock(self) -> None:
        git(self.repo, "config", "filter.git-crypt.required", "true")
        git(self.repo, "config", "filter.git-crypt.clean", str(self.clean))
        git(self.repo, "config", "filter.git-crypt.smudge", str(self.smudge))

    def test_ready_requires_an_active_filter_and_protected_path(self) -> None:
        locked = self.run_checker("ready", "private", check=False)
        self.assertNotEqual(locked.returncode, 0)
        self.assertIn("not unlocked with git-crypt", locked.stderr)

        self.unlock()
        self.assertIn("ready", self.run_checker("ready", "private").stdout)
        public = self.run_checker("ready", "public", check=False)
        self.assertNotEqual(public.returncode, 0)
        self.assertIn("not protected by git-crypt", public.stderr)

    def test_staged_and_tree_checks_require_ciphertext(self) -> None:
        self.unlock()
        private = self.repo / "private"
        private.mkdir()
        payload = private / "payload.txt"
        payload.write_text("private evidence\n")
        git(self.repo, "add", "private/payload.txt")

        staged = self.run_checker("staged", "private")
        self.assertIn("staged ok", staged.stdout)
        git(self.repo, "commit", "-m", "encrypted")
        self.assertIn("main ok", self.run_checker("tree", "main", "private").stdout)

    def test_passthrough_filter_is_rejected(self) -> None:
        self.unlock()
        git(self.repo, "config", "filter.git-crypt.clean", "cat # git-crypt")
        git(self.repo, "config", "filter.git-crypt.smudge", "cat # git-crypt")
        private = self.repo / "private"
        private.mkdir()
        (private / "payload.txt").write_text("plaintext\n")
        git(self.repo, "add", "private/payload.txt")

        result = self.run_checker("staged", "private", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("staged blob is plaintext", result.stderr)


if __name__ == "__main__":
    unittest.main()
