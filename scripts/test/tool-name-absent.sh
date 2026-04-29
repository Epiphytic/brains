#!/usr/bin/env bash
# tool-name-absent.sh — verifies the documented hotskills-absent fallback path.
# Purpose: ADR-005 req 2(a)+12 — when the hotskills MCP tool name is absent from
#          the session, the skill MUST detect it and route to the npx find-skills
#          fallback. Doc-validation test: greps the reference docs for the
#          documented procedure (BRAINS skills are markdown, not executable code).
# Invocation: bash scripts/test/tool-name-absent.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
DETECT="${REPO_ROOT}/references/skills-detection.md"
INVOKE="${REPO_ROOT}/references/skills-invocation.md"

fail() { echo "FAIL: $1"; exit 1; }

[[ -f "$DETECT" ]] || fail "missing $DETECT"
[[ -f "$INVOKE" ]] || fail "missing $INVOKE"

grep -q 'mcp__plugin_hotskills_hotskills__hotskills_search' "$DETECT" \
  || fail "tool-name presence check not documented in skills-detection.md"

grep -q 'npx skills find' "$INVOKE" \
  || fail "find-skills 'npx skills find' invocation not documented in skills-invocation.md"

grep -q 'command -v npx' "$INVOKE" \
  || fail "'command -v npx' precondition not documented in skills-invocation.md"

echo "PASS: tool-name-absent fallback path is documented"
exit 0
