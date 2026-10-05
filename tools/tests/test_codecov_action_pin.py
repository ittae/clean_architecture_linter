#!/usr/bin/env python3
"""CI must not pin the legacy Codecov Node uploader.

codecov-action v1–v3 download https://uploader.codecov.io. That host rejects
the TLS handshake (SSL alert 40) and the v3 action exits 1 before
fail_ci_if_error applies, so the coverage job fails even when tests passed.
v4 and later use the Codecov CLI.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = REPO_ROOT / ".github" / "workflows"

_USES_RE = re.compile(
    r"uses:\s*codecov/codecov-action@(?P<ref>\S+)"
)
_MAJOR_RE = re.compile(r"^v(?P<major>\d+)(?:\.\d+)*$")
# Legacy Node uploader. v4+ speaks to cli.codecov.io instead.
_MIN_MAJOR = 4


def codecov_action_refs(text: str) -> list[str]:
    return [match.group("ref") for match in _USES_RE.finditer(text)]


def legacy_codecov_pins(refs: list[str]) -> list[str]:
    legacy: list[str] = []
    for ref in refs:
        major = _MAJOR_RE.match(ref)
        if major is None or int(major.group("major")) < _MIN_MAJOR:
            legacy.append(ref)
    return legacy


class TestCodecovActionPin(unittest.TestCase):
    def test_live_workflows_avoid_legacy_uploader(self) -> None:
        self.assertTrue(WORKFLOWS.is_dir(), msg=str(WORKFLOWS))
        offenders: list[str] = []
        for path in sorted(WORKFLOWS.glob("*.yml")) + sorted(
            WORKFLOWS.glob("*.yaml")
        ):
            text = path.read_text(encoding="utf-8")
            if "uploader.codecov.io" in text:
                offenders.append(f"{path.name}: references uploader.codecov.io")
            for ref in legacy_codecov_pins(codecov_action_refs(text)):
                offenders.append(f"{path.name}: codecov/codecov-action@{ref}")
        self.assertEqual(offenders, [])

    def test_v3_pin_is_legacy(self) -> None:
        text = "uses: codecov/codecov-action@v3\n"
        self.assertEqual(legacy_codecov_pins(codecov_action_refs(text)), ["v3"])

    def test_v7_pin_is_allowed(self) -> None:
        text = "uses: codecov/codecov-action@v7\n"
        self.assertEqual(legacy_codecov_pins(codecov_action_refs(text)), [])

    def test_unpinned_ref_is_legacy(self) -> None:
        text = "uses: codecov/codecov-action@main\n"
        self.assertEqual(
            legacy_codecov_pins(codecov_action_refs(text)),
            ["main"],
        )
