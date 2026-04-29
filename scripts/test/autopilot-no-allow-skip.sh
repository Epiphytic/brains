#!/usr/bin/env bash
# autopilot-no-allow-skip.sh — verifies the no-allow-status autopilot path.
# Purpose: ADR-005 req 9 — under --autopilot, when no result has
#          gate_status="allow", the skill MUST log + skip without blocking the
#          autopilot run. No activation, no user prompt.
# Invocation: bash scripts/test/autopilot-no-allow-skip.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
INVOKE="${REPO_ROOT}/references/skills-invocation.md"
ADR="${REPO_ROOT}/docs/adr/2026-04-28-005-brains-skills-integration.md"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$INVOKE" ]] || fail "missing $INVOKE"
[[ -f "$ADR" ]]    || fail "missing $ADR"

# The skip-without-blocking semantics MUST be documented in invocation OR ADR.
if ! grep -qE 'no allowed skill|skipping activation|log and skip|no.*allow.*skip' "$INVOKE" "$ADR"; then
  fail "no-allow log+skip semantics not documented in skills-invocation.md or ADR"
fi

# It MUST NOT block the autopilot run (req 9).
if ! grep -qE 'do NOT block|not block the autopilot|continue.*autopilot' "$INVOKE" "$ADR"; then
  fail "'do not block autopilot' contract not documented"
fi

echo "PASS: --autopilot no-allow-status log+skip path is documented"
exit 0
