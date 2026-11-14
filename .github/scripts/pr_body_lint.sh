#!/usr/bin/env bash
# Lint an ittae org PR body for required PULL_REQUEST_TEMPLATE sections.
# Issue link (ITT-4880): a visible `Closes ITT-<n>` or `Related ITT-<n>` line
# (Fixes/Resolves also count; HTML comments do not). PR_BODY_ISSUE_LINK=off turns
# it off for public repos, which keep private ITT keys out of their metadata.
# Receipt line (ITT-4881): a visible `- pre-pr-review: PASS (engine=<e>, head <sha8>)`,
# `- pre-pr-review: PASS (engine=<e>, reviewed head <sha8>, patch-id match)`,
# or `- pre-pr-review: skipped (bot)` line; PR_BODY_RECEIPT_LINE=off turns it off.
# That receipt bullet is not 실제 동작 증거 content (ITT-5126).
set -euo pipefail
file=${1:-}
if [ -z "${file:-}" ]; then
  echo "usage: pr_body_lint.sh <body.md|->" >&2
  exit 2
fi
if [ "$file" = "-" ]; then
  body=$(cat)
elif [ -f "$file" ]; then
  body=$(cat "$file")
else
  echo "usage: pr_body_lint.sh <body.md|->" >&2
  exit 2
fi

missing=0
need() {
  local pat="$1" label="$2"
  if ! printf '%s\n' "$body" | grep -qE "$pat"; then
    echo "::error::missing section: $label"
    missing=1
  fi
}
need '## .*요약' '요약'
need '## .*목표' '목표 / 이유'
need '## .*실제 동작 증거|## .*Real Behavior' '실제 동작 증거'
need '## .*범위 밖' '범위 밖'

# Third arg strip-receipt: drop pre-pr-review bullets before taking the first line (ITT-5126).
section_nonempty() {
  local heading_pat="$1" label="$2"
  local content useful
  content=$(printf '%s\n' "$body" | awk -v p="$heading_pat" '
    $0 ~ p {f=1; next}
    f && /^## / {exit}
    f {print}
  ')
  # Strip HTML comments before emptiness checks: inline occurrences first (a body may
  # legitimately mention comment syntax in backticks), then true multi-line blocks.
  # Single-line grep alone lets multi-line template instructions pass as "content".
  useful=$(printf '%s\n' "$content" \
    | sed -e 's/<!--.*-->//g' -e '/^[[:space:]]*<!--/,/-->/d' \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '^[[:space:]]*-[[:space:]]*$' || true)
  # Filter before head -1 so a receipt-first section keeps a later evidence line,
  # and a receipt-only section stays empty.
  if [ "${3:-}" = "strip-receipt" ]; then
    useful=$(printf '%s\n' "$useful" | grep -vE '^[[:space:]]*-[[:space:]]+pre-pr-review:' || true)
  fi
  useful=$(printf '%s\n' "$useful" | head -1 || true)
  if [ -z "${useful:-}" ]; then
    echo "::error::missing content under: $label"
    missing=1
  fi
}
section_nonempty '## .*요약' '요약'
section_nonempty '## .*목표' '목표 / 이유'
section_nonempty '## .*실제 동작 증거|## .*Real Behavior' '실제 동작 증거' strip-receipt
section_nonempty '## .*범위 밖' '범위 밖'

case "${PR_BODY_ISSUE_LINK:-required}" in
  off) ;;
  *)
    visible=$(printf '%s\n' "$body" | sed -e 's/<!--.*-->//g' -e '/^[[:space:]]*<!--/,/-->/d')
    if ! printf '%s\n' "$visible" | grep -qiE '(^|[^[:alnum:]_])(closes|fixes|resolves|related)[[:space:]]*:?[[:space:]]*\[?ITT-[0-9]+'; then
      echo "::error::missing issue link: add a 'Closes ITT-<n>' (work issue) or 'Related ITT-<n>' (parent/context) line"
      missing=1
    fi
    ;;
esac

case "${PR_BODY_RECEIPT_LINE:-required}" in
  off) ;;
  *)
    # ITT-4881: pr-create-ittae.sh writes this line from the local receipt.
    visible=$(printf '%s\n' "$body" | sed -e 's/<!--.*-->//g' -e '/^[[:space:]]*<!--/,/-->/d')
    if ! printf '%s\n' "$visible" | grep -qE '^[[:space:]]*-[[:space:]]+pre-pr-review:[[:space:]]+(PASS \(engine=(grok|cursor|claude), head [0-9a-f]{7,40}\)|PASS \(engine=(grok|cursor|claude), reviewed head [0-9a-f]{7,40}, patch-id match\)|skipped \(bot\))'; then
      echo "::error::missing pre-pr-review line: open the PR with scripts/git/pr-create-ittae.sh (it adds '- pre-pr-review: PASS (engine=<engine>, head <sha8>)' from the receipt)"
      missing=1
    fi
    ;;
esac

if [ "$missing" -ne 0 ]; then
  echo "PR body INVALID — fill ittae/.github PULL_REQUEST_TEMPLATE sections"
  exit 1
fi
echo "PR body OK"
