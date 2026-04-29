#!/usr/bin/env bash
# run-all.sh — BRAINS scripts/test/ runner.
# Purpose: iterate over every executable test in scripts/test/ (excluding self),
#          run each, accumulate pass/fail counts, print a summary, exit 0 iff
#          all tests passed.
# Invocation: bash scripts/test/run-all.sh
# Expected exit code: 0 if all tests pass, 1 if any fail.
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename -- "${BASH_SOURCE[0]}")"

pass=0
fail=0
failed_names=()

shopt -s nullglob
for t in "${THIS_DIR}"/*.sh; do
  name="$(basename -- "$t")"
  [[ "$name" == "$SELF" ]] && continue
  echo "--- running: $name ---"
  if bash "$t"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
done

echo
echo "=== BRAINS test summary ==="
echo "passed: $pass"
echo "failed: $fail"
if (( fail > 0 )); then
  echo "failures:"
  for n in "${failed_names[@]}"; do echo "  - $n"; done
  exit 1
fi
echo "all tests passed"
exit 0
