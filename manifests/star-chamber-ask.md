---
role: star-chamber-ask
applies-under: --lean
---

## Skill
- not applicable (this role is a sub-invocation, not a top-level skill)

## References
- `references/multi-llm-protocol.md` (lazy-on-demand)
  - on-demand-trigger: debate-round synthesis, error handling, non-standard invocation

## Artifacts
- `ARCHITECTURE.md` (full, if present)
- `.claude/rules/*.md` (filtered-full)
  - include ONLY rules files whose frontmatter tag is `architectural` or `security-relevant`; omit all others
- `docs/adr/*.md` (whole-always)
  - when the question is about a decision covered by existing ADRs, include them in full
- skill-specific payload (full)
  - research summary, ADR draft, plan draft, etc., supplied by the invoking skill

## Live context
- `git diff HEAD~3 --stat` — **OMIT for `ask` calls under `--lean`** (low-signal for design questions where no implementation exists yet)

## Rationale
`ask` calls evaluate design decisions before implementation. A `--stat` diff and non-architectural rules files add noise without signal. The invoking skill is responsible for assembling a tight, purpose-built payload.
