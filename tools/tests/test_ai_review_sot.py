#!/usr/bin/env python3
"""Unit tests for tools/ai_review_sot.py (ITT-2477)."""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from ai_review_sot import load_unified, parse_unified_line, parse_unified_text  # noqa: E402
import ai_review_sot as sot  # noqa: E402


class TestParseUnified(unittest.TestCase):
    def test_order_only(self) -> None:
        order, models, err = parse_unified_line("cursor,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])
        self.assertEqual(models, {})

    def test_with_models(self) -> None:
        order, models, err = parse_unified_line("cursor:composer-2.5,claude:claude-opus-4-8")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])
        self.assertEqual(models["cursor"], "composer-2.5")

    def test_mixed_pin_and_default(self) -> None:
        order, models, err = parse_unified_line("cursor:composer-2.5,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])
        self.assertEqual(models, {"cursor": "composer-2.5"})

    def test_non_monotonic(self) -> None:
        order, models, err = parse_unified_line("claude,cursor")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")

    def test_comments(self) -> None:
        order, models, err = parse_unified_text("# live\n\ncursor,claude\n")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])

    def test_bad_model(self) -> None:
        order, models, err = parse_unified_line("cursor:bad model!")
        self.assertIsNone(order)
        self.assertTrue(str(err).startswith("bad-model:"))

    def test_empty_model_pin_rejected(self) -> None:
        order, models, err = parse_unified_line("cursor:,claude")
        self.assertIsNone(order)
        self.assertEqual(err, "bad-model:cursor")

    def test_model_internal_space_rejected(self) -> None:
        """Spaces inside model IDs must not be stripped into a valid pin (M1)."""
        order, models, err = parse_unified_line("cursor:gpt 5.5")
        self.assertIsNone(order)
        self.assertEqual(models, {})
        self.assertEqual(err, "bad-model:cursor")

    def test_csv_edge_spaces_ok(self) -> None:
        order, models, err = parse_unified_line("  cursor:composer-2.5 , claude:claude-opus-4-8  ")
        self.assertIsNone(err)
        self.assertEqual(order, ["cursor", "claude"])
        self.assertEqual(models["cursor"], "composer-2.5")


class TestLoadUnified(unittest.TestCase):
    def test_missing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            self.assertIsNone(load_unified(Path(td) / "nope"))

    def test_valid(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "ai-review-engines"
            p.write_text("cursor:composer-2.5,claude:claude-opus-4-8\n", encoding="utf-8")
            r = load_unified(p)
            assert r is not None
            self.assertIsNone(r["error"])
            self.assertEqual(r["order"], ["cursor", "claude"])
            self.assertEqual(r["models_partial"]["cursor"], "composer-2.5")


class TestSharedEngineTimeoutAndModels(unittest.TestCase):
    def test_timeout_default_and_env_override(self) -> None:
        self.assertEqual(sot.resolve_engine_timeout({}), sot.ENGINE_TIMEOUT_SEC)
        self.assertEqual(sot.resolve_engine_timeout({sot.ENGINE_TIMEOUT_ENV: "300"}), 300)
        self.assertEqual(sot.resolve_engine_timeout({sot.ENGINE_TIMEOUT_ENV: "0"}), sot.ENGINE_TIMEOUT_SEC)
        self.assertEqual(sot.resolve_engine_timeout({sot.ENGINE_TIMEOUT_ENV: "abc"}), sot.ENGINE_TIMEOUT_SEC)

    def test_overlay_models_keeps_defaults_and_ignores_unknown(self) -> None:
        models = sot.overlay_models({"cursor": "kimi-k2.7-code", "nope": "x"})
        self.assertEqual(models["cursor"], "kimi-k2.7-code")
        self.assertEqual(models["grok"], sot.DEFAULT_MODELS["grok"])
        self.assertNotIn("nope", models)
        self.assertEqual(set(models), set(sot.ALLOWED))


if __name__ == "__main__":
    unittest.main()
