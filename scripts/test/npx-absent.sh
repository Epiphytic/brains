#!/usr/bin/env bash
# npx-absent.sh — verifies the npx-absent fallback error path.
# Purpose: ADR-005 req 12 — the find-skills fallback MUST verify `command -v npx`
#          and, when npx is absent, log a clear error message and continue
#          without skill discovery for the session.
# Invocation: bash scripts/test/npx-absent.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
INVOKE="${REPO_ROOT}/references/skills-invocation.md"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$INVOKE" ]] || fail "missing $INVOKE"

grep -q 'command -v npx' "$INVOKE" \
  || fail "'command -v npx' check not documented in skills-invocation.md"

# The error message MUST mention either npx or Node.js explicitly so the user
# can understand what to install.
grep -qE 'requires.*hotskills.*npx|Install one to use --skills|Node\.js/npx' "$INVOKE" \
  || fail "npx-absent error message not documented in skills-invocation.md"

# The session MUST continue (no abort) — verify "continue" language is present.
grep -qE 'continue without skill discovery|continue without' "$INVOKE" \
  || fail "'continue without skill discovery' semantics not documented"

echo "PASS: npx-absent error+continue path is documented"
exit 0
