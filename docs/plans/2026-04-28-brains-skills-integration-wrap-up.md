# Wrap-up: brains-skills-integration

**Slug:** brains-skills-integration
**ADR:** docs/adr/2026-04-28-005-brains-skills-integration.md (49 RFC-2119 requirements)
**Mode:** --parallel --autopilot --bullets (serial sweep)
**Branch:** brains/brains-skills-integration
**PR:** https://github.com/Epiphytic/brains/pull/4
**Paused:** false

## Per-Task Summary (10 tasks, all closed)

| Task | Bead | Outcome |
|---|---|---|
| T-1 Foundation | brains-6ey | ✅ Vendored find-skills.md, defaults.json v0.3.0 schema + merge migration, AGENTS.md note, research-path migration to docs/research/ |
| T-2 Skills plumbing | brains-3rr | ✅ --skills/--no-skills + flags.grill resolution in 3 SKILL.md files; skills-detection.md + skills-invocation.md; teammate.md T1.1; teammate-protocol.md |
| T-3 Branch + PR + links | brains-cet | ✅ --accept-adrs flag; branch hoist; gh pr create --draft auto; ADR/PR/plan link surfacing at gates; gh pr ready in wrap-up |
| T-4 CI grooming check | brains-ouh | ✅ teammate.md T2 post-grooming gh run list with HEAD~1 dedup; files ci-failure tickets for new failures only |
| T-5 Nurture doc strengthening | brains-l4z | ✅ nurture/SKILL.md P1 Missing docs + Step 5 fix block; teammate.md T4 proactive doc bullet |
| T-6 README + CHANGELOG | brains-ckl | ✅ README flag prose + Configuration section; CHANGELOG.md v0.5.0 with Breaking Changes/Added/Changed sections |
| T-7 E2E tests | brains-5yn | ✅ 6 E2E test scripts under scripts/test/ + run-all.sh runner; all 6 passing; brains-00m filed for CI wiring |
| T-8 Implement --bullets mode | brains-98u | ✅ META — implements the very mode that produced this plan. Auto-detection heuristic (3 conditions); plan-format.md Serial Sweep Mode section |
| T-9 Nurture review | brains-4bw | ✅ 17 files reviewed; 7 P1 fixes in-place; coverage matrix confirms all 49 ADR reqs land |
| T-10 Secure review | brains-uil | ✅ 2 P1 fixes (README stale autopilot wording + shell-injection in npx skills find); 1 P2 deferred (brains-iqt) |

## Coverage Validation

All 49 ADR-005 RFC-2119 requirements mapped to a code site (full coverage matrix in nurture report). Tests: `bash scripts/test/run-all.sh` → 6/6 green throughout.

## Outstanding Cleanup Tickets

| Bead | Title | Origin |
|---|---|---|
| brains-00m | Wire scripts/test/ into project CI | T-7 |
| brains-iqt | Align gh pr create PR_URL extraction to --json pattern | T-10 secure P2 |
| brains-b8g | Fix grill protocol convergence prompt with 1 question left | Pre-existing — surfaced during phase-1 grilling |

All three are non-blocking follow-ups, not part of v0.5.0 acceptance.

## Known Gaps and Limitations

- Vendored `references/find-skills.md` is pinned to upstream SHA `0b8fb22aaa7f82447d4befe1b6a95d30a5b279b8` (vercel-labs/skills v1.5.x). Refresh policy documented in AGENTS.md; nurture may file refresh tickets if older than 90 days.
- Hotskills compatibility pinned to ≥0.1.4 (current). API surface (`hotskills.search`, `hotskills.activate`, `hotskills.invoke`, `hotskills.list`, `gate_status`, `skill_id`, `installs`) documented in `references/skills-detection.md` maintenance header. Any rename in a hotskills release will silently fall through to the find-skills fallback (acceptable degradation).
- Test suite uses doc-validation greps rather than runtime end-to-end execution (BRAINS skills are markdown instructions, not directly executable code). Wired-into-CI follow-up is brains-00m.

## Suggested Follow-up Work

The amendments to ADR-005 grew the scope substantially (44 → 49 requirements over 6 user-driven amendments). Future BRAINS work should consider:

- An ADR-006 if `--bullets` mode itself accumulates further design decisions beyond what landed here
- A formal BRAINS test harness (currently `scripts/test/` is the first step) that runs in CI on every PR
- Hotskills opportunistic-mode integration (ADR-005's auto-detection chooses between hotskills and find-skills, but doesn't yet leverage hotskills' opportunistic suggestions hook from ADR-005 of the hotskills plugin itself)

## Phase Completion

This run demonstrates the `--bullets` mode end-to-end: 10 coarse tasks executed inline (no teammate spawn) in a single orchestrator session, with grooming-style enumeration of file-level work happening organically per-task. Total session duration spans ADR-005 brainstorm + 6 amendment cycles + plan reshape + inline implementation.

The PR will be transitioned from draft to ready immediately after this wrap-up commits.
