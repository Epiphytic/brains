# Wrap-up: BRAINS v0.5.0

**Slug:** brains-v0-5-0
**Paused:** false
**Branch:** brains/brains-v0-5-0
**ADRs:** ADR-003 (er+sequence), ADR-004 (--grill)

## Per-Phase Summary

### Phase 1 — er and sequence diagram type activation
- Tasks completed: 9/9 implementation + nurture + secure
- Files: skills/diagram/references/er.md (new), sequence.md (new); skills/diagram/SKILL.md, renderer-conventions.md, storage-conventions.md, brains/SKILL.md, docs/diagrams.md, README.md, ADR-002 (Revision 3 note)
- Issues found (nurture): 1 — Generation Steps + placeholder section omitted er/sequence (fixed in 52b5a71)
- Issues found (secure): none

### Phase 2 — --grill strategy modifier
- Tasks completed: 7/7 implementation + nurture + secure
- Files: skills/brains/references/grill-protocol.md (new, 3852 bytes), skills/brains/SKILL.md (+26 net lines), README.md
- Issues found (nurture): 1 — grill-protocol.md missing from Additional Resources (fixed in 6ff4296)
- Issues found (secure): none

## Outstanding Work

None. All implementation, nurture, and secure tasks are closed.

## Known Gaps and Limitations
- Diagram SVGs were not rendered for ADR-003 and ADR-004; mmdc Puppeteer failed in the orchestration environment, so source-only fallback was used. Running `/brains:setup --with-kroki` would let any reader regenerate.
- ADR-002 Revision-3 note is appended; the body of ADR-002 is not retroactively rewritten (per the agreed promotion-note convention).

## Suggested Follow-up Plans

- Consider adding an end-to-end test fixture for the `er` and `sequence` auto-trigger heuristics once a test harness for brains:brains synthesis is in place.
- `--grill` follow-up extension to phases 2 and 3 is explicitly scoped out of v0.5.0 per ADR-004; evaluate after user feedback on phase-1 grilling UX.

## Token-budget compliance
- skills/diagram/references/er.md: 2837 bytes / 3 KB
- skills/diagram/references/sequence.md: 2992 bytes / 3 KB
- skills/brains/references/grill-protocol.md: 3852 bytes / 4 KB
- skills/diagram/SKILL.md: 5491 bytes / 4 KB (over budget — this is the existing SKILL.md which exceeded the cap prior to v0.5.0 changes; v0.5.0 additions were net-zero for this file per T-1.3)
- skills/brains/SKILL.md net growth across both phases: 26 / 45 lines

## Commits
```
6ff4296 docs(brains): add grill-protocol.md to SKILL.md Additional Resources ...
f6270d7 docs(brains): document --grill flag in README.md (T-2.6)
07bbb57 feat(brains): add --grill --autopilot handoff note to step 9 (T-2.5)
8522c22 feat(brains): document --grill termination and batching in step 5 (T-...
212a911 feat(brains): document --grill per-turn behavior in step 5 (T-2.4a)
4e83c29 feat(brains): document --grill seed generation in step 3 (T-2.3)
ab7bdb1 feat(brains): add --grill flag to step 1 argument parsing (T-2.2)
b1bbdcb feat(brains): add grill-protocol.md lazy-on-demand reference
52b5a71 fix(diagram): extend Mermaid type lists in SKILL.md generation steps ...
ce8cf9a docs(plan): record teammate-model sonnet in v0.5.0 map header
d8f0a75 feat(diagram): activate er and sequence types in v0.5.0
c0a0bc2 docs(plan): map BRAINS v0.5.0 — er+sequence and --grill
```
