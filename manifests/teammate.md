---
role: teammate
applies-under: --lean
---

## Skill
- `skills/implement/teammate.md` (full)
  - teammate-side protocol ONLY; the master-side `skills/implement/SKILL.md` is NOT loaded by teammates

## References
- `references/teammate-protocol.md` (full)
  - required for completion-marker format at T6 and for understanding the spawn contract
- `references/beads-integration.md` (full)
  - required for task queries (T2 grooming, T3 execution)
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - required for T4 nurture and T5 secure under `--parallel` / `--debate`
- `references/multi-llm-protocol.md` (lazy-on-demand)
  - on-demand-trigger: debate-round synthesis, provider error handling
- `references/failure-recovery.md` (lazy-on-demand)
  - on-demand-trigger: first task failure in T3 (failure flow summary inline in teammate.md is sufficient for the happy path)

## Artifacts
- `docs/adr/*.md` (whole-always)
  - ADR paths passed in initial prompt; load ALL of them in full for task context at T3
- `docs/plans/YYYY-MM-DD-<slug>-map.md` (full)
  - read at T1 to understand phase scope
- `docs/plans/YYYY-MM-DD-<slug>-research.md` (summary-with-drill-down)
  - drill-down-trigger: task flagged `risk:high`; `model-hint: prefer-opus` set on task; `--ignore-research-summary` was passed to master
- `docs/plans/.state/<slug>-phase-<N>-marker.json` (full)
  - this role WRITES the file at T6

## Live context
- Beads queries: tasks matching `brains:topic:<slug>` + `brains:phase-<N>` at various statuses
- Recent commits: `git log --oneline -10` (per-task context at T3)
