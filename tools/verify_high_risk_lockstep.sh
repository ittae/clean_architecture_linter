#!/usr/bin/env bash
# Regression: HIGH_RISK_PATHS must match light reusable DEFAULT_HIGH_RISK_PATHS_LIGHT.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$ROOT/.github/workflows/pr-review.yml"
# origin/main removed the inline GHA PR Review workflow; AI review meta is
# published by the Mac mini poller. Nothing to lockstep in-repo then.
if [[ ! -f "$WF" ]]; then
  echo "LOCKSTEP OK: $WF absent (GHA PR Review workflow removed; 2nd-line guard is ittae/.github test_cal_high_risk_lockstep.py)"
  exit 0
fi
EXPECTED='^\.github/workflows/|^\.env|^env/|/secrets?/|secret|secrets|(^|/)auth(/|$)|api[_-]?key|password|scripts/pr-autopilot|dependabot-alerts-sweep|crontab'
ACTUAL=$(sed -n "s/^  HIGH_RISK_PATHS: '\(.*\)'/\1/p" "$WF" | head -1)
if [[ -z "$ACTUAL" ]]; then
  echo "LOCKSTEP FAIL: could not parse HIGH_RISK_PATHS from $WF" >&2
  exit 1
fi
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "LOCKSTEP FAIL: HIGH_RISK_PATHS diverged from light SoT" >&2
  echo "expected: $EXPECTED" >&2
  echo "actual:   $ACTUAL" >&2
  exit 1
fi
echo "LOCKSTEP OK: HIGH_RISK_PATHS == DEFAULT_HIGH_RISK_PATHS_LIGHT"
