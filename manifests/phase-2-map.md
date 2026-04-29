---
role: phase-2-map
applies-under: --lean
---

## Skill
- `skills/map/SKILL.md` (full)

## References
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - on-demand-trigger: debate-round synthesis, provider error handling
- `references/multi-llm-protocol.md` (lazy-on-demand)
- `references/beads-integration.md` (full)
  - loaded at step 8 (tracker selection) and step 9 (task creation)
- `skills/map/references/plan-format.md` (full, if present)
- `references/find-skills.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set AND hotskills probe falls through during step 5 (codebase exploration refresher)
- `references/skills-detection.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set; loaded once per session before the hotskills probe
- `references/skills-invocation.md` (lazy-on-demand)
  - on-demand-trigger: `--skills` set; loaded after detection resolves a provider
- `skills/brains/references/research-summary-schema.md` (full, if present)
  - loaded under `--lean` when reading the Research-Summary block embedded in the plan header

## Artifacts
- `docs/adr/*.md` (whole-always)
  - match filenames to topic slug; load ALL matching ADRs in full
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (summary-with-drill-down)
  - drill-down-trigger: summary field is empty but research has a matching section; task flagged `risk:high` during grooming; `--ignore-research-summary` was passed
- `docs/plans/YYYY-MM-DD-<slug>-map.md` (full)
  - this role WRITES the file

## Live context
- `git branch --show-current`
- `git log --oneline -5`
