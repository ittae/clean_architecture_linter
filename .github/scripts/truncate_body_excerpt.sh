#!/usr/bin/env bash
# Truncate a PR body (stdin) to <=300 bytes and guarantee valid UTF-8 output.
#
# `head -c 300` cuts on a byte boundary, which can split a multi-byte UTF-8
# character (common in Korean PR bodies) and leave a trailing invalid byte.
# `iconv -c` drops that trailing partial sequence so the excerpt is always
# valid UTF-8 — but iconv exits non-zero whenever it actually drops a partial
# character (the expected, common case for non-ASCII input). Callers must
# not treat that as fatal, so this script neutralizes it internally: no
# caller anywhere needs its own `|| true` to stay safe.
#
# Usage: printf '%s' "$BODY" | truncate_body_excerpt.sh
set -euo pipefail

head -c 300 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || true
