#!/usr/bin/env python3
"""Unit tests for tools/resolve_ai_review_engine_order.py."""
from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from resolve_ai_review_engine_order import (  # noqa: E402
    DEFAULT_ORDER,
    load_order,
    parse_order_text,
    parse_unified_text,
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


class TestParseUnifiedText(unittest.TestCase):
    def test_engine_only_tokens(self) -> None:
        order, models, err = parse_unified_text("codex,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["codex", "claude"])
        self.assertEqual(models, {})

    def test_model_pins_stripped_for_order(self) -> None:
        order, models, err = parse_unified_text("codex:gpt-5.5,claude:claude-opus-4-8")
        self.assertIsNone(err)
        self.assertEqual(order, ["codex", "claude"])
        self.assertEqual(models, {"codex": "gpt-5.5", "claude": "claude-opus-4-8"})

    def test_empty_model_pin_rejected(self) -> None:
        # host parse_unified_line rejects "codex:" as bad-model
        order, models, err = parse_unified_text("codex:,claude")
        self.assertIsNone(order)
        self.assertEqual(models, {})
        self.assertEqual(err, "bad-model:codex")

    def test_bad_model_charset_rejected(self) -> None:
        order, models, err = parse_unified_text("codex:bad!")
        self.assertIsNone(order)
        self.assertTrue(str(err).startswith("bad-model:"))

    def test_non_monotonic_rejected(self) -> None:
        order, models, err = parse_unified_text("claude,codex")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")


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

    def test_empty_model_pin_text_falls_back(self) -> None:
        # parse_order_text sees "codex:" as unknown; unified path rejects empty pin.
        # Either error path must fail-open to default (not accept engine-only).
        r = load_order(text="codex:,claude")
        self.assertEqual(r["source"], "default")
        self.assertEqual(tuple(r["order"]), DEFAULT_ORDER)
        self.assertTrue(str(r["warning"]).startswith("invalid-text:"))
        order, _models, u_err = parse_unified_text("codex:,claude")
        self.assertIsNone(order)
        self.assertEqual(u_err, "bad-model:codex")


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
        self.assertEqual(
            pick_primary(order, {"codex": False, "claude": True, "grok": True}),
            "claude",
        )
        self.assertEqual(
            pick_primary(order, {"codex": True, "claude": True, "grok": True}),
            "codex",
        )
        self.assertEqual(
            pick_primary(order, {"codex": False, "claude": False, "grok": False}),
            "none",
        )


class TestCliSmoke(unittest.TestCase):
    def test_main_json_valid_subsequence(self) -> None:
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
        import resolve_ai_review_engine_order as mod

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mod.main(["--text", "codex,grok", "--json", "--live-codex", "1"])
        self.assertEqual(rc, 0)
        payload = json.loads(buf.getvalue())
        self.assertEqual(payload["source"], "default")
        self.assertEqual(payload["order"], list(DEFAULT_ORDER))
        self.assertTrue(str(payload["warning"]).startswith("invalid-"))

    def test_stderr_warning_sanitizes_newlines(self) -> None:
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

    def test_path_help_mentions_legacy_only(self) -> None:
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
        r = load_order(text="codex:gpt-5.5,claude:claude-opus-4-8")
        self.assertEqual(r["source"], "text")
        self.assertEqual(r["order"], ["codex", "claude"])

    def test_unified_file_preferred(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            uni = root / "ai-review-engines"
            uni.write_text("codex:gpt-5.5,claude:claude-opus-4-8\n", encoding="utf-8")
            r = load_order(path=None, unified_path=uni)
            self.assertEqual(r["source"], "unified")
            self.assertEqual(r["order"], ["codex", "claude"])
            self.assertEqual(r["path"], str(uni))

    def test_legacy_order_when_unified_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            legacy = root / "ai-review-engine-order"
            legacy.write_text("codex,claude\n", encoding="utf-8")
            r = load_order(path=legacy)
            self.assertEqual(r["source"], "file")
            self.assertEqual(r["order"], ["codex", "claude"])

    def test_unified_non_monotonic_falls_through_to_legacy_path_api(self) -> None:
        r = load_order(text="claude,codex")
        self.assertEqual(r["source"], "default")
        self.assertTrue(str(r["warning"]).startswith("invalid-text:"))


if __name__ == "__main__":
    unittest.main()
