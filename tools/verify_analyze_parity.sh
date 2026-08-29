#!/usr/bin/env bash
#
# Regression guard for the "flutter analyze drops plugin diagnostics" bug
# (ITT-1677 / ITT-1836).
#
# What this proves:
#   1. `tools/slice_contracts.json` declares at least one RULE_CODE per
#      lib/src/rules/<slice>/, and `dart analyze` on the fixture reports each
#      of those analysis_server_plugin diagnostics. This is the hard regression
#      gate — it fails CI if a slice contract stops emitting through the
#      recommended consumer path.
#   2. If a Flutter SDK is present, it also runs `flutter analyze` on the same
#      fixture and reports the diagnostic count. `flutter analyze` is known to
#      drop these diagnostics (its LSP client stops collecting when the core
#      analyzer's "Analyzing…" progress token ends, before the plugin isolate
#      publishes its diagnostics). That gap is DOCUMENTED, not a hard failure
#      here, so an upstream fix that closes it does not break CI.
#
# Recommended consumer path: run `dart analyze` (not `flutter analyze`) to
# enforce clean_architecture_linter. See docs/analysis/FLUTTER_ANALYZE_PLUGIN_LOSS.md.
#
# Usage:
#   tools/verify_analyze_parity.sh [fixture_dir] [--require-parity] [--contracts-only]
#
#   fixture_dir       Package to analyze. Default is the `fixture` field in
#                     tools/slice_contracts.json (or $SLICE_CONTRACTS_PATH).
#   --require-parity  Also fail if `flutter analyze` reports fewer diagnostics
#                     than `dart analyze` (opt-in; useful to verify an upstream
#                     Flutter fix once it lands).
#   --contracts-only  Check the contracts file only (no dart analyze). Each
#                     lib/src/rules/<slice>/ must declare ≥1 RULE_CODE. A
#                     positional fixture_dir is ignored in this mode.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_HELPER="$ROOT_DIR/tools/slice_contracts.py"
CONTRACTS_FILE="${SLICE_CONTRACTS_PATH:-$ROOT_DIR/tools/slice_contracts.json}"

FIXTURE_DIR=""
REQUIRE_PARITY=0
CONTRACTS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --require-parity) REQUIRE_PARITY=1 ;;
    --contracts-only) CONTRACTS_ONLY=1 ;;
    -*) echo "Unknown flag: $arg" >&2; exit 2 ;;
    *) FIXTURE_DIR="$arg" ;;
  esac
done

if [[ ! -f "$CONTRACTS_HELPER" ]]; then
  echo "Slice contract helper not found: $CONTRACTS_HELPER" >&2
  exit 2
fi
if [[ ! -f "$CONTRACTS_FILE" ]]; then
  echo "Slice contract file not found: $CONTRACTS_FILE" >&2
  exit 2
fi

echo "==> Slice contracts ($CONTRACTS_FILE)"
python3 "$CONTRACTS_HELPER" --contracts "$CONTRACTS_FILE" --check-manifest

DECLARED_FIXTURE="$(python3 "$CONTRACTS_HELPER" --contracts "$CONTRACTS_FILE" --print-fixture)"
if [[ -z "$DECLARED_FIXTURE" ]]; then
  echo "No fixture directory declared in $CONTRACTS_FILE" >&2
  exit 1
fi

if [[ "$CONTRACTS_ONLY" -eq 1 ]]; then
  echo "    fixture: $DECLARED_FIXTURE"
  echo "PASS: slice contract declarations only (skipped dart analyze)."
  exit 0
fi

if [[ -z "$FIXTURE_DIR" ]]; then
  FIXTURE_DIR="$DECLARED_FIXTURE"
fi
echo "    fixture: $FIXTURE_DIR"

FIXTURE_PATH="$ROOT_DIR/$FIXTURE_DIR"
if [[ ! -d "$FIXTURE_PATH" ]]; then
  echo "Fixture directory not found: $FIXTURE_PATH" >&2
  exit 2
fi

echo "==> Resolving plugin package and fixture ($FIXTURE_DIR)"
(cd "$ROOT_DIR" && dart pub get >/dev/null)
(cd "$FIXTURE_PATH" && dart pub get >/dev/null)

