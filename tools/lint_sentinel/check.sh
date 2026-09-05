#!/usr/bin/env bash
# Sentinel-aware `dart analyze` gate for consumers of clean_architecture_linter.
#
# Copy this file into your app (e.g. scripts/analyze.sh) and call it from every
# local gate that used to run `dart analyze` (derry `check`, pre-commit hooks,
# scripts/verify.sh). Plain `dart analyze` exits 2 once the sentinel file is in
# the tree, because the sentinel deliberately carries a WARNING row.
#
# Behaviour (mirrors the ittae/.github flutter-ci.yml shard 0 step):
#   * SENTINEL_DIR absent  -> fall back to `dart analyze $FALLBACK_ARGS`.
#   * SENTINEL_DIR present -> run `dart analyze --format=machine`; require at
#     least one sentinel row (RULE_CODE in SENTINEL_CODES and a path inside
#     SENTINEL_DIR), retrying SENTINEL_ATTEMPTS times because the analysis
#     server plugin can publish late; then fail on every other row (same
#     policy as --fatal-infos --fatal-warnings).
#
# Env overrides: SENTINEL_DIR, SENTINEL_CODES, SENTINEL_ATTEMPTS, FALLBACK_ARGS.
set -euo pipefail

SENTINEL_DIR="${SENTINEL_DIR:-lib/zz_lint_sentinel}"
SENTINEL_CODES="${SENTINEL_CODES:-RIVERPOD_KEEP_ALIVE|PRESENTATION_NO_THROW}"
SENTINEL_ATTEMPTS="${SENTINEL_ATTEMPTS:-3}"
FALLBACK_ARGS="${FALLBACK_ARGS:---fatal-infos --fatal-warnings}"

if [ ! -d "$SENTINEL_DIR" ]; then
  echo "lint sentinel: $SENTINEL_DIR absent; plugin delivery not verified, running: dart analyze $FALLBACK_ARGS"
  # shellcheck disable=SC2086
  dart analyze $FALLBACK_ARGS
  exit 0
fi

# sentinel_filter count  -> number of sentinel rows.
# sentinel_filter others -> every other machine row.
# The machine format escapes backslashes in the path field, so any run of
# backslashes collapses to a single `/` before matching.
sentinel_filter() {
  printf '%s\n' "$2" | awk -F'|' -v mode="$1" -v d="/$SENTINEL_DIR/" -v codes="$SENTINEL_CODES" '
    BEGIN { n = split(codes, c, "|"); for (i = 1; i <= n; i++) want[c[i]] = 1 }
    /^[A-Z]+\|/ {
      p = $4; gsub(/\\+/, "/", p)
      if (($3 in want) && index(p, d)) { hits++; next }
      if (mode == "others") print
    }
    END { if (mode == "count") print hits + 0 }'
}

OUT=""; ROWS=0
for attempt in $(seq 1 "$SENTINEL_ATTEMPTS"); do
  OUT="$(dart analyze --format=machine 2>&1 || true)"
  ROWS="$(sentinel_filter count "$OUT")"
  if [ "$ROWS" -gt 0 ]; then break; fi
  echo "lint sentinel: clean_architecture_linter diagnostics missing (attempt $attempt/$SENTINEL_ATTEMPTS)"
  if [ "$attempt" -lt "$SENTINEL_ATTEMPTS" ]; then sleep $((attempt * 5)); fi
done

if [ "$ROWS" -eq 0 ]; then
  echo "----- dart analyze output (last attempt) -----"
  printf '%s\n' "$OUT"
  echo "----------------------------------------------"
  echo "lint sentinel: plugin diagnostics were not delivered; refusing to treat the tree as clean" >&2
  exit 1
fi

REAL="$(sentinel_filter others "$OUT")"
echo "lint sentinel: sentinel rows received: $ROWS"
if [ -n "$REAL" ]; then
  printf '%s\n' "$REAL"
  echo "lint sentinel: dart analyze reported $(printf '%s\n' "$REAL" | wc -l | tr -d ' ') diagnostic(s); policy is --fatal-infos --fatal-warnings" >&2
  exit 1
fi
echo "lint sentinel: dart analyze clean; plugin delivery verified by sentinel"
