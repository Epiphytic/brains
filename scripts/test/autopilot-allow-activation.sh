#!/usr/bin/env bash
# autopilot-allow-activation.sh — verifies the --skills --autopilot safety contract.
# Purpose: ADR-005 req 7 — under --autopilot, the skill MUST activate the first
#          gate_status="allow" result WITHOUT passing force_whitelist.
#          force_whitelist MUST NOT be passed regardless of any flag combination.
# Invocation: bash scripts/test/autopilot-allow-activation.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
INVOKE="${REPO_ROOT}/references/skills-invocation.md"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$INVOKE" ]] || fail "missing $INVOKE"

# The verbatim safety contract MUST mention force_whitelist and "MUST NOT".
grep -q 'force_whitelist' "$INVOKE" \
  || fail "force_whitelist contract not documented in skills-invocation.md"

grep -qE 'force_whitelist[^.]*MUST NOT' "$INVOKE" \
  || fail "'force_whitelist ... MUST NOT' contract not stated in skills-invocation.md"

# The autopilot allow-activation flow MUST be documented (gate_status === \"allow\").
grep -q 'gate_status' "$INVOKE" \
  || fail "gate_status field not referenced in skills-invocation.md"

grep -qE 'allow' "$INVOKE" \
  || fail "'allow' status semantics not documented in skills-invocation.md"

echo "PASS: --skills --autopilot allow-activation contract is documented"
exit 0
