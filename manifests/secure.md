---
role: secure
applies-under: --lean
---

## Skill
- `skills/secure/SKILL.md` (full)

## References
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - required under `--parallel` / `--debate`
- `references/multi-llm-protocol.md` (lazy-on-demand)
- `references/beads-integration.md` (full)
  - required for filing follow-up security tasks

## Artifacts
- `docs/adr/*.md` (whole-always)
  - secure reads ADRs to identify declared security surface and required controls
- `docs/plans/YYYY-MM-DD-<slug>-map.md` (full)
  - read to understand phase scope when invoked with `--scope phase-<N>`
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (summary-with-drill-down)
  - drill-down-trigger: security-sensitive library or API mentioned in summary with empty detail

## Live context
- `git diff main...HEAD --stat` (scope changed files)
- `git log --oneline -20` (recent commits)
- Beads queries: open tasks in current scope
