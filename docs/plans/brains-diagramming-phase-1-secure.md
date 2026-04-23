# Security Review: brains-diagramming Phase 1

**Date:** 2026-04-23
**Scope:** Phase 1 files — skills/diagram/ (SKILL.md + 5 references), manifests/phase-1-brains.md, skills/brains/references/adr-template.md
**Mode:** --parallel (star-chamber review)
**Providers:** gemini-3.1-pro, gpt-5.4 (1 provider failed auth on nemotron-ultra-253b)

## Secrets Scan

Clean. No credentials, API keys, tokens, or hardcoded secrets in any phase-1 file.

## OWASP Assessment

Most categories not applicable (no web app, no SQL, no auth system). Relevant findings:

- **A03 Injection / A10 SSRF** — `kroki_url` used to construct HTTP POST target without validation. **Fixed.**
- **A01 Broken Access Control** — renderer.json write access by non-setup skills. Clarified as behavioral contract. **Fixed.**
- **A05 Security Misconfiguration** — `--kroki-cloud` interactive consent path undefined in auto-trigger context. **Fixed.**

## Dependency Audit

No new dependencies added in phase-1. No package.json, requirements.txt, or Cargo.lock touched.

## Threat Model

| Asset | Trust Boundary | Attack Vector | Mitigation |
|---|---|---|---|
| Internal architecture source | `--kroki-cloud` flag | Exfiltration to kroki.io | Per-invocation consent; DISALLOWED in auto-trigger |
| Internal architecture source | `kroki_url` in renderer.json | SSRF: renderer.json tampered to point to internal network | URL validation: http/https + localhost/127.0.0.1/.local only |
| `.mmd` / `.svg` files | ADR stem derivation | Path traversal via crafted ADR filename | Stem sanitization: basename + reject `..` `/` `\` |
| User-edited `.mmd` files | Auto-trigger marker check | Silent overwrite of manual edits | Marker now instructs user to remove it; exact match required |
| @mermaid-js/mermaid-cli package | npx runtime download | Supply chain: malicious package version | Out of scope for doc phase; note added in renderer-conventions.md |

## Findings and Remediations

| Severity | Finding | Remediation | Commit |
|---|---|---|---|
| High | `--kroki-cloud` undefined in auto-trigger context (no interactive consent possible) | Documented as DISALLOWED in auto-trigger; source-only fallback mandated | dee4f0c |
| High | Ordered overwrite destroyed last-known-good SVG on any `.svg` write failure | Distinguish parse error (delete stale) vs I/O transient (preserve last-good) | dee4f0c |
| High | Auto-trigger marker gave no indication that edits would be overwritten | Marker now reads "remove this line to protect manual edits" | dee4f0c |
| Medium | `kroki_url` unvalidated — SSRF-like risk | URL validation: scheme + localhost-only host classes | dee4f0c |
| Medium | `kroki_url` trailing slash not normalized | Strip trailing slash before appending `/mermaid/svg` | dee4f0c |
| Medium | renderer.json immutability overstated as enforced boundary | Reworded as behavioral contract (spec-enforced, not sandbox) | dee4f0c |
| Medium | Generation step ambiguous: render from memory vs from .mmd file | Clarified: write .mmd, render from .mmd, write .svg | dee4f0c |
| Medium | ADR stem not sanitized — path traversal possible | Stem sanitization rule added to storage-conventions.md | dee4f0c |
| Low | Flag confusion --type vs --diagram — filed for phase-cleanup | Filed as brains:cleanup bead | n/a |
| Low | Auto-trigger marker BOM/whitespace matching unspecified | Exact byte-for-byte match rule with BOM/whitespace rejection documented | dee4f0c |

## Remaining Risks

- **npx supply chain**: `npx -p @mermaid-js/mermaid-cli` downloads at runtime. Acceptable risk for a dev-tool plugin; users can use Kroki container to avoid it. Noted in renderer-conventions.md.
- **renderer.json as convention boundary**: enforcement is behavioral, not technical. Acceptable for a single-user plugin context.
- **`--type` vs `--diagram` flag redundancy**: Low-severity UX issue; filed as cleanup task for phase-2+ cycle.

## Council Feedback Summary

Both providers (gemini-3.1-pro, gpt-5.4) rated the implementation "good". Consensus: excellent modular architecture, lazy-loading pattern, strong no-cloud-default posture. Main gaps were around SSRF from unvalidated `kroki_url`, ambiguous auto-trigger cloud consent, overwrite semantics, and user-data protection in the auto-trigger marker. All high and medium findings addressed.
