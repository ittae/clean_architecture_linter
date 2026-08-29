#!/usr/bin/env bash
# After 2026-08-29, public CAL has no GHA AI-review wait caller.
# HIGH_RISK_PATHS lockstep against pr-review.yml is obsolete (file deleted).
# This gate fails closed if a wait-caller workflow is restored.
# Override root with CAL_LOCKSTEP_ROOT for tests.
set -euo pipefail
ROOT="${CAL_LOCKSTEP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
WF_DIR="$ROOT/.github/workflows"
FORBIDDEN_NAMES=(
  pr-review.yml
  pr-review-light.yml
  pr-review-flutter.yml
  claude-code-review.yml
)

fail=0
for name in "${FORBIDDEN_NAMES[@]}"; do
  f="$WF_DIR/$name"
  if [[ -f "$f" ]]; then
    echo "LOCKSTEP FAIL: wait-caller workflow restored: $f" >&2
    echo "Public CAL AI review is Mac mini poller + ittae-ai-review-meta." >&2
    echo "Do not restore a GHA wait job (docs/public-repo-security.md)." >&2
    fail=1
  fi
done

if [[ -d "$WF_DIR" ]]; then
  shopt -s nullglob
  for wf in "$WF_DIR"/*.yml "$WF_DIR"/*.yaml; do
    if grep -E '^[[:space:]]*uses:[[:space:]].*pr-review(-(light|flutter))?\.yml' "$wf" >/dev/null 2>&1; then
      echo "LOCKSTEP FAIL: $wf calls a GHA AI-review wait reusable" >&2
      fail=1
    fi
  done
  shopt -u nullglob
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "LOCKSTEP OK: no GHA AI-review wait caller"
