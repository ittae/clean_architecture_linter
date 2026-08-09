#!/usr/bin/env bash
# Regression test for truncate_body_excerpt.sh.
#
# Root incident: on 2026-08-07, a real multibyte (Korean) PR body truncated
# at exactly 300 bytes landed mid-character. iconv correctly dropped the
# partial trailing byte but exited non-zero doing it, and under `set -e`
# that killed the entire relay job (verified via ittae/glimpshot#51:
# "iconv: unexpected end of file; the last character is incomplete."
# -> job failed with exit 1). This test locks in the fix.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUNCATE_SCRIPT="$SCRIPT_DIR/truncate_body_excerpt.sh"
FIXTURE="$SCRIPT_DIR/testdata/multibyte-body-fixture.md"

# Prefer RUNNER_TEMP (GHA job-scoped) when present; otherwise mktemp for local runs.
# Avoid fixed /tmp/truncate_test_*.$$ which can race on multi-runner hosts.
TMP_BASE="${RUNNER_TEMP:-$(mktemp -d "${TMPDIR:-/tmp}/truncate_test.XXXXXX")}"
OUT_FILE="$TMP_BASE/truncate_test_out"
ERR_FILE="$TMP_BASE/truncate_test_err"
# Clean only the mktemp dir we created (not a pre-existing RUNNER_TEMP root).
CLEANUP_TMPDIR=""
if [ -z "${RUNNER_TEMP:-}" ]; then
  CLEANUP_TMPDIR="$TMP_BASE"
fi
cleanup() {
  rm -f "$OUT_FILE" "$ERR_FILE"
  if [ -n "$CLEANUP_TMPDIR" ]; then
    rmdir "$CLEANUP_TMPDIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

fail=0

check_exit_zero() {
  local label="$1" input="$2"
  if printf '%s' "$input" | bash "$TRUNCATE_SCRIPT" > "$OUT_FILE" 2>"$ERR_FILE"; then
    echo "OK   $label: exit 0"
  else
    echo "FAIL $label: expected exit 0, got $?"
    cat "$ERR_FILE"
    fail=1
  fi
}

check_valid_utf8() {
  local label="$1"
  if iconv -f UTF-8 -t UTF-8 "$OUT_FILE" > /dev/null 2>&1; then
    echo "OK   $label: output is valid UTF-8"
  else
    echo "FAIL $label: output is NOT valid UTF-8"
    fail=1
  fi
}

# 1. Real-world reproduction: the exact PR body that killed ittae/glimpshot#51.
#    This is the case that matters — it must exit 0 and produce valid UTF-8.
check_exit_zero "real multibyte fixture (glimpshot#51 body)" "$(cat "$FIXTURE")"
check_valid_utf8 "real multibyte fixture (glimpshot#51 body)"
REAL_LEN=$(wc -c < "$OUT_FILE" | tr -d ' ')
if [ "$REAL_LEN" -gt 0 ] && [ "$REAL_LEN" -le 300 ]; then
  echo "OK   real multibyte fixture: length=$REAL_LEN (0 < len <= 300)"
else
  echo "FAIL real multibyte fixture: unexpected length=$REAL_LEN"
  fail=1
fi

# 2. Synthetic worst case: pure Korean text long enough that byte 300 lands
#    mid-character for a *different* multi-byte offset than fixture #1, so
#    the test doesn't depend on one specific byte pattern.
SYNTHETIC=$(printf '한글 테스트 문자열입니다 %.0s' {1..20})
check_exit_zero "synthetic Korean text (400+ bytes)" "$SYNTHETIC"
check_valid_utf8 "synthetic Korean text (400+ bytes)"

# 3. Pure ASCII, short (<300 bytes): must pass through unchanged, no
#    truncation, no iconv warning.
check_exit_zero "short ASCII body" "hello world"
check_valid_utf8 "short ASCII body"
ASCII_OUT=$(cat "$OUT_FILE")
if [ "$ASCII_OUT" = "hello world" ]; then
  echo "OK   short ASCII body: passed through unchanged"
else
  echo "FAIL short ASCII body: expected 'hello world', got '$ASCII_OUT'"
  fail=1
fi

# 4. Empty body: must not error.
check_exit_zero "empty body" ""

if [ "$fail" -ne 0 ]; then
  echo "::error::truncate_body_excerpt.sh regression test failed"
  exit 1
fi

echo "All truncate_body_excerpt.sh tests passed."
