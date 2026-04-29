#!/usr/bin/env bash
# config-migration-v01-to-v03.sh — verifies the documented non-destructive merge.
# Purpose: ADR-005 req 16 — `/brains:setup --global` MUST migrate stale
#          v0.1.0/v0.2.0 defaults.json by MERGING (preserving user values),
#          not overwriting. Builds a fixture v0.1.0 file with a custom value to
#          model what real users have on disk; then verifies that
#          skills/setup/SKILL.md step 3 documents non-destructive merge.
#          Does NOT actually run the migration (would require Claude Code).
# Invocation: bash scripts/test/config-migration-v01-to-v03.sh
# Expected exit code: 0 on PASS, 1 on FAIL.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="${REPO_ROOT}/skills/setup/SKILL.md"

fail() { echo "FAIL: $1"; exit 1; }
cleanup() { rm -rf "${TMPDIR_FIX:-}"; }
trap cleanup EXIT

[[ -f "$SETUP" ]] || fail "missing $SETUP"

# Fixture: a v0.1.0 file with a user-customized value the migration must preserve.
TMPDIR_FIX="$(mktemp -d)"
cat > "${TMPDIR_FIX}/defaults.json" <<'JSON'
{ "version": "0.1.0", "defaults": { "brains": "single" }, "debate_rounds": 99 }
JSON
[[ -s "${TMPDIR_FIX}/defaults.json" ]] || fail "fixture defaults.json was not written"

# Doc validation: setup SKILL.md MUST document non-destructive merge semantics.
grep -qi 'non-destructive' "$SETUP" \
  || fail "'non-destructive' merge language not documented in skills/setup/SKILL.md"

grep -qi 'preserve' "$SETUP" \
  || fail "'preserve' user-value language not documented in skills/setup/SKILL.md"

grep -qi 'merge' "$SETUP" \
  || fail "'merge' language not documented in skills/setup/SKILL.md"

grep -q '0.3.0' "$SETUP" \
  || fail "target schema v0.3.0 not documented in skills/setup/SKILL.md"

echo "PASS: defaults.json v0.1.0 -> v0.3.0 non-destructive merge is documented"
exit 0
