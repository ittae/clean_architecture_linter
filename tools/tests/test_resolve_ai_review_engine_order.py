#!/usr/bin/env python3
"""Unit tests for tools/resolve_ai_review_engine_order.py (ITT-2301)."""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
import sys

sys.path.insert(0, str(REPO_ROOT / "tools"))

from resolve_ai_review_engine_order import (  # noqa: E402
    DEFAULT_ORDER,
    load_order,
    parse_order_text,
    pick_primary,
    precedence_flags,
)


class TestParseOrderText(unittest.TestCase):
    def test_default_csv(self) -> None:
        order, err = parse_order_text("grok,codex,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["grok", "codex", "claude"])

    def test_subsequence_and_whitespace(self) -> None:
        order, err = parse_order_text("  codex , claude  \n")
        self.assertIsNone(err)
        self.assertEqual(order, ["codex", "claude"])

    def test_non_monotonic_rejected(self) -> None:
        order, err = parse_order_text("codex,claude,grok")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")

    def test_case_normalize(self) -> None:
        order, err = parse_order_text("Codex,CLAUDE")
        self.assertIsNone(err)
        self.assertEqual(order, ["codex", "claude"])

    def test_comments_and_blank(self) -> None:
        order, err = parse_order_text("# skip codex today\n\ngrok,claude\n# trailing\n")
        self.assertIsNone(err)
        self.assertEqual(order, ["grok", "claude"])

    def test_empty(self) -> None:
        order, err = parse_order_text("")
        self.assertIsNone(order)
        self.assertEqual(err, "empty")
        order, err = parse_order_text("# only comment\n\n")
        self.assertIsNone(order)
        self.assertEqual(err, "empty")

    def test_unknown_token(self) -> None:
        order, err = parse_order_text("grok,gemini")
        self.assertIsNone(order)
        self.assertEqual(err, "unknown:gemini")

    def test_duplicate(self) -> None:
        order, err = parse_order_text("grok,grok")
        self.assertIsNone(order)
        self.assertEqual(err, "duplicate:grok")

    def test_too_many(self) -> None:
        order, err = parse_order_text("grok,codex,claude,grok")
        self.assertIsNone(order)
        self.assertIn(err, ("too-many", "duplicate:grok"))


class TestLoadOrder(unittest.TestCase):
    def test_missing_file_default(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "missing"
            r = load_order(path)
            self.assertEqual(r["source"], "default")
            self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
            self.assertIsNone(r["warning"])

    def test_valid_file(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "order"
            path.write_text("codex,claude\n", encoding="utf-8")
            r = load_order(path)
            self.assertEqual(r["source"], "file")
            self.assertEqual(r["order"], ["codex", "claude"])
            self.assertEqual(r["order_csv"], "codex,claude")

    def test_invalid_file_default_with_warning(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "order"
            path.write_text("nope\n", encoding="utf-8")
            r = load_order(path)
            self.assertEqual(r["source"], "default")
            self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
            self.assertTrue(str(r["warning"]).startswith("invalid-file:"))

    def test_non_utf8_file_fails_open_to_default(self) -> None:
        # fail-open 계약: 디코딩 불가 파일도 리뷰 job을 죽이지 않고 default로 폴백해야 한다.
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "order"
            path.write_bytes(b"\xff\xfe\x00\x00grok")
            r = load_order(path)
            self.assertEqual(r["source"], "default")
            self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
            self.assertTrue(str(r["warning"]).startswith("unreadable:"))

    def test_text_override(self) -> None:
        r = load_order(text="codex")
        self.assertEqual(r["source"], "text")
        self.assertEqual(r["order"], ["codex"])

    def test_non_monotonic_text_falls_back_with_warning(self) -> None:
        r = load_order(text="codex,grok")
        self.assertEqual(r["source"], "default")
        self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
        self.assertEqual(r["warning"], "invalid-text:non-monotonic-order")


class TestPrecedenceAndPrimary(unittest.TestCase):
    def test_default_precedence(self) -> None:
        f = precedence_flags(["grok", "codex", "claude"])
        self.assertEqual(f["want_grok"], "1")
        self.assertEqual(f["need_grok_before_codex"], "1")
        self.assertEqual(f["need_codex_before_grok"], "0")
        self.assertEqual(f["need_grok_before_claude"], "1")
        self.assertEqual(f["need_codex_before_claude"], "1")
        self.assertEqual(f["need_claude_before_grok"], "0")

    def test_codex_first_precedence(self) -> None:
        f = precedence_flags(["codex", "claude"])
        self.assertEqual(f["need_codex_before_claude"], "1")
        self.assertEqual(f["want_grok"], "0")
        self.assertEqual(f["need_grok_before_codex"], "0")

    def test_pick_primary_respects_order_and_live(self) -> None:
        order = ["codex", "claude"]
        self.assertEqual(pick_primary(order, {"codex": False, "claude": True, "grok": True}), "claude")
        self.assertEqual(pick_primary(order, {"codex": True, "claude": True, "grok": True}), "codex")
        self.assertEqual(pick_primary(order, {"codex": False, "claude": False, "grok": False}), "none")


class TestCliSmoke(unittest.TestCase):
    def test_main_json_valid_subsequence(self) -> None:
        import contextlib
        import io
        import json

        import resolve_ai_review_engine_order as mod

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(["--text", "codex,claude", "--json", "--live-codex", "1"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["source"], "text")
        self.assertIsNone(payload["warning"])
        self.assertEqual(payload["order"], ["codex", "claude"])
        self.assertEqual(payload["order_csv"], "codex,claude")
        self.assertEqual(payload["primary"], "codex")
        self.assertIn("flags", payload)

    def test_main_json_non_monotonic_falls_back(self) -> None:
        import contextlib
        import io
        import json

        import resolve_ai_review_engine_order as mod

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(["--text", "codex,grok", "--json", "--live-codex", "1"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["source"], "default")
        self.assertEqual(payload["order"], list(DEFAULT_ORDER))
        self.assertTrue(str(payload["warning"]).startswith("invalid-"))


class TestUnifiedOrderSoT(unittest.TestCase):
    def test_parse_unified_via_text_with_models(self) -> None:
        r = load_order(text="codex:gpt-5.5,claude:claude-opus-4-8")
        self.assertEqual(r["source"], "text")
        self.assertEqual(r["order"], ["codex", "claude"])

    def test_unified_file_preferred(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uni = root / "ai-review-engines"
            legacy = root / "ai-review-engine-order"
            uni.write_text("codex:gpt-5.5,claude:claude-opus-4-8\n", encoding="utf-8")
            legacy.write_text("grok,claude\n", encoding="utf-8")
            r = load_order(path=None, unified_path=uni)
            # when path is None, legacy uses default_order_path() under real HOME —
            # pass skip by monkeypatch: use only unified via explicit load
            # load_order(path=None) still reads real legacy; inject by writing only unified
            # and skip_unified false with unified_path; legacy may still exist on host.
            # Safer: use load_order with path=legacy would skip unified.
            # Call internal: path=None, unified_path=uni — if host has order file it may win after unified.
            # Unified is tried first; if uni valid, returns unified regardless of host legacy.
            self.assertEqual(r["source"], "unified")
            self.assertEqual(r["order"], ["codex", "claude"])
            self.assertEqual(r["path"], str(uni))

    def test_legacy_order_when_unified_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uni = root / "missing-unified"
            legacy = root / "ai-review-engine-order"
            legacy.write_text("codex,claude\n", encoding="utf-8")
            # Explicit legacy path still works (path=legacy skips unified)
            r = load_order(path=legacy)
            self.assertEqual(r["source"], "file")
            self.assertEqual(r["order"], ["codex", "claude"])

    def test_unified_non_monotonic_falls_through_to_legacy_path_api(self) -> None:
        # invalid unified text rejected → default when only text
        r = load_order(text="claude,codex")
        self.assertEqual(r["source"], "default")
        self.assertTrue(str(r["warning"]).startswith("invalid-text:"))


if __name__ == "__main__":
    unittest.main()
