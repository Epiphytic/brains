#!/usr/bin/env bash
# manifest-lint.sh — static validator for BRAINS role manifests.
#
# Checks:
#   1. Every declared file path in manifests/*.md (Skill/References/Artifacts
#      sections only; Live-context section is not a path list) exists on disk.
#      Paths marked "(... if present)" are treated as optional.
#   2. Each manifest's `role:` frontmatter matches an allowed actor and the
#      filename.
#   3. Every `references/...\.md` or `skills/**/*.md` path mentioned in a
#      SKILL.md or teammate.md body is declared in the corresponding role
#      manifest. Emits warnings (not hard failures) for heuristic drift.
#   4. When a manifest declares `summary-with-drill-down` for any artifact,
#      the research-summary schema file exists and declares all required fields.
#   5. ADRs MUST be declared `whole-always` wherever referenced.
#
# Exit 0 on success, non-zero on any hard failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"
FAILURES=0
WARNINGS=0

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

warn() {
  echo "warn: $*" >&2
  WARNINGS=$((WARNINGS + 1))
}

info() {
  echo "info: $*"
}

ALLOWED_ROLES=(
  phase-1-brains
  phase-2-map
  master-implement
  teammate
  nurture
  secure
  star-chamber-ask
  star-chamber-review
)

is_allowed_role() {
  local role="$1" allowed
  for allowed in "${ALLOWED_ROLES[@]}"; do
    [[ "$role" == "$allowed" ]] && return 0
  done
  return 1
}

if [[ ! -d "$MANIFESTS_DIR" ]]; then
  fail "manifests/ directory not found at $MANIFESTS_DIR"
  exit 1
fi

# Extract entries from specific sections of a manifest.
# Prints tuples of: <raw-path> <mode-string>
# Only extracts from "## Skill", "## References", "## Artifacts" — NOT "## Live context".
extract_path_entries() {
  local manifest="$1"
  awk '
    /^## Skill$/        { in_section=1; next }
    /^## References$/   { in_section=1; next }
    /^## Artifacts$/    { in_section=1; next }
    /^## Live context$/ { in_section=0; next }
    /^## Rationale$/    { in_section=0; next }
    /^## / && in_section { in_section=0 }
    in_section && /^- `/ { print }
  ' "$manifest"
}

for manifest in "$MANIFESTS_DIR"/*.md; do
  name="$(basename "$manifest" .md)"
  [[ "$name" == "README" ]] && continue

  role="$(awk '/^role:/ {print $2; exit}' "$manifest")"
  if [[ -z "$role" ]]; then
    fail "$manifest: missing \`role:\` in frontmatter"
    continue
  fi
  if ! is_allowed_role "$role"; then
    fail "$manifest: role \`$role\` is not in the allowed actor set"
  fi
  if [[ "$role" != "$name" ]]; then
    fail "$manifest: role \`$role\` does not match filename \`$name\`"
  fi

  while IFS= read -r line; do
    # Extract the first backtick-quoted token; treat as path candidate.
    path="$(echo "$line" | sed -n 's/.*`\([^`]*\)`.*/\1/p' | head -1)"
    [[ -z "$path" ]] && continue

    # Mode/note string is in parens after the backticks.
    mode="$(echo "$line" | sed -n 's/.*` *(\([^)]*\)).*/\1/p' | head -1)"

    # Skip globs/placeholders — these are patterns, not concrete paths.
    if [[ "$path" == *"*"* ]] || [[ "$path" == *"<"* ]]; then
      continue
    fi

    # Skip "not applicable" sentinel.
    if [[ "$path" == "not applicable" ]]; then
      continue
    fi

    # Skip entries marked "if present".
    if [[ "$mode" == *"if present"* ]]; then
      continue
    fi

    # Strip leading $BRAINS_PATH/ if present.
    rel="${path#\$BRAINS_PATH/}"
    rel="${rel#./}"

    # Paths that don't look like files (no dot, no slash with an extension) are
    # likely prose. Only validate paths with a clear extension.
    if [[ ! "$rel" =~ \.(md|json|yaml|yml|sh|py|js|ts|txt)$ ]]; then
      continue
    fi

    if [[ ! -e "$REPO_ROOT/$rel" ]]; then
      fail "$manifest: declared path \`$rel\` does not exist"
    fi

    # ADR references MUST be whole-always.
    if [[ "$rel" == docs/adr/* ]] || [[ "$path" == *"docs/adr/"* ]]; then
      if [[ "$mode" != *"whole-always"* ]]; then
        fail "$manifest: ADR reference \`$path\` does not use \`whole-always\` mode (found: \`$mode\`)"
      fi
    fi

  done < <(extract_path_entries "$manifest")
done

# Research-summary schema check.
if grep -rq "summary-with-drill-down" "$MANIFESTS_DIR" 2>/dev/null; then
  schema="$REPO_ROOT/skills/brains/references/research-summary-schema.md"
  if [[ ! -f "$schema" ]]; then
    fail "Research-summary schema not found at $schema (required because a manifest declares \`summary-with-drill-down\`)"
  else
    for field in libraries-and-versions deprecated-apis-to-avoid codebase-patterns prior-art constraints; do
      if ! grep -q "$field" "$schema"; then
        fail "Research-summary schema at $schema is missing required field \`$field\`"
      fi
    done
  fi
fi

# Cross-reference: warn if skill bodies reference files not declared in their
# corresponding manifest. Heuristic — emits info, not a hard failure — to
# avoid false positives from prose references.
check_skill_refs() {
  local skill_file="$1" role="$2"
  local manifest="$MANIFESTS_DIR/$role.md"
  [[ -f "$manifest" ]] || return 0
  [[ -f "$skill_file" ]] || return 0

  while IFS= read -r refpath; do
    [[ "$refpath" == *"*"* || "$refpath" == *"<"* ]] && continue
    # Strip $BRAINS_PATH/ for the lookup.
    rel="${refpath#\$BRAINS_PATH/}"
    if ! grep -qF "$rel" "$manifest"; then
      info "$skill_file references \`$refpath\` not declared in $(basename "$manifest") (heuristic)"
    fi
  done < <(grep -oE '\$BRAINS_PATH/(references|skills)/[a-zA-Z0-9_./-]+\.md' "$skill_file" 2>/dev/null | sort -u)
}

check_skill_refs "$REPO_ROOT/skills/brains/SKILL.md" phase-1-brains
check_skill_refs "$REPO_ROOT/skills/map/SKILL.md" phase-2-map
check_skill_refs "$REPO_ROOT/skills/implement/SKILL.md" master-implement
check_skill_refs "$REPO_ROOT/skills/implement/teammate.md" teammate
check_skill_refs "$REPO_ROOT/skills/nurture/SKILL.md" nurture
check_skill_refs "$REPO_ROOT/skills/secure/SKILL.md" secure

manifest_count="$(find "$MANIFESTS_DIR" -maxdepth 1 -name '*.md' -not -name 'README.md' | wc -l | tr -d ' ')"
if [[ "$FAILURES" -eq 0 ]]; then
  echo "manifest-lint: OK ($manifest_count manifests checked, $WARNINGS warnings)"
  exit 0
else
  echo "manifest-lint: $FAILURES failure(s), $WARNINGS warning(s)" >&2
  exit 1
fi
