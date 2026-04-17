---
role: phase-1-brains
applies-under: --lean
---

## Skill
- `skills/brains/SKILL.md` (full)

## References
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - on-demand-trigger: debate-round synthesis, provider error handling, non-standard invocation
- `references/multi-llm-protocol.md` (lazy-on-demand)
  - on-demand-trigger: compact excerpt is insufficient for the specific case at hand
- `skills/brains/references/adr-template.md` (full)
  - loaded at step 8 (ADR generation)
- `skills/brains/references/research-summary-schema.md` (full)
  - loaded at step 2 (when writing the Research-Summary stash)
- `skills/brains/references/visual-companion.md` (lazy-on-demand)
  - on-demand-trigger: user accepts the visual-companion offer at step 4

## Artifacts
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (full)
  - this role WRITES the file; readers downstream use summary-with-drill-down
- `docs/adr/*.md` (whole-always)
- `ARCHITECTURE.md` (full, if present)

## Live context
- `git log --oneline -5` (for ADR Decision-makers field)
