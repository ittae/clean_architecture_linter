#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Resolving root plugin package..."
(cd "$ROOT_DIR" && dart pub get)

echo "Resolving v2 example package..."
(cd "$ROOT_DIR/poc_v2/example" && dart pub get)

echo "Resolving v2 riverpod_lint consumer package..."
(cd "$ROOT_DIR/poc_v2/consumer_riverpod_lint" && dart pub get)

echo "Running analyzer plugin smoke check..."
set +e
ANALYZE_OUTPUT="$(cd "$ROOT_DIR/poc_v2/example" && dart analyze --no-fatal-warnings 2>&1)"
ANALYZE_STATUS=$?
set -e

printf '%s\n' "$ANALYZE_OUTPUT"

if [[ $ANALYZE_STATUS -ne 0 ]]; then
  exit "$ANALYZE_STATUS"
fi

if [[ "$ANALYZE_OUTPUT" != *"presentation_no_throw"* ]]; then
  echo "Expected presentation_no_throw diagnostic was not reported." >&2
  exit 1
fi

if [[ "$ANALYZE_OUTPUT" == *"good_notifier.dart"* ]]; then
  echo "good_notifier.dart should not report presentation_no_throw." >&2
  exit 1
fi

echo "Running analyzer plugin + riverpod_lint consumer smoke check..."
set +e
CONSUMER_ANALYZE_OUTPUT="$(
  cd "$ROOT_DIR/poc_v2/consumer_riverpod_lint" && dart analyze --no-fatal-warnings 2>&1
)"
CONSUMER_ANALYZE_STATUS=$?
set -e

printf '%s\n' "$CONSUMER_ANALYZE_OUTPUT"

if [[ $CONSUMER_ANALYZE_STATUS -ne 0 ]]; then
  exit "$CONSUMER_ANALYZE_STATUS"
fi

if [[ "$CONSUMER_ANALYZE_OUTPUT" != *"presentation_no_throw"* ]]; then
  echo "Expected presentation_no_throw diagnostic was not reported in riverpod_lint consumer fixture." >&2
  exit 1
fi

echo "Smoke check passed: local analyzer plugin reported the expected diagnostic."
