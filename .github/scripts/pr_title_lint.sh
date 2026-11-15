#!/usr/bin/env bash
# Lint a PR title for this public package.
#
# PRs are squash-merged, so the PR title becomes the commit subject, and
# release-please copies the subject of every changelog-visible commit into
# CHANGELOG.md, which pub.dev shows to package users. So:
#   - a title whose type is rendered in the changelog (feat, fix, perf, revert,
#     deps, or any type marked breaking with `!`) must not contain Hangul;
#   - no title may carry a private `ITT-<n>` issue key.
# Keep CHANGELOG_TYPES in step with the visible entries of `changelog-sections`
# in release-please-config.json.
#
# usage: pr_title_lint.sh "<title>"   exit 0 pass, 1 lint failure, 2 usage
set -euo pipefail

CHANGELOG_TYPES='feat|fix|perf|revert|deps'

title=${1:-}
if [ -z "$title" ]; then
  echo "usage: pr_title_lint.sh \"<title>\"" >&2
  exit 2
fi

fail() {
  echo "::error::$1"
  exit 1
}

if ! [[ "$title" =~ ^([a-z]+)(\([^\)]+\))?(!)?:\ .+ ]]; then
  fail "PR title is not a Conventional Commit title (<type>: <summary>): $title"
fi
type=${BASH_REMATCH[1]}
breaking=${BASH_REMATCH[3]:-}

if [[ "$title" =~ ITT-[0-9]+ ]]; then
  fail "PR title carries a private issue key; remove it (public metadata): $title"
fi

# Hangul Jamo, compatibility Jamo, and syllables as UTF-8 byte sequences.
# Byte patterns keep the check independent of the runner locale.
has_hangul() {
  printf '%s' "$1" | LC_ALL=C grep -qE "$(printf '\341[\204-\207][\200-\277]|\343[\204-\206][\200-\277]|[\352-\355][\200-\277][\200-\277]')"
}

if [[ "$type" =~ ^($CHANGELOG_TYPES)$ ]] || [ -n "$breaking" ]; then
  if has_hangul "$title"; then
    fail "'$type${breaking}' titles go into the public CHANGELOG.md as written; write the summary in English: $title"
  fi
fi
