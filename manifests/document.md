---
role: document
applies-under: --lean
---

## Skill
- `skills/document/SKILL.md` (full)

## References
- `skills/document/references/eligibility-detection.md` (full)
  - loaded at step 1 (eligibility gate) and re-run after editing
- `skills/document/references/slim-adr-template.md` (full)
  - loaded at step 4 (slim ADR generation)
- `references/commit-procedure.md` (full)
  - loaded at step 7 (inline commit and `.gitignore`)
- `references/multi-llm-protocol-compact.md` (compact-excerpt)
  - on-demand-trigger: debate-round synthesis, provider error handling, non-standard invocation
- `references/multi-llm-protocol.md` (lazy-on-demand)
  - on-demand-trigger: compact excerpt is insufficient for the document-review variant (`--parallel` / `--debate`)

## Artifacts
- `docs/adr/2026-05-23-006-brains-document-mode.md` (whole-always)
- `docs/adr/*.md` (whole-always)
  - the slim ADR this role WRITES at step 4
- `docs/research/YYYY-MM-DD-<slug>-research.md` (full, if present)
  - the optional orientation note this role MAY write at step 2

## Live context
- `git status --porcelain` (canonical changed set for the eligibility probe and inline commit)
