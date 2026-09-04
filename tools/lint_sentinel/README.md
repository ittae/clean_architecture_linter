# Plugin-load sentinel

`dart analyze` prints `No issues found!` when the `clean_architecture_linter`
plugin isolate has not delivered its diagnostics by the time the CLI collects
results. The same race can also truncate the list (a fixture that yields 16
plugin rows sometimes yields 13, 12 or 2). Nothing in the exit code or output
distinguishes "clean" from "plugin never answered", so a CI gate built on a
bare `dart analyze --fatal-infos` can pass on a tree full of violations.

Measured on Dart SDK 3.13.2 (macOS arm64) against this repo's own fixtures:

| fixture | runs | full delivery | partial / none |
|---|---|---|---|
| `example/` (2 expected rows), sequential runs, load avg ~4 | 20 | 9 | 11 |
| `poc_v2/example` (16 expected rows), sequential runs | 10 | 3 | 7 (13, 13, 2, 2, 2, 2, 2 rows) |
| `poc_v2/example`, while a Flutter app was being analyzed in parallel | 15 | 0 | 15 (2 rows each) |

Large consumer apps (30-40 s of analysis) received the full set on the first
try in every sequential run; the race bites hardest on small fixtures and
loaded machines, which is exactly the CI-runner profile.

The rule repo's own CI shows the same truncation: `tools/verify_analyze_parity.sh`
reported 12 of 16 plugin rows in one run and 16 in the neighbouring runs.

Upstream: [dart-lang/sdk#63787](https://github.com/dart-lang/sdk/issues/63787)
tracks the "analysis complete before plugin diagnostics" timing for the language
server; the merged follow-up (a custom "wait for in-progress analysis" request)
targets LSP clients such as `flutter analyze`. As of SDK 3.13.2 the `dart analyze`
CLI still returns early.

## What the sentinel proves

`zz_lint_sentinel_provider.dart` violates two rules on purpose. Copy it,
unchanged, to

```
lib/zz_lint_sentinel/presentation/providers/zz_lint_sentinel_provider.dart
```

Nothing imports it, so it is not compiled into the app. The directory name
starts with `zz_` so it sorts after every real source directory. Truncated runs
were observed to drop whole files rather than single rows, so a sentinel row
from the last directory is a useful (not absolute) hint that earlier files were
delivered too.

- sentinel rows > 0: the plugin delivered diagnostics for this run
- sentinel rows == 0: the run is inconclusive; retry, and fail if it stays 0

## CI recipe

Replace a bare `dart analyze --fatal-infos --fatal-warnings` step with:

```bash
SENTINEL_DIR=lib/zz_lint_sentinel
# Plugin rule codes the sentinel file violates. Machine output upper-cases them.
SENTINEL_CODES='RIVERPOD_KEEP_ALIVE|PRESENTATION_NO_THROW'
OUT=""; SENTINEL_ROWS=0
count_sentinel() {
  printf '%s\n' "$1" | awk -F'|' -v d="/$SENTINEL_DIR/" -v codes="$SENTINEL_CODES" '
    BEGIN { n = split(codes, c, "|"); for (i = 1; i <= n; i++) want[c[i]] = 1 }
    ($3 in want) && index($4, d) { hits++ }
    END { print hits + 0 }'
}
for attempt in 1 2 3; do
  OUT="$(dart analyze --format=machine 2>&1 || true)"
  SENTINEL_ROWS="$(count_sentinel "$OUT")"
  [ "$SENTINEL_ROWS" -gt 0 ] && break
  echo "::warning::clean_architecture_linter diagnostics missing (attempt $attempt)"
done
if [ "$SENTINEL_ROWS" -eq 0 ]; then
  # Keep the raw output: a broken plugins: entry, a plugin compile error or a
  # pub resolution failure looks identical to the race without it.
  echo "::group::dart analyze output (last attempt)"
  printf '%s\n' "$OUT"
  echo "::endgroup::"
  echo "::error::clean_architecture_linter plugin diagnostics were not delivered; refusing to treat the tree as clean"
  exit 1
fi
# Everything except the sentinel's own plugin rows fails the step. Built-in
# analyzer diagnostics inside the sentinel file still fail it.
REAL="$(printf '%s\n' "$OUT" | awk -F'|' -v d="/$SENTINEL_DIR/" -v codes="$SENTINEL_CODES" '
  BEGIN { n = split(codes, c, "|"); for (i = 1; i <= n; i++) want[c[i]] = 1 }
  /^[A-Z]+\|/ && !(($3 in want) && index($4, d))')"
if [ -n "$REAL" ]; then
  printf '%s\n' "$REAL"
  exit 1
fi
echo "dart analyze clean (sentinel rows: $SENTINEL_ROWS)"
```

Every row other than the sentinel's two plugin rows fails the step, which is
the same policy as `--fatal-infos --fatal-warnings`. `--format=machine` rows
look like `SEVERITY|TYPE|RULE_CODE|path|line|col|len|message`; the count keys
on `RULE_CODE` **and** the path, because built-in lints (for example
`public_member_api_docs` under strict lint sets) also emit rows for the
sentinel file and would otherwise count as "plugin delivered".

`SENTINEL_CODES` must match the rules the consumer actually enables. If
`analysis_options.yaml` sets `riverpod_keep_alive: ignore` or
`presentation_no_throw: ignore`, drop that code from the list; if both are
ignored, add a violation of a rule the app does enforce and list its code.

## Residual risk

The sentinel proves delivery, not completeness. A truncated run that happens to
include the sentinel still hides other rows. Until the CLI waits for the plugin
isolate upstream, keep the retry loop and prefer analyzing on an idle runner.
