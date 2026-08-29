#!/usr/bin/env python3
"""Units for tools/slice_contracts.py + tools/slice_contracts.json."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from slice_contracts import (  # noqa: E402
    check_manifest,
    discover_slices,
    expected_codes,
    load_contracts,
    missing_codes,
)


class TestSliceContractsManifest(unittest.TestCase):
    def test_every_rule_slice_has_at_least_one_code(self) -> None:
        data = load_contracts()
        slices = discover_slices()
        self.assertGreaterEqual(len(slices), 1)
        self.assertEqual(check_manifest(data, slices), [])
        self.assertGreaterEqual(len(expected_codes(data)), len(slices))

    def test_missing_slice_fails_closed(self) -> None:
        data = load_contracts()
        slices = discover_slices() + ["not_a_real_slice"]
        errors = check_manifest(data, slices)
        self.assertTrue(any("not_a_real_slice" in error for error in errors))

    def test_broken_analyze_contract_is_detected(self) -> None:
        machine = (
            "WARNING|LINT|PRESENTATION_NO_THROW|lib/a.dart|1|1|1|msg\n"
            "WARNING|LINT|DOMAIN_PURITY|lib/b.dart|1|1|1|msg\n"
        )
        missing = missing_codes(
            machine,
            ["PRESENTATION_NO_THROW", "DOMAIN_PURITY", "LAYER_DEPENDENCY"],
        )
        self.assertEqual(missing, ["LAYER_DEPENDENCY"])

    def test_contracts_json_is_object_with_slices(self) -> None:
        raw = json.loads(
            (REPO_ROOT / "tools" / "slice_contracts.json").read_text(encoding="utf-8")
        )
        self.assertIsInstance(raw, dict)
        self.assertIn("slices", raw)
        self.assertIsInstance(raw["slices"], dict)

    def test_invalid_json_shape_raises(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "slice_contracts.json"
            path.write_text("[]\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                load_contracts(path)


if __name__ == "__main__":
    unittest.main()
