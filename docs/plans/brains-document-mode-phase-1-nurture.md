# Nurture Report: BRAINS Document Mode — Phase 1

## Review Summary

- Files reviewed: 4 (`skills/document/references/eligibility-detection.md`, `skills/document/references/slim-adr-template.md`, `skills/document/SKILL.md`, `references/commit-procedure.md`)
- Self-review: passed — frontmatter, BRAINS_PATH block, Mode Behavior table, Process steps, and Additional Resources match the house style of `skills/nurture/SKILL.md` and `skills/brains/SKILL.md`.
- Council review: `--parallel`, `uvx star-chamber review`. Providers: `gpt-5.4` (returned, quality "fair"); a second `openai` request timed out (noted, not blocking). `gemini-3.1-pro` did not return a distinct review in this run.
- Lint invariant: `bash scripts/manifest-lint.sh` exits 0 (8 manifests, 0 warnings) before and after fixes.

## Issues Fixed

1. **[HIGH] Code vs all-non-document conflation** (`eligibility-detection.md`) — eligibility (req 13) blocks on ANY non-document file, but the manual hard-refuse (req 17) is specific to **code** files. Introduced a three-class classification (`document` / `code` / `other-non-document`) with a `CODE_RE` and `CODE_COUNT`; §8 now hard-refuses on `CODE_COUNT > 0` and warn-and-confirms for oversized or non-code non-document scopes (`.svg`/`.mmd`/`.dsl`/`.ipynb`).
2. **[HIGH] "zero code files" threshold wording** (`eligibility-detection.md` §7) — changed to "zero non-document files" to match req 13.
3. **[HIGH] 10k-word council review not branched** (`SKILL.md` step 6) — review target list now partitions by `wc -w`: under-10k docs passed in full; ≥10k docs passed as a curated excerpt+summary review-input file in place of the source, per req 24.
4. **[HIGH] Questionnaire subagent vs teammate-instance ambiguity** (`SKILL.md` step 3) — clarified the question-generation `Agent` subagent is the same in-session helper `/brains:brains` uses and is NOT a teammate Claude Code instance (req 21 forbids teammate orchestration, not in-session subagents).
5. **[MEDIUM] Post-edit revalidation omitted the non-document invariant** (`SKILL.md` step 5) — now re-runs the FULL eligibility probe (§2–§6) including non-document detection after editing.
6. **[MEDIUM] Shared-procedure wording said "code"** (`commit-procedure.md`) — generalized "Ensure code is committed" to "Ensure changes are committed", noted the `docs:`-prefixed message for document mode, and folded the `.gitignore` update into the same atomic commit (reconciles req 27). Nurture's behavior is unchanged.
7. **[MEDIUM] Artifact exclusion list muddied the model** (`eligibility-detection.md` §3) — trimmed to artifacts the document-mode spine actually authors (slim ADR, orientation note, beads state).
8. **[MEDIUM] `--teammate-model` on a no-teammate skill** (`SKILL.md` intro) — documented that the flag is accepted only to forward the `/brains:brains` flag set verbatim and is inert here.
9. **[LOW] Over-justified diagram omission** (`slim-adr-template.md`) — softened to "omits Assumed Versions and Diagram by design."

## Council praise (recorded)

Eligibility reference mirrors the ADR hybrid-detection split clearly; slim ADR template preserves RFC-2119 discipline; the spine is easy to follow gate→commit; the shared-commit-procedure extraction is the right anti-drift move.

## Remaining Items

- The second council provider (`gemini-3.1-pro`) did not surface a distinct review this run; a provider request also timed out. Non-blocking per protocol. Phase-2 nurture can re-run review if desired.

All fixes committed: `e4ebd77`.
