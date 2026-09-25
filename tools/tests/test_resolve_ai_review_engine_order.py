#!/usr/bin/env python3
"""Unit tests for tools/resolve_ai_review_engine_order.py (ITT-2301)."""
from __future__ import annotations

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
        order, err = parse_order_text("grok,cursor,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["grok", "cursor", "claude"])

    def test_subsequence_and_whitespace(self) -> None:
        order, err = parse_order_text("  cursor , claude  \n")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])

    def test_non_monotonic_rejected(self) -> None:
        order, err = parse_order_text("cursor,claude,grok")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")

    def test_case_normalize(self) -> None:
        order, err = parse_order_text("Cursor,CLAUDE")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])

    def test_comments_and_blank(self) -> None:
        order, err = parse_order_text("# skip cursor today\n\ngrok,claude\n# trailing\n")
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
        # Five tokens > len(ALLOWED)=4 → the length guard fires before any
        # duplicate check (duplicates are covered by test_duplicate).
        order, err = parse_order_text("grok,cursor,claude,codex,grok")
        self.assertIsNone(order)
        self.assertEqual(err, "too-many")


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
            path.write_text("cursor,claude\n", encoding="utf-8")
            r = load_order(path)
            self.assertEqual(r["source"], "file")
            self.assertEqual(r["order"], ["cursor", "claude"])
            self.assertEqual(r["order_csv"], "cursor,claude")

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
        r = load_order(text="cursor")
        self.assertEqual(r["source"], "text")
        self.assertEqual(r["order"], ["cursor"])

    def test_non_monotonic_text_falls_back_with_warning(self) -> None:
        r = load_order(text="cursor,grok")
        self.assertEqual(r["source"], "default")
        self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
        self.assertEqual(r["warning"], "invalid-text:non-monotonic-order")


class TestPrecedenceAndPrimary(unittest.TestCase):
    def test_default_precedence(self) -> None:
        f = precedence_flags(["grok", "cursor", "claude"])
        self.assertEqual(f["want_grok"], "1")
        self.assertEqual(f["need_grok_before_cursor"], "1")
        self.assertEqual(f["need_cursor_before_grok"], "0")
        self.assertEqual(f["need_grok_before_claude"], "1")
        self.assertEqual(f["need_cursor_before_claude"], "1")
        self.assertEqual(f["need_claude_before_grok"], "0")

    def test_cursor_first_precedence(self) -> None:
        f = precedence_flags(["cursor", "claude"])
        self.assertEqual(f["need_cursor_before_claude"], "1")
        self.assertEqual(f["want_grok"], "0")
        self.assertEqual(f["need_grok_before_cursor"], "0")

    def test_pick_primary_respects_order_and_live(self) -> None:
        order = ["cursor", "claude"]
        self.assertEqual(pick_primary(order, {"cursor": False, "claude": True, "grok": True}), "claude")
        self.assertEqual(pick_primary(order, {"cursor": True, "claude": True, "grok": True}), "cursor")
        self.assertEqual(pick_primary(order, {"cursor": False, "claude": False, "grok": False}), "none")


