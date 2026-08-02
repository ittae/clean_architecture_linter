#!/usr/bin/env bash
# Lint an ittae org PR body for required PULL_REQUEST_TEMPLATE sections.
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
need '## .*변경' '변경 사항'
need '## .*범위 밖' '범위 밖'
need '## .*관련 이슈' '관련 이슈'
need '## .*실제 동작 증거|## .*Real Behavior' '실제 동작 증거'
need '## .*위험' '위험 / 리뷰 초점'
need 'Risk tier:' 'Risk tier'
need '## .*PR metadata|## .*metadata|## .*🧷' 'PR metadata'
need '## .*체크리스트' 'PR 체크리스트'

section_nonempty() {
  local heading_pat="$1" label="$2"
  local content useful
  content=$(printf '%s\n' "$body" | awk -v p="$heading_pat" '
    $0 ~ p {f=1; next}
    f && /^## / {exit}
    f {print}
  ')
  # Strip HTML comments before emptiness checks: inline occurrences first (a body may
  # legitimately mention comment syntax in backticks), then line-anchored multi-line
  # blocks. Single-line grep alone lets multi-line template instructions pass as "content";
  # an unanchored range would also swallow real content after a mid-line `<!--` mention.
  useful=$(printf '%s\n' "$content" \
    | sed -e 's/<!--.*-->//g' -e '/^[[:space:]]*<!--/,/-->/d' \
    | grep -vE '^[[:space:]]*$' \
    | grep -vE '^[[:space:]]*-[[:space:]]*$' \
    | head -1 || true)
  if [ -z "${useful:-}" ]; then
    echo "::error::missing content under: $label"
    missing=1
  fi
}
section_nonempty '## .*요약' '요약'
section_nonempty '## .*목표' '목표 / 이유'
section_nonempty '## .*변경' '변경 사항'
section_nonempty '## .*범위 밖' '범위 밖'

if printf '%s\n' "$body" | grep -qE 'Risk tier:.*`T0 docs/test only`[[:space:]]*\|'; then
  echo "::error::Risk tier placeholder not selected"
  missing=1
elif ! printf '%s\n' "$body" | grep -qE 'Risk tier:.*`T[0-3]'; then
  echo "::error::Risk tier must select T0-T3"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "PR body INVALID — fill ittae/.github PULL_REQUEST_TEMPLATE sections"
  exit 1
fi
echo "PR body OK"
