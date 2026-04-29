#!/usr/bin/env bash
# hotskills-list-throws.sh — verifies the documented try/catch fallback contract.
# Purpose: ADR-005 req 2(b)+3 — when the hotskills tool is present but
#          hotskills.list() throws, the skill MUST catch and fall through to the
#          fallback while logging a single-line user-visible warning.
# Invocation: bash scripts/test/hotskills-list-throws.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DETECT="${REPO_ROOT}/references/skills-detection.md"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$DETECT" ]] || fail "missing $DETECT"

grep -qE 'try/catch|try and catch' "$DETECT" \
  || fail "try/catch error-handling not documented in skills-detection.md"

# Warning-log contract MUST mention 'fallback' and the probe-failure case.
grep -qi 'fallback' "$DETECT" \
  || fail "fallback warning-log contract not documented in skills-detection.md"

grep -qE 'list\(\) failed|probe failed|throw' "$DETECT" \
  || fail "list/probe-failure language not documented in skills-detection.md"

echo "PASS: hotskills.list() throw handling is documented (try/catch + fallback warning)"
exit 0
