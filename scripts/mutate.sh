#!/usr/bin/env bash
# Deliberate-break runner: apply each edit of test/mutation/breaks.txt, run the
# tests, restore the file. Local only; no CI job runs it.
#
# usage: bash scripts/mutate.sh        BREAKS=<file> picks another list
# Line format: file § from § to § label. `from` must appear once in the file.
# \n in a field is a newline. Blank lines and # lines are skipped.
# KILLED: the tests exit non-zero. SURVIVED: they exit 0.
# Exit 0: every break was killed. Exit 1: a SURVIVED or SKIP, or no break at all.
# Exit 2: no breaks file. Exit 3: the tests fail before any break.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BREAKS=${BREAKS:-"$ROOT/test/mutation/breaks.txt"}
# § is U+00A7. Bash splits on it as one character only in a UTF-8 locale.
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
cd "$ROOT"

cmd=(dart test --reporter=failures-only test/features/features_bdd.dart
  test/scripts/coverage_ratchet_test.dart)
if [ ! -f "$BREAKS" ]; then
  echo "breaks file not found: $BREAKS" >&2
  exit 2
fi

killed=0 survived=0 skipped=0 n=0
file='' bak='' child=''

restore_current() {
  if [ -z "$bak" ] || [ ! -f "$bak" ]; then
    return 0
  fi
  if cp "$bak" "$file"; then
    rm -f "$bak"
    bak=
    return 0
  fi
  echo "RESTORE FAILED: $file (backup kept at $bak)" >&2
  trap - EXIT
  exit 1
}

# shellcheck disable=SC2329 # trap INT TERM calls this
on_term() {
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  restore_current
  exit 143
}
trap restore_current EXIT
trap on_term INT TERM

run_test_cmd() {
  set +e
  "${cmd[@]}" </dev/null >"$log" 2>&1 &
  child=$!
  wait "$child"
  test_rc=$?
  child=
  set -e
}

skip() {
  restore_current
  echo "SKIP     #$n ${label:-${file:-line}} ($1)"
  skipped=$((skipped + 1))
}

log=$(mktemp "${TMPDIR:-/tmp}/cal-mutate.XXXXXX")
run_test_cmd
if [ "$test_rc" -ne 0 ]; then
  cat "$log" >&2
  rm -f "$log"
  echo "BASELINE FAILED rc=$test_rc" >&2
  exit 3
fi

while IFS= read -r line || [ -n "${line:-}" ]; do
  case "$line" in
    '' | '#'*) continue ;;
  esac
  n=$((n + 1))
  IFS='§' read -r file from to label <<<"$line"
  seps=${line//[^§]/}
  if [ "${#seps}" -lt 2 ] || [ -z "$file" ] || [ -z "$from" ]; then
    skip "malformed"
    continue
  fi
  if [ ! -f "$file" ]; then
    skip "file not found: $file"
    continue
  fi
  bak="$file.mut.bak"
  if [ -e "$bak" ]; then
    echo "stale backup: $bak" >&2
    bak=
    exit 1
  fi
  cp "$file" "$bak"
  if ! python3 - "$file" "$from" "$to" <<'PY'; then
import sys
path, src, dst = (a.replace("\\n", "\n") for a in sys.argv[1:4])
text = open(path, encoding="utf-8", newline="").read()
if text.count(src) != 1:
    sys.exit(1)
with open(path, "w", encoding="utf-8", newline="") as out:
    out.write(text.replace(src, dst, 1))
PY
    skip "from-text is not in $file exactly once"
    continue
  fi
  run_test_cmd
  restore_current
  if [ "$test_rc" -eq 0 ]; then
    survived=$((survived + 1))
    echo "SURVIVED #$n $file: ${label:-}"
  else
    killed=$((killed + 1))
    echo "KILLED   #$n $file: ${label:-}"
  fi
done <"$BREAKS"
rm -f "$log"

echo "breaks=$n killed=$killed survived=$survived skipped=$skipped"
if [ "$n" -eq 0 ] || [ "$survived" -ne 0 ] || [ "$skipped" -ne 0 ]; then
  exit 1
fi
exit 0
