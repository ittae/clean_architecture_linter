#!/usr/bin/env bash
# Local gate to run before opening a pull request. PR CI
# (.github/workflows/ci.yml) does not run this script and is unchanged by it.
#
#   verify.sh           dart analyze, format check, unit tests with the
#                       line-coverage ratchet, Gherkin scenarios, and the
#                       end-to-end smoke tools/verify_analyze_parity.sh
#   verify.sh --quick   analyze and format check only
#   verify.sh --mutate  the default run, then scripts/mutate.sh
#
# Device or simulator e2e does not apply: this package is a headless
# analysis_server_plugin, and verify_analyze_parity.sh is its end-to-end check.
set -euo pipefail
cd "$(dirname "$0")/.."

mode=${1:-}
case "$mode" in
  '' | --quick | --mutate) ;;
  *)
    echo "usage: verify.sh [--quick|--mutate]" >&2
    exit 2
    ;;
esac

dart pub get
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
if [ "$mode" = "--quick" ]; then
  echo "verify ok (quick)"
  exit 0
fi

# Same two steps as the CI coverage job. `dart test --coverage-path`, which
# writes LCOV in one step, crashed the Dart 3.13.7 VM on this suite.
# A fresh directory keeps coverage of deleted tests out of the report.
coverage_json=$(mktemp -d "${TMPDIR:-/tmp}/cal-coverage.XXXXXX")
trap 'rm -rf "$coverage_json"' EXIT
dart test --reporter=failures-only --coverage="$coverage_json"
mkdir -p coverage
dart run coverage:format_coverage --lcov --in="$coverage_json" \
  --out=coverage/lcov.info --report-on=lib
dart scripts/coverage_ratchet.dart

dart test --reporter=failures-only test/features/features_bdd.dart
bash tools/verify_analyze_parity.sh

if [ "$mode" = "--mutate" ]; then
  bash scripts/mutate.sh
fi
echo "verify ok"
