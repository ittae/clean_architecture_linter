#!/usr/bin/env python3
"""Host SoT validation cases for ~/.config/ittae/ai-review-engines (CAL / shared).

Covers:
  H1 missing file
  H2 unknown engine
  H3 bad model (charset / internal space)
  H4 partial pins (some engines model-less in unified line)
  H5 valid full pin line
  H6 non-monotonic order
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from ai_review_sot import (  # noqa: E402
    DEFAULT_MODELS,
    DEFAULT_ORDER,
    load_unified,
    parse_unified_line,
)
from resolve_ai_review_model import load_models  # noqa: E402


class TestHostFileMissing(unittest.TestCase):
    """H1 — host file missing → fail-open defaults."""

    def test_h1_load_unified_missing_returns_none(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            self.assertIsNone(load_unified(Path(td) / "ai-review-engines"))

    def test_h1_load_models_missing_legacy_path_is_default(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            # path= is legacy-only (skips unified). Do not pass unified_path —
            # it is ignored here, and path=None would read the real host file.
            r = load_models(
                path=Path(td) / "ai-review-model",
                skip_unified=True,
            )
            self.assertEqual(r["source"], "default")
            self.assertEqual(r["models"], dict(DEFAULT_MODELS))
            self.assertEqual(r["from_file"], [])


class TestInvalidEngine(unittest.TestCase):
    """H2 — unknown engine token invalidates whole unified line."""

    def test_h2_unknown_engine_in_unified(self) -> None:
        order, models, err = parse_unified_line("gemini:foo,codex:gpt-5.5")
        self.assertIsNone(order)
        self.assertEqual(models, {})
        self.assertEqual(err, "unknown:gemini")

    def test_h2_load_unified_invalid_has_error(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "ai-review-engines"
            p.write_text("openai:gpt-x,claude:claude-opus-4-8\n", encoding="utf-8")
            r = load_unified(p)
            assert r is not None
            self.assertIsNone(r["order"])
            self.assertIn("invalid-unified:unknown:openai", r["error"])


class TestInvalidModel(unittest.TestCase):
    """H3 — bad model charset / internal space."""

    def test_h3_model_with_space_rejected(self) -> None:
        order, models, err = parse_unified_line("codex:gpt 5.5")
        self.assertIsNone(order)
        self.assertEqual(models, {})
        self.assertEqual(err, "bad-model:codex")

    def test_h3_model_with_bang_rejected(self) -> None:
        order, models, err = parse_unified_line("codex:bad!")
        self.assertIsNone(order)
        self.assertTrue(str(err).startswith("bad-model:"))

    def test_h3_empty_model_after_colon_rejected(self) -> None:
        order, models, err = parse_unified_line("codex:,claude")
        self.assertIsNone(order)
        self.assertEqual(err, "bad-model:codex")


class TestPartialKeys(unittest.TestCase):
    """H4 — some engines pinned, others order-only → models_partial + DEFAULT fill."""

    def test_h4_parse_partial_pin(self) -> None:
        # codex pinned, claude order-only (no model in unified token)
        order, models, err = parse_unified_line("codex:gpt-5.5,claude")
        self.assertIsNone(err)
        self.assertEqual(order, ["codex", "claude"])
        self.assertEqual(models, {"codex": "gpt-5.5"})
        self.assertNotIn("claude", models)
        self.assertNotIn("grok", models)

    def test_h4_load_models_fills_defaults_for_unpinned(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            engines = root / "ai-review-engines"
            # valid unified with only codex model pin
            engines.write_text("codex:gpt-5.5,claude\n", encoding="utf-8")
            # path=None → default host resolution uses unified_path then legacy.
            r = load_models(unified_path=engines)
            self.assertEqual(r["source"], "unified")
            self.assertEqual(r["models"]["codex"], "gpt-5.5")
            # unpinned engines come from DEFAULT_MODELS
            self.assertEqual(r["models"]["claude"], DEFAULT_MODELS["claude"])
            self.assertEqual(r["models"]["grok"], DEFAULT_MODELS["grok"])
            self.assertEqual(r["from_file"], ["codex"])

    def test_h4_legacy_model_file_partial_is_mixed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            # force skip unified by missing/invalid: no unified file
            legacy = root / "ai-review-model"
            legacy.write_text("codex=gpt-5.5\n# only one key\n", encoding="utf-8")
            r = load_models(path=legacy, skip_unified=True)
            self.assertEqual(r["source"], "mixed")
            self.assertEqual(r["models"]["codex"], "gpt-5.5")
            self.assertEqual(r["models"]["grok"], DEFAULT_MODELS["grok"])
            self.assertEqual(r["models"]["claude"], DEFAULT_MODELS["claude"])
            self.assertEqual(r["from_file"], ["codex"])


class TestValidAndMonotonic(unittest.TestCase):
    """H5 valid full pin · H6 non-monotonic."""

    def test_h5_valid_full_live_style(self) -> None:
        line = "grok:grok-4.5,codex:gpt-5.5,claude:claude-opus-4-8"
        order, models, err = parse_unified_line(line)
        self.assertIsNone(err)
        self.assertEqual(order, list(DEFAULT_ORDER))
        self.assertEqual(
            models,
            {
                "grok": "grok-4.5",
                "codex": "gpt-5.5",
                "claude": "claude-opus-4-8",
            },
        )
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "ai-review-engines"
            p.write_text(f"# live\n{line}\n", encoding="utf-8")
            r = load_unified(p)
            assert r is not None
            self.assertIsNone(r["error"])
            self.assertEqual(r["order"], list(DEFAULT_ORDER))
            rm = load_models(unified_path=p)
            self.assertEqual(rm["source"], "unified")
            self.assertEqual(sorted(rm["from_file"]), ["claude", "codex", "grok"])
            self.assertEqual(rm["models"]["grok"], "grok-4.5")

    def test_h6_non_monotonic_rejected(self) -> None:
        order, models, err = parse_unified_line("claude,codex")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")

    def test_h6_codex_before_grok_rejected(self) -> None:
        order, models, err = parse_unified_line("codex,grok")
        self.assertIsNone(order)
        self.assertEqual(err, "non-monotonic-order")


class TestGithubEnvMappingContract(unittest.TestCase):
    """Document mapping resolve_ai_review_model outputs → GITHUB_ENV keys."""

    def test_emit_gha_writes_model_output_keys(self) -> None:
        # Workflow (#138) maps: grok_model→GROK_MODEL, codex_model→CODEX_MODEL,
        # claude_model→MODEL (historical CLAUDE env name).
        from io import StringIO
        from unittest.mock import patch
        from resolve_ai_review_model import emit_gha

        result = load_models(text="codex=gpt-5.5\n")
        buf = StringIO()
        with patch("sys.stdout", buf):
            emit_gha(result)
        out = buf.getvalue()
        self.assertIn("codex_model=gpt-5.5", out)
        self.assertIn("grok_model=", out)
        self.assertIn("claude_model=", out)
        for eng in ("grok", "codex", "claude"):
            self.assertIn(eng, DEFAULT_MODELS)


if __name__ == "__main__":
    unittest.main()
