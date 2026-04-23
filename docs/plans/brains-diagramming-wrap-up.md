# Wrap-up: BRAINS Diagramming

**Slug:** brains-diagramming
**Paused:** false
**Branch:** brains/brains-diagramming
**ADR:** docs/adr/2026-04-23-002-brains-diagramming.md

## Per-Phase Summary

### Phase 1: Diagram Skill Foundation

- Tasks completed: 6/6 + Nurture + Secure
- Commits:
  - `e3deaba` — feat(diagram): scaffold brains:diagram skill — phase-1 foundation
  - `a6781ba` — fix(diagram): address nurture/council review findings
  - `ee418bb` — chore: ignore .claude/plugins/ and scheduled_tasks.lock
  - `dee4f0c` — fix(security): harden diagram skill against council security findings
  - `7c9af47` — docs(secure): add phase-1 security review report
- Nurture findings: addressed in `a6781ba` — adr-template.md un-commented, auto-trigger marker (`%% auto-generated`) defined, `--type` vs `--diagram` distinction clarified in flags table, `--max-diagrams` v0.4/v0.5 priority order corrected, lazy-on-demand scope tightened in routing table, renderer/storage references fixed.
- Secure findings: 10 (3 high, 5 medium, 2 low) — 9 fixed in `dee4f0c`, 1 filed as `brains-db3` (low severity: `--type` vs `--diagram` flag confusion)

### Phase 2: Visual Companion

- Tasks completed: 7/7 (2.1, 2.2, 2.3, 2.4, 2.5, 2.6a, 2.6b, 2.7) + Nurture + Secure
- Commits:
  - `71ec4eb` — feat(visual-companion): rebrand header/title to BRAINS! with repo link
  - `a52c36a` — feat(visual-companion): Mermaid ESM CDN, BRAINS.gif loader, zombie sprites
  - `bf9e2ed` — feat(visual-companion): ADR scrollable view with DOMPurify+marked, per-block Mermaid try/catch
  - `f96171a` — fix(visual-companion): async-safe Mermaid block rendering, remove stale static approach
  - `a2d5598` — docs(visual-companion): add diagram-capable fragment docs; mention architecture diagrams
  - `e9bf3e9` — fix(security): XSS hardening — safe DOM construction + SRI for CDN scripts
  - `fe0c1b8` — docs(secure): add phase-2 security review report
- Nurture findings: addressed in `f96171a` — async-safe Mermaid rendering, stale static approach removed.
- Secure findings: 5 (0 high, 2 medium, 3 low) — 2 medium fixed (`e9bf3e9`), 3 low accepted (Mermaid ESM SRI browser limitation, no CSP on localhost dev server, silent JS error handling)

### Phase 3: Auto-trigger Integration

- Tasks completed: 4/4 (3.1, 3.2, 3.3, 3.4) + Nurture + Secure
- Commits:
  - `827543f` — feat(brains): phase-3 auto-trigger integration
  - `3018359` — fix(brains): clarify ER/sequence v0.5-only status in step 8 and option-5
  - `3042923` — fix(security): explicit error on unknown --diagram type in brains SKILL.md
  - `6e55937` — docs(secure): add phase-3 security review report
- Nurture findings: addressed in `3018359` — ER/sequence v0.5-only status made explicit in step 8 dispatch note and option-5 enumeration.
- Secure findings: 1 (0 high, 0 medium, 1 low) — fixed in `3042923` (unknown `--diagram <type>` now errors with valid-type list)

### Phase 4: Kroki Container Setup

- Tasks completed: 3/3 (4.1, 4.2, 4.3) + Nurture + Secure
- Commits:
  - `94313b2` — feat(setup): add --with-kroki / --without-kroki Kroki container lifecycle
  - `1f4c1da` — fix(setup): address nurture/council review findings for phase-4
  - `f201003` — fix(security): harden phase-4 Kroki setup against council security findings
  - `1dd3d8b` — docs(secure): add phase-4 security review report
- Nurture findings: addressed in `1f4c1da` — idempotency on port mismatch (stop+recreate), fallback teardown when `kroki_runtime` missing, `renderer.json` write semantics made explicit (full replace, not merge), scope section clarified for Kroki-only invocations, duplicate renderer-conventions paragraphs merged.
- Secure findings: 8 (2 high, 3 medium, 3 low) — all 8 fixed in `f201003` (loopback binding, port injection, atomic write, port inspection, dual-runtime teardown, rm -f, .local trust doc, Kroki-only scope)

### Cleanup: brains-db3

- Decision: **documented, closed as wontfix**
- Rationale: `--type` and `--diagram` are flags in two separate skills with genuinely distinct semantics. `--type` is a `brains:diagram` flag that selects the diagram type for standalone invocation; `--diagram` is a `brains:brains` pipeline-level override that forces a type before heuristics run, then gets dispatched internally as `--type`. Consolidation would require `brains:diagram` to understand pipeline context it has no business knowing. The separation is load-bearing.
- Outcome: `skills/diagram/SKILL.md` flags table expanded with a Scope column and a dedicated explanatory note block; `argument-hint` corrected to show only standalone-relevant flags (`--type`, `--kroki-cloud`).
- Commit: see cleanup commit on this branch.

## Outstanding Work

No beads tickets remain open after this cleanup.

Out-of-scope v0.5 items per ADR-002 and plan:
- `sequence.md` and `er.md` per-type reference files (one file each, one router row each — purely additive)
- Auto-trigger dispatch for ER type: heuristic evaluates in step 8 but no diagram is dispatched until `er.md` ships (v0.5 activation)
- Auto-trigger dispatch for sequence type: same pattern as ER

## Known Gaps and Limitations

- **Mermaid ESM SRI**: The `mermaid@11` ESM CDN import in `frame-template.html` uses an inline `<script type="module">` block; browsers do not support Subresource Integrity on inline module scripts. Acceptable for localhost-only dev tooling; noted in a comment.
- **No CSP header**: `server.cjs` does not set a `Content-Security-Policy` header. Acceptable given the server is bound to `127.0.0.1` only and is a local dev tool. Not a production surface.
- **`npx mmdc` supply chain**: `npx -p @mermaid-js/mermaid-cli` downloads at runtime from the npm registry. Users can eliminate this risk by running `/brains:setup --with-kroki` to use the local Kroki container instead. Noted in `renderer-conventions.md`.
- **Test coverage**: All changes are in SKILL.md instruction text and `frame-template.html`/`helper.js`/`server.cjs`. No automated test suite covers the visual companion; manual testing validates the golden path. The retry-and-placeholder loop and renderer priority logic in `brains:diagram` are instruction-text only — correctness depends on the executing model following them.
- **BRAINS.gif optimization**: GIF committed at 1.43 MB (original 3.6 MB, optimized with `gifsicle -O3 --lossy=80`). Target was under 1.5 MB; achieved.
- **Zombie sprites**: Hand-authored inline SVG/CSS animations in `frame-template.html`. Thematic but minimal; no external asset sourcing.

## Suggested Follow-up Plans

- **v0.5: sequence and ER diagram types** — add `skills/diagram/references/sequence.md` and `er.md`, extend the router table in `brains:diagram/SKILL.md`, activate the ER heuristic dispatch in `brains:brains` step 8. Purely additive; no architectural changes needed.
- **Visual companion CSP hardening** — if the companion ever exposes a non-localhost surface, add a `Content-Security-Policy` header to `server.cjs` and evaluate the Mermaid ESM import strategy.
- **Automated rendering test** — a smoke test that invokes `/brains:diagram "test" --type flowchart` against a known-good renderer config and asserts `.mmd` + `.svg` output files exist at the expected paths.
