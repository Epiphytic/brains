# BRAINS Role Manifests

Each manifest declares exactly what context a role loads at runtime under `--lean`. Skills consult their role's manifest and load only what it specifies. Without `--lean`, manifests are ignored and skills follow their inline instructions (byte-identical to v0.2.x behavior).

## Format

Each manifest is a markdown file with YAML front matter and four fixed sections. Fields are specified per section:

```markdown
---
role: <actor-name>
applies-under: --lean
---

## Skill
- `<path>` (<mode: full | teammate-slice>)

## References
- `<path>` (<mode: full | compact-excerpt | lazy-on-demand>)
  - on-demand-trigger: <when to escalate to full>  (only for lazy-on-demand)

## Artifacts
- `<path-or-pattern>` (<mode: full | summary-with-drill-down | whole-always>)
  - drill-down-trigger: <when to escalate to full>  (only for summary-with-drill-down)

## Live context
- <source> (<fetch command or static>)
```

## Modes

**Reference modes:**
- `full`: load the complete file at initialization.
- `compact-excerpt`: load a compact excerpt (typically a sibling file ending in `-compact.md`). Full file loaded only for edge cases named in `on-demand-trigger`.
- `lazy-on-demand`: do not load at initialization. Load in full when the condition in `on-demand-trigger` is met.

**Artifact modes:**
- `full`: always load the complete artifact (applies to rapidly-changing live artifacts like the current plan document).
- `summary-with-drill-down`: load only the structured summary (e.g. `Research-Summary` block). Drill down into the full file when the condition in `drill-down-trigger` is met.
- `whole-always`: load complete, never summarized, never partially loaded. **ADRs MUST use this mode in every manifest that references them.** It is the non-negotiable fidelity constraint from ADR-001.

## Manifest list

- `master-implement.md` — phase-3 master orchestrator
- `teammate.md` — per-plan-phase teammate Claude Code instance
- `nurture.md` — phase-3 nurture subagent
- `secure.md` — phase-3 secure subagent
- `star-chamber-ask.md` — star-chamber `ask` (design-question) invocation
- `star-chamber-review.md` — star-chamber `review` (code-review) invocation
- `phase-1-brains.md` — phase-1 `/brains:brains` skill
- `phase-2-map.md` — phase-2 `/brains:map` skill

## Drift detection

`scripts/manifest-lint.sh` validates manifests against skill bodies. CI runs it on every PR. See the script header for the exact rules.
