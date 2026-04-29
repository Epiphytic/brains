# Nurture Report: BRAINS `--skills` integration (T-1..T-8)

**Slug:** brains-skills-integration
**Scope:** ADR-005 reqs 1-49; T-1..T-8 of `docs/plans/2026-04-28-brains-skills-integration-map.md`
**Beads task:** brains-4bw (in_progress)
**Mode:** --single (orchestrator-driven sweep, no star-chamber)

## Review Summary

- Files reviewed: 17 (3 references, 1 AGENTS.md, 5 SKILL.md files, teammate.md, settings-format.md, plan-format.md, README.md, CHANGELOG.md, 6 test scripts + runner, research-summary-schema.md)
- Issues found: P0 = 0; P1 = 7; P2 = 0
- Issues fixed in-place: 7
- Test runner: `bash scripts/test/run-all.sh` → 6/6 PASS

## Coverage Matrix (ADR-005 reqs 1-49)

| Req | Topic | Implementing site | Status |
|---|---|---|---|
| 1 | `--skills` flag accepted by brains/map/implement | `skills/{brains,map,implement}/SKILL.md` argument-hint + step 1 | ✅ |
| 2 | Two-step probe order (tool-name → hotskills.list) | `references/skills-detection.md` §"Two-step probe procedure" | ✅ |
| 3 | Single-line warning on probe failure | `references/skills-detection.md` §"Warning-log contract" | ✅ |
| 4 | Per-session independence | `references/skills-detection.md` §"Per-session independence" | ✅ |
| 5 | Pin hotskills 0.1.4 + document API surface | `references/skills-detection.md:8-11`; `references/find-skills.md:9` | ✅ |
| 6 | Call `hotskills.search({query, limit:10})` | `references/skills-invocation.md:22` | ✅ |
| 7 | Autopilot picks first `gate_status=allow`, no `force_whitelist` | `references/skills-invocation.md:24,26,31` | ✅ (test: autopilot-allow-activation.sh) |
| 8 | Non-autopilot ranked picker | `references/skills-invocation.md:25` | ✅ |
| 9 | Surface gate reason / autopilot logs+skips | `references/skills-invocation.md:24` | ✅ (test: autopilot-no-allow-skip.sh) |
| 10 | Find-skills fallback consults vendored doc | `references/skills-invocation.md:41` | ✅ |
| 11 | Vendored doc with maintenance header | `references/find-skills.md:1-13` | ✅ |
| 12 | `command -v npx` check + clear error | `references/skills-invocation.md:40` | ✅ (test: npx-absent.sh) |
| 13 | `npx skills find <query>` via Bash | `references/skills-invocation.md:42`; `references/find-skills.md:65-67` | ✅ |
| 14 | Autopilot fallback MUST NOT auto-install | `references/skills-invocation.md:46`; `references/find-skills.md:115` | ✅ |
| 15 | defaults.json v0.3.0 schema with `flags` object | `skills/setup/SKILL.md:259-279`; `skills/setup/references/settings-format.md:9-27` | ✅ |
| 16 | Non-destructive merge migration | `skills/setup/SKILL.md:247-281` | ✅ (test: config-migration-v01-to-v03.sh) |
| 17 | Local Flags table writer | `skills/setup/SKILL.md:335-346` | ✅ |
| 18 | Precedence chain CLI > local > global > built-in | `skills/{brains,map,implement}/SKILL.md` step 1; `README.md:78-85` | ✅ |
| 19 | `--no-*` overrides `flags.*: true` | `skills/brains/SKILL.md:46`; `README.md:85` | ✅ (fixed: accept_adrs naming) |
| 20 | Query derivation order | `references/skills-invocation.md:7-16` | ✅ |
| 21 | Master propagates `--skills` as text in teammate prompt | `references/teammate-protocol.md:52`; `skills/implement/SKILL.md:60` | ✅ |
| 22 | Teammate T1 parses + re-probes | `skills/implement/teammate.md:27,29-31` | ✅ |
| 23 | `--grill` MUST NOT propagate | `skills/brains/SKILL.md:58`; `skills/map/SKILL.md:46` (rejected with error) | ✅ |
| 24 | Nurture Step 2 doc bullet | `skills/nurture/SKILL.md:77-80` | ✅ |
| 25 | `P1 \| Missing docs` row | `skills/nurture/SKILL.md:113` | ✅ |
| 26 | Step 5 P1 fix scope extended to docs | `skills/nurture/SKILL.md:138` | ✅ |
| 27 | Teammate T4 doc-update bullet | `skills/implement/teammate.md:90` | ✅ |
| 28 | CHANGELOG file-follow-up clause | `skills/implement/teammate.md:90`; `skills/nurture/SKILL.md:138` | ✅ |
| 29 | Lazy-load find-skills.md under `--lean` | `references/skills-invocation.md:51-58`; `references/skills-detection.md:60-62` | ✅ |
| 30 | 90-day vendored doc refresh policy | `AGENTS.md:11`; `references/find-skills.md:8` | ✅ |
| 31 | Research path = `docs/research/` | `skills/brains/SKILL.md:68`; `README.md:241` | ✅ |
| 32 | Phase-1/2/lean migration to `docs/research/` | `skills/brains/SKILL.md:68,72`; `skills/map/SKILL.md:94` (legacy fallback) | ✅ (fixed nurture stale ref + research-summary-schema legacy-fallback note) |
| 33 | Autopilot still presents ADR gate by default | `skills/brains/SKILL.md:52,167` | ✅ |
| 34 | `--accept-adrs` flag accepted | `skills/brains/SKILL.md:5,37,54` | ✅ (fixed: implement now accepts CLI override on resume) |
| 35 | `Accept-ADRs:` persisted in plan header | `skills/map/SKILL.md:210,236`; `skills/implement/SKILL.md:115` | ✅ |
| 36 | ADR commit lands on topic branch (hoisted) | `skills/brains/SKILL.md:185-198` (sub-step a) | ✅ |
| 37 | Auto-create draft PR after push | `skills/brains/SKILL.md:219-238` (sub-step c) | ✅ |
| 37a | PR draft→ready at wrap-up | `skills/implement/SKILL.md:253-287` (step 7a) | ✅ |
| 37b | Surface ADR + draft-PR links at gate | `skills/brains/SKILL.md:240-265` (sub-step d) | ✅ |
| 37c | Commit+push plan + Plan doc link at map gate | `skills/map/SKILL.md:139-168` (step 7a) | ✅ |
| 38 | `/brains:map` step 3 no-op when phase 1 hoisted branch | `skills/map/SKILL.md:73-74` | ✅ |
| 39 | Grooming CI status check | `skills/implement/teammate.md:40-45` | ✅ |
| 40 | MUST NOT wait for in-flight runs | `skills/implement/teammate.md:61` | ✅ |
| 41 | HEAD~1 dedup + ci-failure ticket | `skills/implement/teammate.md:47-59` | ✅ |
| 42 | Skip silently when gh missing / no GH remote | `skills/implement/teammate.md:40` | ✅ |
| 43 | CI check runs after `groomed` label swap | `skills/implement/teammate.md:38,40` | ✅ |
| 44 | `/brains:map` accepts `--bullets` / `--no-bullets` | `skills/map/SKILL.md:5,44,57-63` | ✅ |
| 45 | Auto-detection (3 conditions) | `skills/map/SKILL.md:109-123` (step 5a) | ✅ |
| 46 | Serial-sweep shape: 3-6 tasks, bullet checklists | `skills/map/SKILL.md:120`; `skills/map/references/plan-format.md:73-77` | ✅ |
| 47 | Gate defaults to inline; grooming risk:high escalates | `skills/map/SKILL.md:178-182`; `references/plan-format.md:80-82` | ✅ |
| 48 | plan-format.md "Serial Sweep Mode" section | `skills/map/references/plan-format.md:59-120` | ✅ |
| 49 | `Bullets:` plan-header field | `skills/map/SKILL.md:212`; `skills/map/references/plan-format.md:14` | ✅ |

