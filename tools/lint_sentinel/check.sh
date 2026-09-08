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
# Env overrides: SENTINEL_DIR, SENTINEL_CODES, SENTINEL_ATTEMPTS (default 5, as in
# the README recipe; CI uses 3 to stay inside its step timeout), SENTINEL_BACKOFF
# (seconds multiplier between attempts, default 5), FALLBACK_ARGS,
# SENTINEL_REQUIRE_ALL, SENTINEL_FILE (both opt-in, default unset/0 — see the
# README "Local gates" table).
set -euo pipefail

SENTINEL_DIR="${SENTINEL_DIR:-lib/zz_lint_sentinel}"
SENTINEL_CODES="${SENTINEL_CODES:-RIVERPOD_KEEP_ALIVE|PRESENTATION_NO_THROW}"
SENTINEL_ATTEMPTS="${SENTINEL_ATTEMPTS:-5}"
SENTINEL_BACKOFF="${SENTINEL_BACKOFF:-5}"
FALLBACK_ARGS="${FALLBACK_ARGS:---fatal-infos --fatal-warnings}"
# 0 (default): rows>0 passes even if a single code delivered them all. 1:
# every code in SENTINEL_CODES must appear at least once in the sentinel rows.
SENTINEL_REQUIRE_ALL="${SENTINEL_REQUIRE_ALL:-0}"
# Unset (default): a sentinel row is anything under SENTINEL_DIR. Set: only a
# row at this exact file counts (a full absolute path — in any of the forms
# `dart analyze --format=machine` itself would print, backslashes included —
# or a shorter path suffix in the SENTINEL_DIR style, e.g.
# lib/zz_lint_sentinel/.../zz.dart), so a real violation of the same rule
# codes elsewhere under SENTINEL_DIR still fails the gate. Exported so awk can
# read it via ENVIRON and normalise it with the exact same `gsub` used for the
# row path (see sentinel_filter below); awk's `-v` assignment does its own
# backslash-escape processing first, which would otherwise silently mangle a
# backslash-containing value in a way that no longer matches the row.
export SENTINEL_FILE="${SENTINEL_FILE:-}"

if [ ! -d "$SENTINEL_DIR" ]; then
  echo "lint sentinel: $SENTINEL_DIR absent; plugin delivery not verified, running: dart analyze $FALLBACK_ARGS"
  # shellcheck disable=SC2086
  dart analyze $FALLBACK_ARGS
  exit 0
fi

# sentinel_filter count  -> number of sentinel rows.
# sentinel_filter others -> every other machine row.
# sentinel_filter codes  -> distinct RULE_CODEs matched by a sentinel row.
# The machine format escapes backslashes in the path field, so any run of
# backslashes collapses to a single `/` before matching. SENTINEL_FILE (read
# via ENVIRON, not -v, so awk never escape-processes it) goes through the
# identical gsub, so both sides normalise the same way regardless of how many
# backslashes either one started with. When set, a row counts as sentinel
# only when its path equals that exact file, or ends with "/" plus that file
# (so a shorter SENTINEL_DIR-style suffix still matches an absolute `dart
# analyze` path); otherwise any path under SENTINEL_DIR counts (the original
# behaviour).
sentinel_filter() {
  printf '%s\n' "$2" | awk -F'|' -v mode="$1" -v d="/$SENTINEL_DIR/" -v codes="$SENTINEL_CODES" '
    function file_match(path,    plen, flen) {
      plen = length(path); flen = length(file)
      if (path == file) return 1
      return (plen > flen && substr(path, plen - flen) == "/" file)
    }
    BEGIN {
      n = split(codes, c, "|"); for (i = 1; i <= n; i++) want[c[i]] = 1
      file = ENVIRON["SENTINEL_FILE"]
      if (file != "") gsub(/\\+/, "/", file)
    }
    /^[A-Z]+\|/ {
      p = $4; gsub(/\\+/, "/", p)
      is_sentinel = 0
      if ($3 in want) {
        if (file != "") { if (file_match(p)) is_sentinel = 1 }
        else if (index(p, d)) is_sentinel = 1
      }
      if (is_sentinel) { hits++; seen[$3] = 1; next }
      if (mode == "others") print
    }
    END {
      if (mode == "count") print hits + 0
      if (mode == "codes") for (k in seen) print k
    }'
}

# missing_codes <dart-out> -> comma-separated SENTINEL_CODES entries that had
# zero sentinel rows in <dart-out>, in SENTINEL_CODES order.
missing_codes() {
  local seen missing="" code
  local -a want_codes
  seen="$(sentinel_filter codes "$1")"
  IFS='|' read -ra want_codes <<<"$SENTINEL_CODES"
  for code in "${want_codes[@]}"; do
    if ! printf '%s\n' "$seen" | grep -qxF "$code"; then
      missing="${missing:+$missing, }$code"
    fi
  done
  printf '%s' "$missing"
}

OUT=""; ROWS=0; MISSING=""
for attempt in $(seq 1 "$SENTINEL_ATTEMPTS"); do
  OUT="$(dart analyze --format=machine 2>&1 || true)"
  ROWS="$(sentinel_filter count "$OUT")"
  MISSING=""
  if [ "$ROWS" -gt 0 ] && [ "$SENTINEL_REQUIRE_ALL" = "1" ]; then
    MISSING="$(missing_codes "$OUT")"
  fi
  if [ "$ROWS" -gt 0 ] && [ -z "$MISSING" ]; then break; fi
  if [ "$ROWS" -eq 0 ]; then
    echo "lint sentinel: clean_architecture_linter diagnostics missing (attempt $attempt/$SENTINEL_ATTEMPTS)${SENTINEL_FILE:+ [SENTINEL_FILE=$SENTINEL_FILE]}"
  else
    echo "lint sentinel: sentinel codes missing: $MISSING (attempt $attempt/$SENTINEL_ATTEMPTS)${SENTINEL_FILE:+ [SENTINEL_FILE=$SENTINEL_FILE]}"
  fi
  if [ "$attempt" -lt "$SENTINEL_ATTEMPTS" ]; then sleep $((attempt * SENTINEL_BACKOFF)); fi
done

if [ "$ROWS" -eq 0 ] || [ -n "$MISSING" ]; then
  echo "----- dart analyze output (last attempt) -----"
  printf '%s\n' "$OUT"
  echo "----------------------------------------------"
  if [ "$ROWS" -eq 0 ]; then
    echo "lint sentinel: plugin diagnostics were not delivered; refusing to treat the tree as clean${SENTINEL_FILE:+ (no row matched SENTINEL_FILE=$SENTINEL_FILE — check it is the exact path dart analyze --format=machine prints, or a path suffix of it)}" >&2
  else
    echo "lint sentinel: sentinel codes still missing after $SENTINEL_ATTEMPTS attempt(s): $MISSING; refusing to treat the tree as clean${SENTINEL_FILE:+ (SENTINEL_FILE=$SENTINEL_FILE narrows which path counts — a missing code may exist elsewhere under SENTINEL_DIR)}" >&2
  fi
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
