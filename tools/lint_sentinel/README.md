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

## Root cause (measured 2026-09-04)

Driving the analysis server over the legacy protocol and logging
`server.status` against plugin `analysis.errors` shows two things:

- With `analysis_server_plugin 0.3.15` (the 2.4.x line) the plugin reports
  *idle* to the server after its first file (priority/changed-file handling)
  and only then starts its full pass. The server forwards that idle as
  `isAnalyzing: false`; `dart analyze` stops collecting there. The full pass
  arrives 10-50 ms later and is discarded. 9 of 10 traces showed the
  `false -> true -> errors -> false` flip on the 2-row fixture.
- With `analysis_server_plugin 0.3.22` the plugin status follows its analysis
  driver (reworked in 0.3.16), the flip is gone, and `dart analyze` delivered
  every row in 55 of 55 runs on the same fixtures, 15 of them under the same
  parallel load that lost 15 of 15 on 0.3.15.

Those 0.3.22 numbers are a host-side measurement, not a line this package
ships. 2.4.x still pins `analysis_server_plugin: ">=0.3.15 <0.3.16"` and
`analyzer: ">=13.0.0 <14.0.0"` so it can coexist with `riverpod_lint` 3.1.x
(see `pubspec.yaml`). 0.3.22 needs analyzer 14.3.0, which this package cannot
open yet — `docs/analysis/FLUTTER_ANALYZE_PLUGIN_LOSS.md` keeps that
upper-bound in place. Upgrading `clean_architecture_linter` therefore does
not give consumers 0.3.22.

For 2.4.x consumers the sentinel recipe below is the **required CI gate**,
not a backup. A plugin that fails to start, a future host regression, or
the residual ordering gap (even 0.3.22 still sends idle a few milliseconds
before the last error batch, which `dart analyze` currently tolerates)
all surface as a loud failure instead of a silent pass. The trace script is
small enough to inline:

```python
# legacy_trace.py <package_dir>: prints the server.status / analysis.errors timeline
import json, os, queue, subprocess, sys, threading, time
root = os.path.abspath(sys.argv[1])
p = subprocess.Popen(['dart', 'language-server', '--protocol=analyzer'],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
q, t0 = queue.Queue(), time.time()
threading.Thread(target=lambda: [q.put((time.time() - t0, json.loads(l))) for l in p.stdout if l.startswith('{')], daemon=True).start()
def send(i, m, params): p.stdin.write(json.dumps({'id': str(i), 'method': m, 'params': params}) + '\n'); p.stdin.flush()
send(1, 'server.setSubscriptions', {'subscriptions': ['STATUS']})
send(2, 'analysis.setAnalysisRoots', {'included': [root], 'excluded': []})
deadline = None
while deadline is None or time.time() < deadline:
    try: ts, m = q.get(timeout=0.2)
    except queue.Empty: continue
    if m.get('event') == 'server.status':
        a = m['params']['analysis']['isAnalyzing']; print(f'{ts:6.2f}s status isAnalyzing={a}')
        if a is False and deadline is None: deadline = time.time() + 5
    elif m.get('event') == 'analysis.errors' and m['params']['errors']:
        print(f"{ts:6.2f}s errors {os.path.relpath(m['params']['file'], root)}: {len(m['params']['errors'])}")
send(3, 'server.shutdown', {})
```

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
# Attempts and back-off: the race is load-sensitive, so a busy runner needs
# more tries and a pause between them (see "Expected miss rate" below).
ATTEMPTS="${SENTINEL_ATTEMPTS:-5}"
OUT=""; SENTINEL_ROWS=0
count_sentinel() {
  printf '%s\n' "$1" | awk -F'|' -v d="/$SENTINEL_DIR/" -v codes="$SENTINEL_CODES" '
    BEGIN { n = split(codes, c, "|"); for (i = 1; i <= n; i++) want[c[i]] = 1 }
    { gsub(/\\+/, "/", $4) }
    ($3 in want) && index($4, d) { hits++ }
    END { print hits + 0 }'
}
for attempt in $(seq 1 "$ATTEMPTS"); do
  OUT="$(dart analyze --format=machine 2>&1 || true)"
  SENTINEL_ROWS="$(count_sentinel "$OUT")"
  [ "$SENTINEL_ROWS" -gt 0 ] && break
  echo "::warning::clean_architecture_linter diagnostics missing (attempt $attempt/$ATTEMPTS)"
  [ "$attempt" -lt "$ATTEMPTS" ] && sleep $((attempt * 5))
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
  { p = $4; gsub(/\\+/, "/", p) }
  /^[A-Z]+\|/ && !(($3 in want) && index(p, d))')"
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

**Expected miss rate.** From the table above, a single attempt on a clean tree
missed 11 of 20 runs on a 2-row fixture, 7 of 10 on a 16-row fixture, and
15 of 15 while another analysis loaded the machine. Real consumer apps
(30-40 s of analysis) delivered on the first attempt in every sequential run,
so the fixture numbers are a worst case; even at a 55% single-run miss rate,
five attempts leave about a 5% false failure. A shared runner should raise
`SENTINEL_ATTEMPTS` or serialize analyze jobs. The recipe is fail-closed, so a
miss is a loud failure, never a silent pass.

The `gsub` in both awk programs normalises Windows `\` paths so the sentinel
directory still matches on a Windows runner.

`SENTINEL_CODES` must match the rules the consumer actually enables. If
`analysis_options.yaml` sets `riverpod_keep_alive: ignore` or
`presentation_no_throw: ignore`, drop that code from the list; if both are
ignored, add a violation of a rule the app does enforce and list its code.

## Local gates (derry `check`, pre-commit, verify.sh)

Plain `dart analyze` exits 2 as soon as the sentinel is in the tree, because
the sentinel deliberately carries a WARNING row (`presentation_no_throw`).
Every local gate that used to run `dart analyze` (with or without
`--fatal-*`) therefore needs the same sentinel-aware check as CI.

`check.sh` next to this file is a copy-and-go version of the CI recipe:

```bash
cp <clean_architecture_linter>/tools/lint_sentinel/check.sh scripts/analyze.sh
chmod +x scripts/analyze.sh
# derry / pre-commit / verify.sh: replace `dart analyze …` with
bash scripts/analyze.sh
```

Without `lib/zz_lint_sentinel/` it falls back to `dart analyze
--fatal-infos --fatal-warnings` (override with `FALLBACK_ARGS`), so the same
script is safe to land before the sentinel file. `SENTINEL_DIR` and
`SENTINEL_CODES` mirror the CI step. `SENTINEL_ATTEMPTS` defaults to 5 like
the recipe above (the "Expected miss rate" figures assume 5); the CI step
itself uses 3 to stay inside its 15-minute timeout. `SENTINEL_BACKOFF`
(default 5) is the seconds multiplier between attempts.

## Regression contract

`test/tools/lint_sentinel_test.dart` runs the shipped sentinel file through
both rules with the package's rule harness and asserts exactly one
`riverpod_keep_alive` and one `presentation_no_throw` diagnostic at the
documented consumer path. A heuristic change that silences either rule fails
the package's own `dart test` before it can break consumer gates.

## Residual risk

The sentinel proves delivery, not completeness. A truncated run that happens to
include the sentinel still hides other rows. Until the CLI waits for the plugin
isolate upstream, keep the retry loop and prefer analyzing on an idle runner.
