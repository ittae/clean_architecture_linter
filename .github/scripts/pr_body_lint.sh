#!/usr/bin/env bash
# Lint an ittae org PR body for required PULL_REQUEST_TEMPLATE sections.
# Usage: pr_body_lint.sh <body.md|-> 
set -euo pipefail
file=${1:-}
if [ "$file" = "-" ] || [ -z "$file" ]; then
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
need '## .*변경' '변경 사항'
need '## .*범위 밖' '범위 밖'
need '## .*관련 이슈' '관련 이슈'
need '## .*실제 동작 증거|## .*Real Behavior' '실제 동작 증거'
need '## .*위험' '위험 / 리뷰 초점'
need 'Risk tier:' 'Risk tier'
need '## .*PR metadata|## .*metadata|## .*🧷' 'PR metadata'
need '## .*체크리스트' 'PR 체크리스트'

sum=$(printf '%s\n' "$body" | awk '/## .*요약/{f=1;next} /^## /{f=0} f' | grep -vE '^[[:space:]]*(<!--.*-->)?[[:space:]]*$' | grep -vE '^[[:space:]]*-[[:space:]]*$' | head -1 || true)
if [ -z "${sum:-}" ]; then
  echo "::error::missing content under: 요약 (empty template)"
  missing=1
fi
if printf '%s\n' "$body" | grep -qE 'Risk tier: `T0 docs/test only` \| `T1'; then
  echo "::error::Risk tier placeholder not selected"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "PR body INVALID — fill ittae/.github PULL_REQUEST_TEMPLATE sections"
  exit 1
fi
echo "PR body OK"
