#!/usr/bin/env python3
"""Units for tools/slice_contracts.py + tools/slice_contracts.json."""
from __future__ import annotations

import json
import subprocess
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
    fixture_dir,
    fixture_escapes_repo,
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
        self.assertEqual(raw.get("fixture"), fixture_dir(load_contracts()))
        self.assertTrue((REPO_ROOT / fixture_dir(load_contracts())).is_dir())

    def test_missing_fixture_dir_fails_closed(self) -> None:
        data = dict(load_contracts())
        data["fixture"] = "does/not/exist"
        errors = check_manifest(data)
        self.assertTrue(any("does/not/exist" in error for error in errors))

    def test_invalid_json_shape_raises(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "slice_contracts.json"
            path.write_text("[]\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                load_contracts(path)

    def test_check_analyze_cli_fails_on_missing_code(self) -> None:
        helper = REPO_ROOT / "tools" / "slice_contracts.py"
        machine = "WARNING|LINT|PRESENTATION_NO_THROW|lib/a.dart|1|1|1|msg\n"
        result = subprocess.run(
            [sys.executable, str(helper), "--check-analyze"],
            input=machine,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_malformed_entry_fails_closed(self) -> None:
        data = load_contracts()
        slices = dict(data["slices"])
        slices["data_rules"] = [
            {"code": "REPOSITORY_PASS_THROUGH"},
            {"codes": "LAYER_DEPENDENCY"},
        ]
        data = {**data, "slices": slices}
        errors = check_manifest(data)
        self.assertTrue(
            any("invalid contract entry in data_rules[1]" in error for error in errors)
        )

    def test_absolute_fixture_fails_closed(self) -> None:
        self.assertTrue(fixture_escapes_repo("/tmp/outside"))
        self.assertTrue(fixture_escapes_repo(r"C:\Windows"))
        self.assertTrue(fixture_escapes_repo("C:/Windows"))
        self.assertTrue(fixture_escapes_repo("../outside"))
        self.assertFalse(fixture_escapes_repo("poc_v2/example"))
        data = dict(load_contracts())
        data["fixture"] = "/tmp/outside"
        errors = check_manifest(data)
        self.assertTrue(any("relative path" in error for error in errors))

    def test_contracts_only_ignores_positional_fixture_dir(self) -> None:
        script = REPO_ROOT / "tools" / "verify_analyze_parity.sh"
        result = subprocess.run(
            ["bash", str(script), "--contracts-only", "some/dir"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("fixture: poc_v2/example", result.stdout)
        self.assertNotIn("fixture: some/dir", result.stdout)

    def test_print_codes_fails_on_malformed_entry(self) -> None:
        helper = REPO_ROOT / "tools" / "slice_contracts.py"
        data = load_contracts()
        slices = dict(data["slices"])
        slices["data_rules"] = [{"codes": "REPOSITORY_PASS_THROUGH"}]
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "slice_contracts.json"
            path.write_text(json.dumps({**data, "slices": slices}), encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(helper),
                    "--contracts",
                    str(path),
                    "--print-codes",
                ],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(result.returncode, 0)

    def test_print_and_check_flags_are_exclusive(self) -> None:
        helper = REPO_ROOT / "tools" / "slice_contracts.py"
        result = subprocess.run(
            [
                sys.executable,
                str(helper),
                "--print-codes",
                "--check-manifest",
            ],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
