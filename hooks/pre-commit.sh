#!/bin/bash

# Get staged Dart files (excluding generated files)
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E "\.dart$" | grep -v -E "\.g\.dart$|\.freezed\.dart$|\.mocks\.dart$")

if [ -z "$STAGED_DART_FILES" ]; then
  exit 0
fi

# Format check
echo "Checking code format..."
echo "$STAGED_DART_FILES" | xargs dart format --set-exit-if-changed > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "ERROR: Code formatting failed. Run: dart format ."
  exit 1
fi

# Analyze check
echo "Running dart analyze..."
dart analyze 2>&1 | grep -E "^(error|warning|info)" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "ERROR: Dart analyze failed"
  exit 1
fi

exit 0
