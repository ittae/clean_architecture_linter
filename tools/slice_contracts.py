#!/usr/bin/env python3
"""Slice pass-contracts for plugin dart-analyze.

Declaration: tools/slice_contracts.json
Each directory under lib/src/rules/ must have at least one machine-format
RULE_CODE. tools/verify_analyze_parity.sh uses this helper as the gate.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONTRACTS = REPO_ROOT / "tools" / "slice_contracts.json"
RULES_DIR = REPO_ROOT / "lib" / "src" / "rules"
MACHINE_CODE = re.compile(r"^[A-Z][A-Z0-9_]*$")
MACHINE_ROW = re.compile(r"^[A-Z]+\|[A-Z_]+\|([^|]+)\|")


def load_contracts(path: Path | None = None) -> dict[str, Any]:
    contracts_path = path or DEFAULT_CONTRACTS
    data = json.loads(contracts_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{contracts_path} must be a JSON object")
    slices = data.get("slices")
    if not isinstance(slices, dict) or not slices:
        raise ValueError(f"{contracts_path} must declare a non-empty slices object")
    try:
        fixture_dir(data)
    except ValueError as exc:
        raise ValueError(f"{contracts_path} must declare a non-empty fixture path") from exc
    return data


def fixture_dir(data: dict[str, Any]) -> str:
    fixture = data.get("fixture")
    if not isinstance(fixture, str) or not fixture.strip():
        raise ValueError("contracts must declare fixture")
    return fixture.strip()


def discover_slices(rules_dir: Path | None = None) -> list[str]:
    root = rules_dir or RULES_DIR
    return sorted(
        p.name
        for p in root.iterdir()
        if p.is_dir() and not p.name.startswith(".")
    )


def expected_codes(data: dict[str, Any]) -> list[str]:
    codes: list[str] = []
    for entries in (data.get("slices") or {}).values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if isinstance(entry, dict):
                code = entry.get("code")
                if isinstance(code, str) and code:
                    codes.append(code)
    return codes


def missing_slices(data: dict[str, Any], slices: list[str]) -> list[str]:
    declared = data.get("slices") or {}
    missing: list[str] = []
    for slice_id in slices:
        entries = declared.get(slice_id)
        if not isinstance(entries, list) or not any(
            isinstance(entry, dict) and isinstance(entry.get("code"), str) and entry["code"]
            for entry in entries
        ):
            missing.append(slice_id)
    return missing


def extra_slices(data: dict[str, Any], slices: list[str]) -> list[str]:
    declared = set((data.get("slices") or {}).keys())
    return sorted(declared - set(slices))


def invalid_codes(codes: list[str]) -> list[str]:
    return [code for code in codes if not MACHINE_CODE.match(code)]


def present_codes(machine_output: str) -> set[str]:
    found: set[str] = set()
    for line in machine_output.splitlines():
        match = MACHINE_ROW.match(line)
        if match:
            found.add(match.group(1))
    return found


def missing_codes(machine_output: str, codes: list[str]) -> list[str]:
    found = present_codes(machine_output)
    return [code for code in codes if code not in found]


def check_manifest(
    data: dict[str, Any],
    slices: list[str] | None = None,
    repo_root: Path | None = None,
) -> list[str]:
    slice_ids = slices if slices is not None else discover_slices()
    root = repo_root or REPO_ROOT
    errors: list[str] = []
    missing = missing_slices(data, slice_ids)
    if missing:
        errors.append("missing contract for slice(s): " + ", ".join(missing))
    extra = extra_slices(data, slice_ids)
    if extra:
        errors.append("unknown slice id(s): " + ", ".join(extra))
    codes = expected_codes(data)
    invalid = invalid_codes(codes)
    if invalid:
        errors.append("invalid machine RULE_CODE(s): " + ", ".join(invalid))
    if not codes:
        errors.append("no contract codes declared")
    try:
        fixture = fixture_dir(data)
    except ValueError as exc:
        errors.append(str(exc))
    else:
        if fixture.startswith("/") or ".." in Path(fixture).parts:
            errors.append(f"fixture must be a relative path inside the repo: {fixture}")
        elif not (root / fixture).is_dir():
            errors.append(f"fixture directory not found: {fixture}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contracts", type=Path, default=DEFAULT_CONTRACTS)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--check-manifest",
        action="store_true",
        help="require at least one contract per lib/src/rules slice",
    )
    mode.add_argument(
        "--check-analyze",
        action="store_true",
        help="read dart analyze --format=machine output from stdin",
    )
    mode.add_argument(
        "--print-codes",
        action="store_true",
        help="print declared RULE_CODE values, one per line",
    )
    mode.add_argument(
        "--print-fixture",
        action="store_true",
        help="print the declared fixture directory (repo-relative)",
    )
    args = parser.parse_args(argv)

    data = load_contracts(args.contracts)
    if args.print_codes:
        for code in expected_codes(data):
            print(code)
        return 0
    if args.print_fixture:
        print(fixture_dir(data))
        return 0

    if args.check_manifest:
        errors = check_manifest(data)
        if errors:
            for error in errors:
                print(f"CONTRACT FAIL: {error}", file=sys.stderr)
            return 1
        codes = ", ".join(expected_codes(data))
        print(f"CONTRACT OK: all slices declared ({codes})")
        return 0

    machine_output = sys.stdin.read()
    missing = missing_codes(machine_output, expected_codes(data))
    if missing:
        print(
            "CONTRACT FAIL: dart analyze missing RULE_CODE(s): "
            + " ".join(missing),
            file=sys.stderr,
        )
        return 1
    print(
        "CONTRACT OK: all declared plugin diagnostics present via dart analyze."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