All 49 RFC-2119 requirements have a matching code site.

## Issues Fixed (P1)

1. **`skills/brains/SKILL.md:43,46`** — `flags.accept-adrs` (kebab) → `flags.accept_adrs` (underscore) to match the actual JSON schema everywhere else.
2. **`skills/implement/SKILL.md:5`** — `argument-hint` was missing `--accept-adrs` / `--no-accept-adrs`, despite step 2 (line 115) stating CLI override on `--resume` supersedes the persisted value. Added to argument-hint + step 1 parse list.
3. **`skills/implement/SKILL.md:50`** — Step 1 parse list was missing `--accept-adrs`. Added.
4. **`skills/implement/SKILL.md:52`** — Header claimed "4-layer precedence" while listing 5 numbered layers (CLI > plan-header > local > global > built-in). Renamed to "5-layer precedence" with parenthetical clarification.
5. **`skills/map/SKILL.md:202-214` + `:236`** — Plan-header template was missing `**Skills:**` field, but `skills/implement/SKILL.md:117` reads it as a persisted plan-header field per ADR req 21-22. Added Skills row to template + narrative.
6. **`skills/map/references/plan-format.md:13-15` + Header Fields table** — Template and table omitted `Autopilot`, `Accept-ADRs`, `Lean`, `Skills`, `Teammate-model`. Added all five rows so the spec matches what `/brains:map` step 11 actually writes and what `/brains:implement` step 2 reads.
7. **`skills/nurture/SKILL.md:43`** + **`skills/brains/references/research-summary-schema.md:34`** — Two stale `docs/plans/.../research.md` references. Updated to `docs/research/` with legacy-fallback note (matching the pattern in `skills/map/SKILL.md:94`).

## Issues Filed for Cleanup

None — no P2/style items required filing as cleanup tickets.

## Tests

`bash scripts/test/run-all.sh` exits 0 — 6/6 tests pass:

```
PASS: --skills --autopilot allow-activation contract is documented
PASS: --autopilot no-allow-status log+skip path is documented
PASS: defaults.json v0.1.0 -> v0.3.0 non-destructive merge is documented
PASS: hotskills.list() throw handling is documented (try/catch + fallback warning)
PASS: npx-absent error+continue path is documented
PASS: tool-name-absent fallback path is documented
```

All P1 fixes are doc/spec edits in skill bodies; none touch test contracts or behavioral entry points, so no test regression risk.
