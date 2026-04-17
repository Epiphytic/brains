---
role: master-implement
applies-under: --lean
---

## Skill
- `skills/implement/SKILL.md` (full, master-side only)

## References
- `references/teammate-protocol.md` (full)
  - required for constructing teammate initial-prompt templates at step 5a
- `references/beads-integration.md` (full)
  - required for tracker-selection (step 3) and progress polling (step 5b)
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
- `references/multi-llm-protocol.md` (lazy-on-demand)
- `references/failure-recovery.md` (lazy-on-demand)
  - on-demand-trigger: a teammate surfaces `brains:needs-human` (step 5c) or user-response timeout (step 5d)

## Artifacts
- `docs/adr/*.md` (whole-always)
  - pass ADR paths to teammate initial prompts
- `docs/plans/YYYY-MM-DD-<slug>-map.md` (full)
  - read at step 2 (load plan)
- `docs/plans/.state/<slug>-phase-<N>-marker.json` (full)
  - polled at step 5b

## Live context
- `git branch --show-current` (step 2)
- Beads queries: `bd query --label brains:topic:<slug> --label brains:phase-<N> --status <status>` (step 5b)
- Completion markers: file polling at step 5b
