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
# Hangul in the scope.
expect 1 'fix(규칙): report ref access'
# Each Hangul block on its own, first and last code point, as UTF-8 octal bytes.
hangul() { expect 1 "fix: report ref access $(printf '%b' "$1")"; }
hangul '\341\204\200' # U+1100 Jamo
hangul '\341\207\277' # U+11FF Jamo
hangul '\343\204\261' # U+3131 compatibility Jamo
hangul '\343\205\207' # U+3147 compatibility Jamo
hangul '\343\206\216' # U+318E compatibility Jamo
hangul '\343\210\200' # U+3200 parenthesized Hangul
hangul '\343\210\236' # U+321E parenthesized Hangul
hangul '\343\211\240' # U+3260 circled Hangul
hangul '\343\211\276' # U+327E circled Hangul
hangul '\352\245\240' # U+A960 Jamo Extended-A
hangul '\352\245\274' # U+A97C Jamo Extended-A
hangul '\352\260\200' # U+AC00 first syllable
hangul '\353\214\200' # U+B300 syllable
hangul '\355\225\234' # U+D55C syllable
hangul '\355\236\243' # U+D7A3 last syllable
hangul '\355\236\260' # U+D7B0 Jamo Extended-B
hangul '\355\237\273' # U+D7FB Jamo Extended-B
hangul '\357\276\241' # U+FFA1 halfwidth Hangul
hangul '\357\277\234' # U+FFDC halfwidth Hangul
# Neighbouring non-Hangul code points pass: this lint is about Hangul only.
other() { expect 0 "fix: report ref access $(printf '%b' "$1")"; }
other '\342\200\224 caf\303\251' # em dash, Latin-1
other '\343\204\205' # U+3105 Bopomofo
other '\343\206\220' # U+3190 Kanbun
other '\343\210\240' # U+3220 parenthesized ideograph
other '\343\212\200' # U+3280 circled ideograph
other '\346\227\245' # U+65E5 CJK ideograph
other '\352\200\200' # U+A000 Yi
other '\352\224\200' # U+A500 Vai
other '\352\246\200' # U+A980 Javanese
other '\357\275\261' # U+FF71 halfwidth Katakana
other '\357\277\240' # U+FFE0 fullwidth cent sign
# The code point just outside each block edge.
other '\341\203\277' # U+10FF, below Jamo
other '\341\210\200' # U+1200, above Jamo
other '\343\204\257' # U+312F, below compatibility Jamo
other '\343\210\237' # U+321F, above parenthesized Hangul
other '\343\211\237' # U+325F, below circled Hangul
other '\343\211\277' # U+327F, above circled Hangul
other '\352\245\237' # U+A95F, below Jamo Extended-A
other '\352\257\277' # U+ABFF, below the syllables
other '\355\236\244' # U+D7A4, gap after the last syllable
other '\355\236\257' # U+D7AF, gap before Jamo Extended-B
other '\357\276\237' # U+FF9F, below halfwidth Hangul
other '\357\277\235' # U+FFDD, above halfwidth Hangul
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
