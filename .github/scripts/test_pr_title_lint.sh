#!/usr/bin/env bash
# Tests for pr_title_lint.sh: titles that release-please copies into the public
# CHANGELOG.md must be English and must not carry a private issue key.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/pr_title_lint.sh"
failures=0

expect() {
  local want="$1" title="$2" got=0
  bash "$LINT" "$title" >/dev/null 2>&1 || got=$?
  if [ "$got" -ne "$want" ]; then
    echo "FAIL: exit $got, want $want: $title"
    failures=$((failures + 1))
  fi
}

# Changelog types in English pass.
expect 0 'fix: isRethrow recognizes a standalone rethrow statement'
expect 0 'feat(rules): report extension @Dependencies outside the notifier scope'
expect 0 'perf: cache resolved layer lookups'
expect 0 'revert: restore the previous DI file-name exemption'
expect 0 'feat!: drop analyzer 13 support'
expect 0 'chore(main): release 2.8.5'

# Types hidden from the changelog may stay Korean.
expect 0 'docs: 강제 패턴 가이드를 분리한다'
expect 0 'chore: PR 본문 lint를 조직 정본 사본과 맞춘다'
expect 0 'ci: 공개 저장소용 비밀값 검사를 추가한다'
expect 0 'test(rules): 회귀 테스트를 추가한다'

# Changelog types with Hangul fail.
expect 1 'fix: isRethrow가 단독 rethrow 문장을 인식하게 한다'
expect 1 'feat: 확장 @Dependencies가 스코프를 벗어나면 보고한다'
expect 1 'perf(rules): 조회를 캐시한다'
expect 1 'revert: 예외를 되돌린다'
expect 1 'deps: analyzer를 올린다'
# A breaking change is always rendered, whatever its type.
expect 1 'refactor!: 공개 API를 정리한다'
expect 1 'chore(api)!: 공개 API를 정리한다'

# A private issue key fails for every type.
expect 1 'fix: ITT-6072 isRethrow recognizes a standalone rethrow statement'
expect 1 'chore: ITT-3070 rename leftover references'
expect 1 'docs: ITT-12 가이드를 고친다'

# Not a Conventional Commit title.
expect 1 'isRethrow recognizes a standalone rethrow statement'
expect 1 'fix isRethrow'

# Usage error.
expect 2 ''

if [ "$failures" -ne 0 ]; then
  echo "$failures test(s) failed"
  exit 1
fi
echo "pr_title_lint: all tests passed"
