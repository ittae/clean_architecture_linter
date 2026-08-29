#!/usr/bin/env bash
# After 2026-08-29, public CAL has no GHA AI-review wait caller.
# HIGH_RISK_PATHS lockstep against pr-review.yml is obsolete (file deleted).
# This gate fails closed if a wait-caller workflow is restored.
# GitHub Actions loads both .yml and .yaml; stems below cover both.
# Override root with CAL_LOCKSTEP_ROOT for tests.
set -euo pipefail
ROOT="${CAL_LOCKSTEP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WF_DIR="$ROOT/.github/workflows"
FORBIDDEN_STEMS=(
  pr-review
  pr-review-light
  pr-review-flutter
  claude-code-review
)

fail=0
for stem in "${FORBIDDEN_STEMS[@]}"; do
  for ext in yml yaml; do
    f="$WF_DIR/${stem}.${ext}"
    if [[ -f "$f" ]]; then
      echo "LOCKSTEP FAIL: wait-caller workflow restored: $f" >&2
      echo "Public CAL AI review is Mac mini poller + ittae-ai-review-meta." >&2
      echo "Do not restore a GHA wait job (docs/public-repo-security.md)." >&2
      fail=1
    fi
  done
done

uses_re=""
for stem in "${FORBIDDEN_STEMS[@]}"; do
  if [[ -n "$uses_re" ]]; then
    uses_re+="|"
  fi
  uses_re+="${stem}\\.ya?ml"
done
# Require a path boundary so foo-pr-review.yml does not match pr-review.yml.
USES_RE="^[[:space:]]*uses:[[:space:]]+(.*/)?(${uses_re})"

if [[ -d "$WF_DIR" ]]; then
  shopt -s nullglob
  for wf in "$WF_DIR"/*.yml "$WF_DIR"/*.yaml; do
    matches="$(grep -E "$USES_RE" "$wf" || true)"
    if [[ -n "$matches" ]]; then
      echo "LOCKSTEP FAIL: $wf calls a GHA AI-review wait reusable" >&2
      printf '%s\n' "$matches" >&2
      fail=1
    fi
  done
  shopt -u nullglob
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "LOCKSTEP OK: no GHA AI-review wait caller"
