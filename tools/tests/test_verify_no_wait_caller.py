#!/usr/bin/env python3
"""Regression: wait-caller gate must not require deleted pr-review.yml.

Incident: 2026-08-29 main CI (runs 33260793986 / 33260844754) failed because
the old lockstep script still sed'd `.github/workflows/pr-review.yml`
after the wait caller was removed. The gate now fails closed only if a wait
caller is restored (.yml or .yaml, file or uses:).
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "verify_no_wait_caller.sh"


def _run(root: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["CAL_LOCKSTEP_ROOT"] = str(root)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )


def _write_workflow(root: Path, name: str, body: str) -> None:
    wf = root / ".github" / "workflows"
    wf.mkdir(parents=True, exist_ok=True)
    (wf / name).write_text(body, encoding="utf-8")


class TestVerifyNoWaitCaller(unittest.TestCase):
    def test_live_repo_has_no_wait_caller(self) -> None:
        proc = subprocess.run(
            ["bash", str(SCRIPT)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(
            proc.returncode,
            0,
            msg=proc.stderr or proc.stdout,
        )
        self.assertIn("LOCKSTEP OK", proc.stdout)

    def test_empty_workflows_dir_is_ok(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / ".github" / "workflows").mkdir(parents=True)
            proc = _run(root)
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            self.assertIn("LOCKSTEP OK", proc.stdout)

    def test_restored_pr_review_yml_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(root, "pr-review.yml", "name: restored\n")
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("wait-caller workflow restored", proc.stderr)
            self.assertIn("pr-review.yml", proc.stderr)

    def test_restored_pr_review_yaml_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(root, "pr-review.yaml", "name: restored\n")
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("wait-caller workflow restored", proc.stderr)
            self.assertIn("pr-review.yaml", proc.stderr)

    def test_uses_pr_review_light_reusable_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uses_line = (
                "    uses: ittae/.github/.github/workflows/"
                "pr-review-light.yml@main\n"
            )
            _write_workflow(
                root,
                "ci.yml",
                "jobs:\n  review:\n" + uses_line,
            )
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("AI-review wait reusable", proc.stderr)
            self.assertIn("pr-review-light.yml@main", proc.stderr)

    def test_uses_pr_review_light_yaml_reusable_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uses_line = (
                "    uses: ittae/.github/.github/workflows/"
                "pr-review-light.yaml@main\n"
            )
            _write_workflow(
                root,
                "ci.yml",
                "jobs:\n  review:\n" + uses_line,
            )
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("AI-review wait reusable", proc.stderr)
            self.assertIn("pr-review-light.yaml@main", proc.stderr)

    def test_uses_claude_code_review_reusable_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(
                root,
                "ci.yml",
                "jobs:\n  review:\n    uses: ittae/.github/.github/workflows/claude-code-review.yml@main\n",
            )
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("AI-review wait reusable", proc.stderr)

    def test_restored_claude_review_light_yml_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(root, "claude-review-light.yml", "name: restored\n")
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("wait-caller workflow restored", proc.stderr)
            self.assertIn("claude-review-light.yml", proc.stderr)

    def test_uses_claude_review_light_reusable_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uses_line = (
                "    uses: ittae/.github/.github/workflows/"
                "claude-review-light.yml@main\n"
            )
            _write_workflow(
                root,
                "ci.yml",
                "jobs:\n  review:\n" + uses_line,
            )
            proc = _run(root)
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("AI-review wait reusable", proc.stderr)
            self.assertIn("claude-review-light.yml@main", proc.stderr)

    def test_prefix_foo_pr_review_yml_file_is_ok(self) -> None:
        """Path-boundary: foo-pr-review.yml is not the forbidden stem pr-review."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(root, "foo-pr-review.yml", "name: unrelated\n")
            proc = _run(root)
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            self.assertIn("LOCKSTEP OK", proc.stdout)

    def test_uses_prefix_foo_pr_review_is_ok(self) -> None:
        """USES_RE (.*/)? must not treat foo-pr-review.yml as pr-review.yml."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uses_line = (
                "    uses: ittae/.github/.github/workflows/"
                "foo-pr-review.yml@main\n"
            )
            _write_workflow(
                root,
                "ci.yml",
                "jobs:\n  review:\n" + uses_line,
            )
            proc = _run(root)
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            self.assertIn("LOCKSTEP OK", proc.stdout)

    def test_comment_mentioning_pr_review_does_not_fail(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _write_workflow(
                root,
                "relay.yml",
                "# Aligns with pr-review.yml same-repo gate.\nname: relay\n",
            )
            proc = _run(root)
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)


if __name__ == "__main__":
    unittest.main()
