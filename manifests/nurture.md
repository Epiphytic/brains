---
role: nurture
applies-under: --lean
---

## Skill
- `skills/nurture/SKILL.md` (full)

## References
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - required under `--parallel` / `--debate`
- `references/multi-llm-protocol.md` (lazy-on-demand)
- `references/beads-integration.md` (full)
  - required for filing follow-up tasks (`brains:phase-<N+1>` or `brains:cleanup`)

## Artifacts
- `docs/adr/*.md` (whole-always)
  - nurture reads ADRs to check implementation against declared requirements
- `docs/plans/YYYY-MM-DD-<slug>-map.md` (full)
  - read to understand phase scope when invoked with `--scope phase-<N>`
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (summary-with-drill-down)
  - drill-down-trigger: reviewing a file that cites a specific research constraint; `--ignore-research-summary` set

## Live context
- `git diff main...HEAD --stat` (scope recent changes)
- `git log --oneline -20` (recent commits)
- Beads queries: open tasks in current scope
