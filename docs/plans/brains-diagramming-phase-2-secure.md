# Security Review: BRAINS Diagramming Phase 2 (Visual Companion Upgrades)

**Date:** 2026-04-23
**Scope:** phase-2 — frame-template.html, helper.js, server.cjs, assets/BRAINS.gif, SKILL.md, visual-companion.md

## Secrets Scan

Clean. No API keys, credentials, tokens, or hardcoded secrets found in any changed file.

## OWASP Assessment

### A03 — Injection / XSS

**Finding 1 (Medium, remediated):** helper.js lines 63/65 — dataset.choice value was interpolated unsanitized into DOM for the indicator bar label. Fixed by replacing string-concatenation DOM-update with explicit createElement + textContent + createTextNode so no HTML is ever parsed from untrusted attribute values.

**Finding 2 (Low, accepted):** renderADRView uses DOMPurify.sanitize() with USE_PROFILES html+svg+svgFilters before any DOM insertion. Verified: onerror attributes stripped, script tags stripped, Mermaid SVG passes through with svg profile.

**Finding 3 (Low, accepted):** _renderMermaidBlocks inserts Mermaid-generated SVG (trusted library output, not user content). Acceptable.

### A05 — Security Misconfiguration

**Finding 4 (Medium, partially remediated):** marked@14 and DOMPurify@3 CDN script tags lacked Subresource Integrity. Fixed: both now carry integrity="sha384-..." and crossorigin="anonymous". Mermaid ESM is loaded via an inline script type=module import — browsers do not support integrity on inline module scripts; documented with a comment.

**Finding 5 (Low, accepted):** No Content-Security-Policy header on server responses. Local dev tool bound to 127.0.0.1 — acceptable risk.

### A08 — Software and Data Integrity

**Finding 6 (Low, accepted):** BRAINS.gif committed as binary (1.43 MB). Verified GIF magic bytes GIF89a. No executable content.

### A09 — Security Logging and Monitoring

**Finding 7 (Low, accepted):** Unhandled JS errors silently swallowed. Local dev tool — acceptable.

## Dependency Audit

CDN-loaded libraries reviewed:
- marked@14 — current stable; no known CVEs at review time.
- DOMPurify@3 — current stable; active security maintenance.
- mermaid@11 — current stable; no known critical CVEs.

## Threat Model

**Assets:** ADR content in companion (may contain internal architecture), user option selections.

**Trust boundaries:**
1. Fragment HTML written by Claude -> frame DOM — low trust
2. CDN-loaded scripts (marked, DOMPurify, Mermaid) — medium trust (CDN supply chain)
3. dataset.choice values in fragments — untrusted

**Mitigations in place:**
- DOMPurify wraps all marked() output before DOM insertion
- SRI on marked + DOMPurify CDN scripts
- path.basename() prevents path traversal in /assets/ route
- Server bound to 127.0.0.1 only

## Findings Summary

| Severity | Category | Finding | Status |
|----------|----------|---------|--------|
| Medium | XSS | dataset.choice unsanitized in DOM update — helper.js | Remediated |
| Medium | Supply Chain | marked@14 + DOMPurify@3 CDN lacking SRI | Remediated |
| Low | Supply Chain | Mermaid@11 ESM inline import — SRI unsupported by browsers | Accepted |
| Low | Misconfiguration | No CSP header on server responses | Accepted (local dev tool) |
| Low | Logging | Silent JS error handling | Accepted (dev tool) |

## Remediations Applied

1. fix(security): XSS hardening — safe DOM construction + SRI for CDN scripts — e9bf3e9

## Remaining Risks

- Mermaid ESM CDN load cannot be verified via SRI (browser limitation for inline module imports). Acceptable for localhost-only development tooling.
- No CSP header — acceptable for localhost-only server.
