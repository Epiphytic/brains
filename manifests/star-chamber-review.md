---
role: star-chamber-review
applies-under: --lean
---

## Skill
- not applicable (sub-invocation)

## References
- `references/multi-llm-protocol.md` (lazy-on-demand)
  - on-demand-trigger: debate-round synthesis, error handling

## Artifacts
- `ARCHITECTURE.md` (full, if present)
- `.claude/rules/*.md` (filtered-full)
  - include ONLY rules files whose frontmatter tag is `architectural` or `security-relevant`
- `docs/adr/*.md` (whole-always)
  - when the reviewed code claims to implement an ADR, include relevant ADRs in full
- changed files (full)
  - supplied by the invoking skill via `star-chamber review --context-file ... <files>`

## Live context
- `git diff HEAD~3 --stat` — **RETAIN for `review` calls** (the diff is the review subject)
- `git log --oneline -10` (recent commits in scope)

## Rationale
`review` calls evaluate concrete code changes. The `--stat` diff and recent commits frame what is under review. Rules files remain filtered to the two architectural tags to avoid noise from CI/commit-message conventions.
