---
plan: brains-skills-integration-secure
date: 2026-04-28
branch: brains/brains-skills-integration
reviewer: security-validator
---

# Security Review: ADR-005 Skills Integration

## Review Summary

**Files reviewed (26 changed, security-relevant subset):**
- `references/find-skills.md` — vendored LLM instruction doc
- `references/skills-detection.md` — MCP probe procedure
- `references/skills-invocation.md` — query derivation + npx/hotskills invocation
- `skills/setup/SKILL.md` — defaults.json migration, Kroki container setup
- `skills/brains/SKILL.md` — `gh pr create --draft` invocation
- `skills/implement/SKILL.md` — `gh pr ready` invocation
- `README.md` — flag documentation and examples
- `CHANGELOG.md` — release notes
- `scripts/test/*.sh` — test harness

**Findings by severity:**
| Severity | Count |
|----------|-------|
| P0 (blocker) | 0 |
| P1 (fix before merge) | 2 |
| P2 (should fix) | 1 |
| Info | 2 |

---

## Findings

### P1-1 — README `--autopilot` description contradicts implementation (misleads users into insecure config)

**File:** `README.md` line 196

**Issue:** The `--autopilot` flag entry states:
> "At the phase 1 ADR gate, `--autopilot` pre-selects 'accept ADR(s), push to origin, chain into /brains:map --autopilot' (option 2 of 5)."

This is a stale pre-v0.5.0 description. Per the v0.5.0 breaking change, `--autopilot` alone NO LONGER auto-accepts ADRs; `--accept-adrs` is required. The implementation in `skills/brains/SKILL.md` step 9 is correct. The README is wrong.

**Security impact:** Users who want HITL on architectural decisions may believe bare `--autopilot` is safe when it now correctly pauses at the ADR gate. Line 116 table entry compounds the error: "`--autopilot` auto-accepts ADRs at the gate without prompting" — wrong; that's `--accept-adrs`'s job.

---

### P1-2 — `npx skills find <query>` invocation lacks shell-quoting specification

**File:** `references/skills-invocation.md` line 42

**Issue:** The instruction reads verbatim:
> "invoke `npx skills find <query>` via the Bash tool"

No quoting is specified. The query is derived from beads task titles, topic slugs, or user prompts (truncated to 80 chars). If a beads task title or user prompt contains shell metacharacters (`;`, `|`, `$(`, backticks, `&&`, etc.), an LLM executing this instruction via the Bash tool could construct a command-injected invocation.

**Attack surface:** User-controlled prompt text at source 4; beads task titles at source 2 (which may embed user text). The 80-char truncation does not sanitize metacharacters.

**Concrete example:** A task title `"fix $(rm -rf ~) bug"` would produce `npx skills find fix $(rm -rf ~) bug` without quoting guidance — a live shell injection.

**Fix required:** The instruction MUST specify `npx skills find "$QUERY"` with the query assigned to a variable first, or equivalently note that the query string MUST be double-quoted as a single shell word when passed to Bash.

---

### P2-1 — `PR_URL` captured from `tail -n1` of `gh pr create` combined stderr/stdout

**File:** `skills/brains/SKILL.md` lines ~227-235

**Issue:**
```bash
PR_OUTPUT=$(gh pr create --draft --title "$ADR_TITLE" --body-file "$ADR" 2>&1) || true
PR_URL=$(echo "$PR_OUTPUT" | tail -n1)
```

`stderr` is merged into `PR_OUTPUT`. On auth failure or rate-limit, `tail -n1` captures the last error line (potentially an internal GH error message with token hints or endpoint details) and assigns it to `PR_URL`, which is then surfaced to the user. Not a direct exploit, but error lines can expose rate-limit details, internal GitHub endpoints, or OAuth token expiry messages in user-visible output.

**Preferred pattern:** Use `gh pr create ... --json url -q .url` (structured output) or separate stdout/stderr (`2>/dev/null`). The `implement/SKILL.md` PR-ready block already uses `--json url -q .url` correctly — align brains/SKILL.md to the same pattern.

---

### Info-1 — `find-skills.md` body: no embedded scripts, no suspicious URLs, no prompt-injection vectors

The vendored body is plain instructional markdown. All URLs are `https://skills.sh/`, `https://github.com/vercel-labs/`, `https://github.com/ComposioHQ/`, `https://nodejs.org/`. No `<script>`, `javascript:`, `data:`, eval, or exec constructs found. The BRAINS-specific autopilot override appended at the end is correctly scoped and non-executable. SHA pin is documented; no mechanism verifies it at runtime (acceptable — this is documentation, not a binary).

### Info-2 — defaults.json merge: no path traversal, no JSON injection, no race condition risk

The write target is hardcoded to `~/.config/brains/defaults.json`. No user-controlled path component. The merge is performed via the Read tool (structured JSON parse) and Write tool (serialized output) — no string concatenation of untrusted values into JSON. The `flags` object keys are enumerated statically. Concurrent setup runs could produce a TOCTOU on the read-merge-write cycle, but this is an LLM instruction document, not a multi-process binary; concurrent execution is not a realistic threat model here. Kroki `--port` validation (`1–65535`, digits-only) is present and correct.

---

## Fixes Applied

**P1-1 — `README.md` fixed in-place:**
- Line 196 (`--autopilot` description): removed stale "pre-selects option 2" clause; replaced with accurate description that `--autopilot` pauses at the ADR gate and requires `--accept-adrs` to also auto-accept it.
- Line 116 (`accept_adrs` table entry): corrected from "`--autopilot` auto-accepts ADRs" to "When combined with `--autopilot`, auto-accepts ADRs at the phase-1 gate."

**P1-2 — `references/skills-invocation.md` fixed in-place:**
- Line 42 (find-skills fallback step 3): replaced bare `npx skills find <query>` with `npx skills find "$QUERY"` pattern, with explicit guidance to assign the derived query to a variable and double-quote it as a single shell word.

---

## Out-of-Scope Recommendations

1. **Runtime vendor SHA verification:** `find-skills.md` documents a SHA but nothing checks it. A future enhancement could hash the vendored body at load time and warn if it diverges from the pinned SHA. Low urgency — the file is in version control.

2. **`npx` integrity:** `npx skills find` fetches package metadata from the npm registry. Consider documenting that the user's npm registry config (`NPM_CONFIG_REGISTRY`) is trusted input — a malicious registry override could poison skill search results.

3. **Query truncation boundary:** The 80-char word-boundary truncation correctly prevents empty queries but does not strip metacharacters. The P1-2 fix (quoting) is sufficient for now; a future hardening pass could explicitly strip or reject queries containing shell metacharacters before passing them to the Bash tool.
