#!/bin/bash

# Run pre-commit checks first
./hooks/pre-commit.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Pre-commit checks failed"
  exit 1
fi

# Run all tests
echo "Running tests..."
dart test --reporter=compact

if [ $? -ne 0 ]; then
  echo "ERROR: Tests failed"
  exit 1
fi

exit 0
