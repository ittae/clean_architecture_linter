#!/usr/bin/env python3
"""Unit tests for tools/inject_reviewer_into_meta.py (ITT-2553 / ITT-2554)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from inject_reviewer_into_meta import (  # noqa: E402
    InjectError,
    extract_meta_json,
    inject_into_body,
    inject_reviewer_fields,
    require_reviewer_engine,
    rewrite_meta_block_in_body,
)

HELPER = REPO_ROOT / "tools" / "inject_reviewer_into_meta.py"


def _body(meta: dict) -> str:
    payload = json.dumps(meta, ensure_ascii=False)
    return (
        "## AI PR Review\n\n"
        f"<!-- ittae-ai-review-meta\n{payload}\n-->\n"
        "\nend\n"
    )


class TestInjectReviewerFields(unittest.TestCase):
    def test_u1_inject_preserves_counts(self) -> None:
        meta = {
            "iteration": 0,
            "head_sha": "a" * 40,
            "high": 0,
            "medium": 1,
            "low": 2,
            "verdict": "FAIL",
            "categories": ["Architecture"],
        }
        out = inject_reviewer_fields(
            meta, reviewer_engine="grok", reviewer_model="grok-4.5"
        )
        self.assertEqual(out["reviewer_engine"], "grok")
        self.assertEqual(out["reviewer_model"], "grok-4.5")
        self.assertEqual(out["high"], 0)
        self.assertEqual(out["medium"], 1)
        self.assertEqual(out["verdict"], "FAIL")
        self.assertEqual(out["categories"], ["Architecture"])

    def test_u2_overwrite_existing_engine(self) -> None:
        meta = {"high": 0, "reviewer_engine": "codex", "reviewer_model": "gpt-5.5"}
        out = inject_reviewer_fields(
            meta, reviewer_engine="grok", reviewer_model="grok-4.5"
        )
        self.assertEqual(out["reviewer_engine"], "grok")
        self.assertEqual(out["reviewer_model"], "grok-4.5")

    def test_u3_invalid_engine(self) -> None:
        for eng in ("", "gemini", "unknown"):
            with self.subTest(eng=eng), self.assertRaises(InjectError):
                inject_reviewer_fields(
                    {"high": 0}, reviewer_engine=eng, reviewer_model="x"
                )
        # strip+lower accepts padded allowlisted engines.
        out = inject_reviewer_fields(
            {"high": 0}, reviewer_engine="GROK ", reviewer_model="x"
        )
        self.assertEqual(out["reviewer_engine"], "grok")

    def test_u4_invalid_model(self) -> None:
        with self.assertRaises(InjectError):
            inject_reviewer_fields(
                {"high": 0}, reviewer_engine="grok", reviewer_model=""
            )
        with self.assertRaises(InjectError):
            inject_reviewer_fields(
                {"high": 0}, reviewer_engine="grok", reviewer_model="bad model!"
            )

    def test_u8_optional_run_fields(self) -> None:
        out = inject_reviewer_fields(
            {"high": 0},
            reviewer_engine="claude",
            reviewer_model="claude-opus-4-8",
            run_id="123",
            run_attempt="2",
            job="review",
        )
        self.assertEqual(out["run_id"], "123")
        self.assertEqual(out["run_attempt"], 2)
        self.assertEqual(out["job"], "review")

    def test_u9_idempotent(self) -> None:
        meta = {"high": 0, "medium": 0, "verdict": "PASS"}
        once = inject_reviewer_fields(
            meta, reviewer_engine="codex", reviewer_model="gpt-5.5"
        )
        twice = inject_reviewer_fields(
            once, reviewer_engine="codex", reviewer_model="gpt-5.5"
        )
        self.assertEqual(once, twice)


class TestBodyRewrite(unittest.TestCase):
    def test_u5_rewrite_single_block(self) -> None:
        meta = {
            "iteration": 0,
            "head_sha": "b" * 40,
            "high": 0,
            "medium": 0,
            "low": 0,
            "categories": [],
            "verdict": "PASS",
        }
        body = _body(meta)
        new_body = inject_into_body(
            body, reviewer_engine="grok", reviewer_model="grok-4.5"
        )
        self.assertEqual(new_body.count("<!-- ittae-ai-review-meta"), 1)
        parsed = extract_meta_json(new_body)
        self.assertEqual(parsed["reviewer_engine"], "grok")
        self.assertEqual(parsed["reviewer_model"], "grok-4.5")
        self.assertEqual(parsed["verdict"], "PASS")
        json.loads(
            new_body.split("<!-- ittae-ai-review-meta\n", 1)[1].split("\n-->", 1)[0]
        )

    def test_u6_missing_block_fail_closed(self) -> None:
        with self.assertRaises(InjectError):
            inject_into_body(
                "no meta here",
                reviewer_engine="grok",
                reviewer_model="grok-4.5",
            )
        with self.assertRaises(InjectError):
            rewrite_meta_block_in_body("no meta", {"high": 0})

    def test_u7_multiline_categories_roundtrip(self) -> None:
        # Pretty-printed multiline meta JSON inside the HTML comment.
        inner = json.dumps(
            {
                "high": 1,
                "medium": 0,
                "low": 0,
                "categories": ["Architecture", "Test"],
                "verdict": "FAIL",
                "head_sha": "c" * 40,
            },
            indent=2,
            ensure_ascii=False,
        )
        body = f"start\n<!-- ittae-ai-review-meta\n{inner}\n-->\nend\n"
        new_body = inject_into_body(
            body, reviewer_engine="claude", reviewer_model="claude-opus-4-8"
        )
        parsed = extract_meta_json(new_body)
        self.assertEqual(parsed["categories"], ["Architecture", "Test"])
        self.assertEqual(parsed["reviewer_engine"], "claude")
        self.assertEqual(parsed["high"], 1)

    def test_require_reviewer_engine(self) -> None:
        require_reviewer_engine({"reviewer_engine": "grok", "reviewer_model": "g"})
        with self.assertRaises(InjectError):
            require_reviewer_engine({"high": 0})
        with self.assertRaises(InjectError):
            require_reviewer_engine({"reviewer_engine": "unknown"})
        with self.assertRaises(InjectError):
            require_reviewer_engine({"reviewer_engine": "grok"})
        with self.assertRaises(InjectError):
            require_reviewer_engine(
                {"reviewer_engine": "grok", "reviewer_model": ""}
            )


class TestCli(unittest.TestCase):
    def _run(self, *args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(HELPER), *args],
            check=False,
            capture_output=True,
            text=True,
            input=input_text,
            cwd=str(REPO_ROOT),
        )

    def test_cli_in_place_and_require(self) -> None:
        meta = {
            "high": 0,
            "medium": 0,
            "verdict": "PASS",
            "head_sha": "d" * 40,
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review-result.md"
            path.write_text(_body(meta), encoding="utf-8")
            proc = self._run(
                "--body-file",
                str(path),
                "--engine",
                "codex",
                "--model",
                "gpt-5.5",
                "--run-id",
                "99",
                "--run-attempt",
                "1",
                "--job",
                "review",
                "--in-place",
                "--print-meta",
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            out_meta = json.loads(proc.stdout)
            self.assertEqual(out_meta["reviewer_engine"], "codex")
            self.assertEqual(out_meta["run_id"], "99")
            body = path.read_text(encoding="utf-8")
            self.assertIn('"reviewer_engine":"codex"', body.replace(" ", ""))

            ok = self._run(
                "--body-file",
                str(path),
                "--engine",
                "codex",
                "--model",
                "gpt-5.5",
                "--require-only",
            )
            self.assertEqual(ok.returncode, 0, ok.stderr)

    def test_cli_invalid_engine_nonzero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review-result.md"
            path.write_text(_body({"high": 0, "verdict": "PASS"}), encoding="utf-8")
            proc = self._run(
                "--body-file",
                str(path),
                "--engine",
                "gemini",
                "--model",
                "x",
                "--in-place",
            )
            self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
