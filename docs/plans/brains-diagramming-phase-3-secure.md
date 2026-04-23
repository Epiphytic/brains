# Security Review: brains-diagramming Phase 3

## Scope

Commits `827543f` and `3018359` — both modify `skills/brains/SKILL.md` only. Phase-3 adds auto-trigger heuristics (step 8), diagram flag parsing (step 1), ADR companion push (step 9), and option-5 diagram regeneration. All changes are prompt/instruction text; no executable code introduced.

## Secrets Scan

Clean. No credentials, tokens, API keys, or hardcoded secrets in changed file.

## OWASP Assessment

Relevant categories only (most OWASP categories are N/A for instruction text):

- **Injection**: Option-5 regeneration uses anchored per-type enumeration (`{state,flowchart,c4}`, no glob) and defers to `brains:diagram`'s existing stem sanitization (strips `..`, `/`, `\`). No new injection surface.
- **XSS**: Step 9 companion push passes ADR body to `renderADRView()`. DOMPurify sanitization established in phase-2 covers this path. No new surface.
- **Input Validation**: `--diagram <type>` accepted arbitrary string; unknown types would produce a silent no-op. Fixed (see Remediations).

## Dependency Audit

No new dependencies introduced in phase-3. N/A.

## Threat Model

| Asset | Trust Boundary | Vector | Mitigation |
|---|---|---|---|
| ADR body | renderADRView() companion write | XSS via rendered ADR body | DOMPurify (phase-2, in place) |
| Diagram files | Option-5 per-type enumeration | Path traversal via ADR stem | Anchored enumeration + upstream stem sanitization |
| `--diagram` flag value | CLI argument parsing | Unknown type string → silent no-op | Fixed: error with valid-type list |

## Findings

| Severity | Category | Finding | File | Remediation |
|---|---|---|---|---|
| Low | Input Validation | `--diagram <type>` with unknown type produced no error | `skills/brains/SKILL.md` | Fixed in commit `3042923` |

## Remediations Applied

1. Explicit error on unknown `--diagram <type>` value: lists valid types (`flowchart`, `state`, `c4`) — commit `3042923`

## Remaining Risks

None. No medium or higher findings. The one Low finding was remediated.