echo "==> dart analyze $FIXTURE_DIR (recommended consumer path)"
set +e
DART_OUT="$(cd "$FIXTURE_PATH" && dart analyze --format=machine 2>&1)"
set -e

# `dart analyze --format=machine` emits one row per diagnostic:
#   SEVERITY|TYPE|RULE_CODE|path|line|col|len|message
DART_DIAG_COUNT="$(printf '%s\n' "$DART_OUT" | grep -cE '^[A-Z]+\|[A-Z_]+\|' || true)"
echo "    dart analyze reported $DART_DIAG_COUNT plugin diagnostic(s)."

set +e
printf '%s\n' "$DART_OUT" | python3 "$CONTRACTS_HELPER" --contracts "$CONTRACTS_FILE" --check-analyze
ANALYZE_CONTRACT_STATUS=$?
set -e
if [[ "$ANALYZE_CONTRACT_STATUS" -ne 0 ]]; then
  echo "" >&2
  echo "REGRESSION: dart analyze did not report expected plugin diagnostic(s)." >&2
  echo "The analysis_server_plugin is not producing diagnostics through the" >&2
  echo "recommended consumer path. Investigate plugin loading / analyzer or" >&2
  echo "analysis_server_plugin compatibility before releasing." >&2
  echo "" >&2
  echo "--- dart analyze output ---" >&2
  printf '%s\n' "$DART_OUT" >&2
  exit 1
fi

# --- Optional flutter analyze parity check (documented known gap) -------------
if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter analyze $FIXTURE_DIR (known to drop plugin diagnostics)"
  set +e
  FLUTTER_OUT="$(cd "$FIXTURE_PATH" && flutter analyze 2>&1)"
  set -e
  # Flutter human-readable output (3.x):
  #   warning • message • path:line:col • rule_code
  #   2 issues found. (ran in 0.3s)
  # Legacy/alternate forms may use " - rule" or singular "1 issue found".
  if printf '%s\n' "$FLUTTER_OUT" | grep -qE 'No issues found'; then
    FLUTTER_DIAG_COUNT=0
  else
    SUMMARY_LINE="$(printf '%s\n' "$FLUTTER_OUT" | grep -E '[0-9]+ issues? found' | head -1 || true)"
    if [[ -n "$SUMMARY_LINE" ]]; then
      FLUTTER_DIAG_COUNT="$(printf '%s\n' "$SUMMARY_LINE" | grep -oE '[0-9]+ issues? found' | head -1 | grep -oE '^[0-9]+')"
    else
      # Fallback: count per-issue lines ending with " • rule_code" or " - rule_code"
      FLUTTER_DIAG_COUNT="$(printf '%s\n' "$FLUTTER_OUT" | grep -cE ' [•-] [a-z_0-9]+$' || true)"
    fi
  fi
  echo "    flutter analyze reported $FLUTTER_DIAG_COUNT diagnostic(s)."

  if [[ "$FLUTTER_DIAG_COUNT" -lt "$DART_DIAG_COUNT" ]]; then
    echo ""
    echo "NOTE: flutter analyze ($FLUTTER_DIAG_COUNT) < dart analyze ($DART_DIAG_COUNT)."
    echo "This is the DOCUMENTED flutter_tools gap: flutter analyze stops"
    echo "collecting when the core analyzer's progress token ends, before the"
    echo "plugin isolate publishes its diagnostics. Consumers MUST run"
    echo "'dart analyze' to enforce clean_architecture_linter."
    echo "See docs/analysis/FLUTTER_ANALYZE_PLUGIN_LOSS.md"
    if [[ "$REQUIRE_PARITY" -eq 1 ]]; then
      echo "--require-parity set: failing because parity is not met." >&2
      exit 1
    fi
  else
    echo "    flutter analyze parity holds (upstream gap may be fixed)."
  fi
else
  echo "==> flutter not found; skipping flutter analyze parity check."
  echo "    (CI Dart-only runners skip this; the dart analyze gate above still runs.)"
  if [[ "$REQUIRE_PARITY" -eq 1 ]]; then
    echo "--require-parity set but flutter is not available; cannot verify parity." >&2
    exit 2
  fi
fi

echo ""
echo "PASS: plugin diagnostics verified via dart analyze."
