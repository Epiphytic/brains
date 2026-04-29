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
- `skills/diagram/references/flowchart.md` (lazy-on-demand)
  - on-demand-trigger: diagram generation (type: flowchart)
- `skills/diagram/references/state.md` (lazy-on-demand)
  - on-demand-trigger: diagram generation (type: state)
- `skills/diagram/references/structurizr.md` (lazy-on-demand)
  - on-demand-trigger: diagram generation (type: c4)
- `skills/diagram/references/storage-conventions.md` (lazy-on-demand)
  - on-demand-trigger: diagram generation
- `skills/diagram/references/renderer-conventions.md` (lazy-on-demand)
  - on-demand-trigger: diagram generation
- `references/find-skills.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set AND hotskills probe falls through (step 1 / question-generation external research)
- `references/skills-detection.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set; loaded once per session before the hotskills probe
- `references/skills-invocation.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set; loaded after detection resolves a provider
- `skills/brains/references/grill-protocol.md` (lazy-on-demand)
  - on-demand-trigger: `--grill` set (steps 3 and 5)

## Artifacts
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (full)
  - this role WRITES the file; readers downstream use summary-with-drill-down
- `docs/adr/*.md` (whole-always)
- `ARCHITECTURE.md` (full, if present)

## Live context
- `git log --oneline -5` (for ADR Decision-makers field)
