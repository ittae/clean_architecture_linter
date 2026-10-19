#!/usr/bin/env python3
"""The public runner-guard caller must not call a private reusable workflow.

Red first (policies/agent-test-quality.md §1), command:
  PYTHONPATH=tools python3 -m unittest tools.tests.test_runner_guard_public -v
Before this caller (workflow was only `uses: ittae/.github/...@main`):
  AssertionError: no public caller script in runner-guard.yml
  exit 1
After the `run: |` block:
  test_public_exits_0 ... ok
  test_private_exits_1 ... ok
  exit 0

Deliberate break (§3): the `run: |` condition compared REPO_PRIVATE to
"false" instead of "true". test_private_exits_1 failed (returncode 0 != 1)
and test_public_exits_0 failed (returncode 1 != 0). The condition was
restored. That flip left test_workflow_does_not_call_private_reusable
alive; the red run above is the break that kills it (private `uses:`
present, AssertionError on assertNotIn).
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "runner-guard.yml"
PRIVATE_USES = "uses: ittae/.github/.github/workflows/runner-guard.yml@main"
PRIVATE_STDERR = (
    "private repository must call the org runner-guard reusable, "
    "not this public caller"
)
PUBLIC_STDOUT = "public repository: hosted runners stay on GitHub"


def extract_run_script(text: str) -> str:
    """Return the first `run: |` block body from a workflow file."""
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.strip() == "run: |":
            start = index + 1
            break
    if start is None:
        raise AssertionError("no public caller script in runner-guard.yml")
    if start >= len(lines):
        raise AssertionError("public caller script is empty")
    indent = len(lines[start]) - len(lines[start].lstrip(" "))
    if indent == 0:
        raise AssertionError("public caller script is empty")
    body: list[str] = []
    for line in lines[start:]:
        if line.strip() == "":
            body.append("")
            continue
        if not line.startswith(" " * indent):
            break
        body.append(line[indent:])
    script = "\n".join(body).strip("\n")
    if not script:
        raise AssertionError("public caller script is empty")
    return script + "\n"


def run_caller(script: str, repo_private: str) -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "caller.sh"
        path.write_text(script, encoding="utf-8")
        env = os.environ.copy()
        env["REPO_PRIVATE"] = repo_private
        return subprocess.run(
            ["bash", str(path)],
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )


class TestRunnerGuardPublic(unittest.TestCase):
    def setUp(self) -> None:
        self.text = WORKFLOW.read_text(encoding="utf-8")

    def test_workflow_does_not_call_private_reusable(self) -> None:
        self.assertNotIn(PRIVATE_USES, self.text)

    def test_public_exits_0(self) -> None:
        proc = run_caller(extract_run_script(self.text), "false")
        self.assertEqual(proc.returncode, 0, msg=proc.stderr or proc.stdout)
        self.assertIn(PUBLIC_STDOUT, proc.stdout)

    def test_private_exits_1(self) -> None:
        proc = run_caller(extract_run_script(self.text), "true")
        self.assertEqual(proc.returncode, 1, msg=proc.stdout or proc.stderr)
        self.assertIn(PRIVATE_STDERR, proc.stderr)


if __name__ == "__main__":
    unittest.main()
