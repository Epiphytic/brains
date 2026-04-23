# Security Review: brains-diagramming Phase 4

**Date:** 2026-04-23
**Scope:** Phase 4 commits — `94313b2` (Kroki lifecycle feature), `1f4c1da` (nurture fixes)
**Files:** `skills/setup/SKILL.md`, `skills/diagram/references/renderer-conventions.md`
**Mode:** --parallel (3 providers, 1 failed auth)

## Secrets Scan

Clean — no hardcoded secrets, API keys, or credentials found in phase-4 changes.

## OWASP Assessment

| Category | Result |
|----------|--------|
| Injection | **Fixed** — `--port N` now requires digits-only 1–65535 validation before shell substitution |
| Security Misconfiguration | **Fixed** — container bound to `127.0.0.1` not `0.0.0.0` |
| Sensitive Data | Clean — `renderer.json` contains no secrets; atomic write prevents torn-state reads |
| Access Control | Clean — `renderer.json` immutability rule enforced; only `brains:setup` writes it |
| Other categories | Not applicable to this feature (skill prompt documents, no runtime code) |

## Dependency Audit

No new runtime dependencies introduced. `yuzutech/kroki:latest` is a well-maintained official image; container isolation is the mitigation for any upstream vulnerabilities.

## Threat Model

**Assets:** diagram source text (may contain internal architecture), `~/.config/brains/renderer.json`

**Trust boundaries:**
- User CLI args (`--port N`) → shell command: mitigated by numeric validation
- `renderer.json` → diagram skill: mitigated by immutability rule + host/scheme validation
- Kroki container → local network: mitigated by loopback-only binding

**STRIDE highlights:**
- **T (Tampering):** atomic write (`write-to-tmp then mv`) prevents torn JSON state
- **I (Information Disclosure):** `127.0.0.1` binding prevents LAN exposure of diagram source
- **E (Elevation of Privilege):** no `--privileged`, no volume mounts, no extra capabilities

## Findings

| Severity | Category | Finding | Status |
|----------|----------|---------|--------|
| High | Network exposure | Container bound to 0.0.0.0, exposes Kroki to LAN | **Fixed** |
| High | Shell injection | `--port N` used unsanitized in shell command | **Fixed** |
| Medium | Atomicity | `renderer.json` write non-atomic; torn-state possible | **Fixed** |
| Medium | Correctness | Port inspect used `.HostConfig.PortBindings` (unreliable rootless) | **Fixed** |
| Medium | Correctness | Dual-runtime teardown undefined when both have brains-kroki | **Fixed** |
| Low | Maintainability | `rm` → `rm -f` for renderer.json deletion | **Fixed** |
| Low | Architecture | `.local` trust boundary undocumented vs standard setup path | **Fixed** |
| Low | UX/control flow | Kroki-only invocation still prompted for global/local scope | **Fixed** |

## Remediations Applied

1. Bind to `127.0.0.1:<PORT>:8000` — `f201003`
2. PORT numeric validation (digits-only 1–65535, error+exit on invalid) — `f201003`
3. Atomic `renderer.json` write (write `.tmp`, then `mv` into place; `mkdir -p` first) — `f201003`
4. Port inspection via `.NetworkSettings.Ports` instead of `.HostConfig.PortBindings` — `f201003`
5. Dual-runtime teardown: if `brains-kroki` found in both podman and docker, clean both — `f201003`
6. `rm -f` for renderer.json deletion — `f201003`
7. `.local` domain documented as broader trust model for user-managed instances — `f201003`
8. Scope section: Kroki-only invocations skip global/local prompt — `f201003`

## Remaining Risks

None — all findings remediated.

## Council Feedback

3 providers consulted (1 failed auth: nemotron-ultra-253b 403). Both responding providers (gemini-3.1-pro, gpt-5.4) rated the implementation "good". All council-identified issues were addressed. Consensus praise: strong `renderer.json` ownership boundary, robust SSRF prevention via host/scheme validation, and sound `--kroki-cloud` auto-trigger prohibition.
