#!/usr/bin/env bash
#
# Regression guard for the "flutter analyze drops plugin diagnostics" bug
# (ITT-1677 / ITT-1836).
#
# What this proves:
#   1. `dart analyze` on the bad fixture reports the analysis_server_plugin
#      diagnostics (the plugin still loads and produces warnings). This is the
#      hard regression gate — it fails CI if the plugin ever stops emitting
#      diagnostics through the recommended consumer path.
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
#   tools/verify_analyze_parity.sh [fixture_dir] [--require-parity]
#
#   fixture_dir       Package to analyze (default: poc_v2/example).
#   --require-parity  Also fail if `flutter analyze` reports fewer diagnostics
#                     than `dart analyze` (opt-in; useful to verify an upstream
#                     Flutter fix once it lands).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FIXTURE_DIR="poc_v2/example"
REQUIRE_PARITY=0
for arg in "$@"; do
  case "$arg" in
    --require-parity) REQUIRE_PARITY=1 ;;
    -*) echo "Unknown flag: $arg" >&2; exit 2 ;;
    *) FIXTURE_DIR="$arg" ;;
  esac
done

FIXTURE_PATH="$ROOT_DIR/$FIXTURE_DIR"
if [[ ! -d "$FIXTURE_PATH" ]]; then
  echo "Fixture directory not found: $FIXTURE_PATH" >&2
  exit 2
fi

# Rule codes that MUST appear in `dart analyze` output for the fixture. Keep
# this list small and stable; it only needs to prove the plugin is loaded and
# producing diagnostics, not to enumerate every rule.
EXPECTED_CODES=(
  "PRESENTATION_NO_THROW"
  "DOMAIN_PURITY"
)

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

MISSING=()
for code in "${EXPECTED_CODES[@]}"; do
  if ! printf '%s\n' "$DART_OUT" | grep -qE "^[A-Z]+\|[A-Z_]+\|${code}\|"; then
    MISSING+=("$code")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "" >&2
  echo "REGRESSION: dart analyze did not report expected plugin diagnostic(s): ${MISSING[*]}" >&2
  echo "The analysis_server_plugin is not producing diagnostics through the" >&2
  echo "recommended consumer path. Investigate plugin loading / analyzer or" >&2
  echo "analysis_server_plugin compatibility before releasing." >&2
  echo "" >&2
  echo "--- dart analyze output ---" >&2
  printf '%s\n' "$DART_OUT" >&2
  exit 1
fi

echo "    OK: all expected plugin diagnostics present via dart analyze."

# --- Optional flutter analyze parity check (documented known gap) -------------
if command -v flutter >/dev/null 2>&1; then
  echo "==> flutter analyze $FIXTURE_DIR (known to drop plugin diagnostics)"
  set +e
  FLUTTER_OUT="$(cd "$FIXTURE_PATH" && flutter analyze 2>&1)"
  set -e
  if printf '%s\n' "$FLUTTER_OUT" | grep -qE 'No issues found'; then
    FLUTTER_DIAG_COUNT=0
  else
    FLUTTER_DIAG_COUNT="$(printf '%s\n' "$FLUTTER_OUT" | grep -cE ' - [a-z_]+$' || true)"
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
fi

echo ""
echo "PASS: plugin diagnostics verified via dart analyze."