class TestCliSmoke(unittest.TestCase):
    def test_main_json_valid_subsequence(self) -> None:
        import contextlib
        import io
        import json

        import resolve_ai_review_engine_order as mod

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(["--text", "cursor,claude", "--json", "--live-cursor", "1"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["source"], "text")
        self.assertIsNone(payload["warning"])
        self.assertEqual(payload["order"], ["cursor", "claude"])
        self.assertEqual(payload["order_csv"], "cursor,claude")
        self.assertEqual(payload["primary"], "cursor")
        self.assertIn("flags", payload)

    def test_main_json_non_monotonic_falls_back(self) -> None:
        import contextlib
        import io
        import json

        import resolve_ai_review_engine_order as mod

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(["--text", "cursor,grok", "--json", "--live-cursor", "1"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["source"], "default")
        self.assertEqual(payload["order"], list(DEFAULT_ORDER))
        self.assertTrue(str(payload["warning"]).startswith("invalid-"))

    def test_stderr_warning_sanitizes_newlines(self) -> None:
        import contextlib
        import io

        import resolve_ai_review_engine_order as mod

        # unreadable warning can carry exception text with newlines
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "order"
            path.write_bytes(b"\xff\xfe")
            out = io.StringIO()
            err = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = mod.main(["--path", str(path)])
            self.assertEqual(rc, 0)
            err_text = err.getvalue()
            warning_lines = [
                ln for ln in err_text.splitlines() if ln.startswith("::warning::")
            ]
            self.assertEqual(len(warning_lines), 1)
            # workflow command must be a single line (no embedded newline split)
            self.assertNotIn("\n", warning_lines[0])
            self.assertIn("unreadable:", warning_lines[0])
            self.assertEqual(err_text.count("\n"), 1)

    def test_path_help_mentions_legacy_only(self) -> None:
        import contextlib
        import io

        import resolve_ai_review_engine_order as mod

        help_buf = io.StringIO()
        with self.assertRaises(SystemExit) as cm:
            with contextlib.redirect_stdout(help_buf):
                mod.main(["--help"])
        self.assertEqual(cm.exception.code, 0)
        help_text = help_buf.getvalue()
        self.assertIn("legacy order file only", help_text)
        self.assertNotIn("config path (default:", help_text)


class TestUnifiedOrderSoT(unittest.TestCase):
    def test_parse_unified_via_text_with_models(self) -> None:
        r = load_order(text="cursor:composer-2.5,claude:claude-opus-4-8")
        self.assertEqual(r["source"], "text")
        self.assertEqual(r["order"], ["cursor", "claude"])

    def test_unified_file_preferred(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uni = root / "ai-review-engines"
            uni.write_text("cursor:composer-2.5,claude:claude-opus-4-8\n", encoding="utf-8")
            # Unified is tried first; a valid unified file wins regardless of
            # any legacy order file (host or fixture), so none is written here.
            r = load_order(path=None, unified_path=uni)
            self.assertEqual(r["source"], "unified")
            self.assertEqual(r["order"], ["cursor", "claude"])
            self.assertEqual(r["path"], str(uni))

    def test_legacy_order_when_unified_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            legacy = root / "ai-review-engine-order"
            legacy.write_text("cursor,claude\n", encoding="utf-8")
            # Explicit legacy path still works (path=legacy skips unified)
            r = load_order(path=legacy)
            self.assertEqual(r["source"], "file")
            self.assertEqual(r["order"], ["cursor", "claude"])

    def test_unified_non_monotonic_falls_through_to_legacy_path_api(self) -> None:
        # invalid unified text rejected → default when only text
        r = load_order(text="claude,cursor")
        self.assertEqual(r["source"], "default")
        self.assertTrue(str(r["warning"]).startswith("invalid-text:"))


class TestCursorSlot(unittest.TestCase):
    """2026-09-24: cursor holds codex's former slot; codex is the last fallback."""

    def test_full_default_order_with_models(self) -> None:
        order, err = parse_order_text("grok,cursor,claude,codex")
        self.assertIsNone(err)
        self.assertEqual(order, ["grok", "cursor", "claude", "codex"])

    def test_codex_before_claude_is_non_monotonic_now(self) -> None:
        order, err = parse_order_text("codex,claude")
        self.assertEqual(err, "non-monotonic-order")
        self.assertIsNone(order)

    def test_json_exposes_consumer_contract(self) -> None:
        import io, json
        import resolve_ai_review_engine_order as mod
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = mod.main(["--text", "grok:grok-4.6,cursor:kimi-k2.7-code,claude", "--json"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["allowed"], list(mod.ALLOWED))
        self.assertEqual(payload["default_order"], list(mod.DEFAULT_ORDER))
        self.assertEqual(payload["models"]["cursor"], "kimi-k2.7-code")
        self.assertEqual(payload["models"]["grok"], "grok-4.6")
        self.assertEqual(payload["models"]["codex"], mod.DEFAULT_MODELS["codex"])
        self.assertEqual(set(payload["models"]), set(mod.ALLOWED))
        self.assertIsInstance(payload["engine_timeout_sec"], int)
        self.assertGreater(payload["engine_timeout_sec"], 0)

    def test_owner_legacy_grok_claude_still_valid(self) -> None:
        order, err = parse_order_text("grok,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["grok", "claude"])


if __name__ == "__main__":
    unittest.main()
