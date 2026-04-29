# Plan: BRAINS `--skills` integration

**Slug:** brains-skills-integration
**ADRs:** docs/adr/2026-04-28-005-brains-skills-integration.md
**Research:** docs/research/2026-04-28-brains-skills-integration-research.md
**Mode:** --parallel
**Autopilot:** true
**Lean:** false
**Teammate-model:** opus
**Branch:** brains/brains-skills-integration

## Overview

Implement ADR-005 in three plan-phases:

1. **Foundation** — vendor `find-skills.md`, bump `defaults.json` schema to v0.3.0 with non-destructive merge migration in `/brains:setup`, add maintenance note to `AGENTS.md`. **Independently testable for the setup/config subsystem**: a v0.1.0 `defaults.json` can be migrated and verified, the local Flags table writer can be exercised, the vendored doc can be spot-checked against upstream SHA. This phase does NOT exercise `--skills` execution paths — those land in phase 2.
2. **Skills plumbing** — add `--skills` / `--no-skills` flag parsing AND `flags.grill` runtime resolution (both booleans share the same v0.3.0 schema and precedence chain), hotskills-detection procedure, and find-skills fallback invocation to `/brains:brains`, `/brains:map`, `/brains:implement` and `teammate.md`. Includes safe `--autopilot` interaction (no `force_whitelist`) and per-session re-probing on the teammate side.
3. **Doc-update strengthening + finalization** — strengthen nurture's review checklist with `P1 Missing docs`, extend Step 5 fix block, add the proactive `T4` doc-update bullet to `teammate.md`. Update `README.md` with new `--skills` flag prose + a new `Configuration` section. Add `CHANGELOG.md`. Land E2E tests for the detection-and-fallback paths.

## Phase 1: Foundation (no orchestration skill changes)

- [ ] **T-1.1**: Vendor find-skills SKILL.md with maintenance header
  - Depends on: none
  - Acceptance: `references/find-skills.md` exists at the BRAINS plugin root, first 20 lines contain a maintenance header documenting (i) source URL, (ii) SHA at vendor time, (iii) refresh policy, (iv) the hotskills MCP API surface this fallback is paired with. Body matches upstream `vercel-labs/skills/main/skills/find-skills/SKILL.md` content.

- [ ] **T-1.2**: Bump `defaults.json` schema to v0.3.0 with `flags` object
  - Depends on: none
  - Acceptance: `skills/setup/references/settings-format.md` documents v0.3.0 schema with `flags: { skills: bool, grill: bool }`. The example JSON block shows `version: "0.3.0"` and a `flags` object. Migration semantics (merge, preserve existing values, only add missing keys) are described in prose.

- [ ] **T-1.3**: Implement merge migration in `/brains:setup --global`
  - Depends on: T-1.2
  - Acceptance: `skills/setup/SKILL.md` step 3 reads any existing `defaults.json`, merges new keys (preserving prior values for `defaults.*`, `debate_rounds`, etc.), bumps `version` to `"0.3.0"`, and writes `flags: { skills: false, grill: false }` only when those keys are absent. Verifiable by inspecting setup SKILL.md procedure; no destructive overwrite path exists.

- [ ] **T-1.4**: Add `Flags` table writer to `/brains:setup --local`
  - Depends on: T-1.2
  - Acceptance: `skills/setup/SKILL.md` step 4 writes a `## Flags` H2 section in `.claude/brains.local.md` with a markdown table for `skills` and `grill` boolean overrides. Documented format explicitly states "missing/empty cell falls through to global default."

- [ ] **T-1.5**: Add vendored-doc maintenance note to `AGENTS.md`
  - Depends on: T-1.1
  - Acceptance: `AGENTS.md` contains a section titled "Vendored documentation maintenance" referencing `references/find-skills.md`, the upstream URL, and a refresh policy ("refresh on every minor BRAINS release; nurture may file a refresh ticket if older than 90 days").

- [ ] **T-1.8**: Migrate research-path convention to `docs/research/`
  - Depends on: none
  - Acceptance: `skills/brains/SKILL.md` step 2 writes new research files to `docs/research/YYYY-MM-DD-<slug>-research.md` (and the lean research-summary stash to `docs/research/YYYY-MM-DD-<slug>-research-summary.yaml`). `skills/map/SKILL.md` step 4 reads research from `docs/research/` first, falling back to `docs/plans/` for legacy files. Existing `docs/plans/*-research.md` files are NOT auto-migrated; new runs use the new path. The phase-1 reuse staleness check (`docs/plans/2026-04-28-brains-skills-integration-research.md` mtime check) is updated to scan `docs/research/`. Verifiable: `grep -n 'docs/plans/.*-research' skills/brains/SKILL.md skills/map/SKILL.md` returns no matches outside legacy-fallback prose.

- [ ] **T-1.6** (Nurture): `Nurture: phase 1`
  - Depends on: T-1.1, T-1.2, T-1.3, T-1.4, T-1.5, T-1.8
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-1-nurture.md` exists with an `Issues Fixed` section. README/CHANGELOG/AGENTS.md mentions of the new vendored doc and config schema are accurate. Tests for migration-merge invariants exist or have been filed as cleanup tickets.

- [ ] **T-1.7** (Secure): `Secure: phase 1`
  - Depends on: T-1.6
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-1-secure.md` exists. Vendored `find-skills.md` is reviewed for embedded scripts; merge migration is reviewed for path traversal / JSON-injection risks; `AGENTS.md` note is reviewed for misleading or unsafe instructions to future agents.

## Phase 2: Skills plumbing (orchestration skill changes)

- [ ] **T-2.1**: Add `--skills` / `--no-skills` parsing AND `flags.grill` resolution to `skills/brains/SKILL.md`
  - Depends on: T-1.2 (schema must exist for config-default resolution)
  - Acceptance: `skills/brains/SKILL.md` step 1 parses `--skills` and `--no-skills`, merges with `defaults.json` `flags.skills` and `.claude/brains.local.md` per the precedence chain in ADR-005 req. 18. Step 1 ALSO resolves `flags.grill` from the same chain (CLI `--grill`/`--no-grill` > local > global > built-in `false`) — both booleans land via the same precedence logic. The argument-hint frontmatter line includes `[--skills|--no-skills] [--no-grill]` (existing `--grill` already documented). Composition rules with `--single`/`--parallel`/`--debate`/`--autopilot`/`--lean`/`--grill` are documented inline.

- [ ] **T-2.2**: Add `--skills` parsing AND `flags.grill` resolution to `skills/map/SKILL.md`
  - Depends on: T-2.1
  - Acceptance: `skills/map/SKILL.md` step 1 parses `--skills`, inherits from phase-1 chained invocation, and writes `Skills: <true|false>` to the plan header in step 11. `flags.grill` resolution is no-op in map (grill is phase-1 only) but the parsing branch consistently rejects `--grill` with a clear error; the precedence resolver is shared and tested. The `Resume` documentation reflects the new persisted `Skills:` field.

- [ ] **T-2.3**: Add `--skills` parsing AND `flags.grill` resolution to `skills/implement/SKILL.md`
  - Depends on: T-2.2
  - Acceptance: `skills/implement/SKILL.md` step 1 parses `--skills`, reads `Skills:` from the plan header on `--resume`, allows CLI override, and includes `--skills` text in the teammate initial prompt per `references/teammate-protocol.md`. `flags.grill` resolution is no-op in implement (same as map) and rejects `--grill` with a clear error.

- [ ] **T-2.4**: Implement hotskills detection procedure as a shared reference
  - Depends on: T-1.1
  - Acceptance: New file `references/skills-detection.md` exists and (i) contains the verbatim string `mcp__plugin_hotskills_hotskills__hotskills_search` in the tool-name presence check section, (ii) describes the `hotskills.list({scope:"merged"})` try/catch with explicit warning-log contract, (iii) documents per-session independence. AT LEAST ONE upstream caller — `skills/brains/SKILL.md`, `skills/map/SKILL.md`, `skills/implement/SKILL.md`, OR `skills/implement/teammate.md` — contains an explicit reference to `references/skills-detection.md` by path. (If no upstream caller cites it, this file is orphaned and the task is NOT done.)

- [ ] **T-2.5**: Implement query-derivation + invocation procedure as a shared reference
  - Depends on: T-2.4
  - Acceptance: New file `references/skills-invocation.md` exists and contains (a) query derivation order per ADR-005 req. 20, (b) the autopilot-vs-interactive `hotskills.search` → `hotskills.activate` → `hotskills.invoke` sequence, (c) the find-skills fallback path with `command -v npx` check + `npx skills find` invocation, (d) the verbatim text `force_whitelist` MUST NOT be passed under `--autopilot`, (e) the rule that `npx skills add` MUST NOT be invoked under `--autopilot`. AT LEAST ONE upstream caller cites this file by path. The shared-reference verification command `grep -l "skills-invocation.md" skills/` returns at least one match.

- [ ] **T-2.6**: Update `skills/implement/teammate.md` T1 to parse `--skills` and re-probe
  - Depends on: T-2.4, T-2.5
  - Acceptance: `teammate.md` T1 parses `--skills` from initial prompt and references `skills-detection.md` + `skills-invocation.md` for behavior. Re-probing per session is explicit. No resolved provider value is consumed from master.

- [ ] **T-2.7**: Update `references/teammate-protocol.md` initial-prompt template
  - Depends on: T-2.3
  - Acceptance: The Teammate Initial Prompt Template explicitly documents `--skills` as a forwarded flag (mirroring `--lean`); `--grill` non-propagation reaffirmed.

- [ ] **T-2.10**: Add `--accept-adrs` flag to `/brains:brains` and propagate via plan header
  - Depends on: T-2.1
  - Acceptance: `skills/brains/SKILL.md` step 1 parses `--accept-adrs`. Step 9 logic: when `--autopilot` is set WITHOUT `--accept-adrs`, present the ADR gate normally and await user input; when `--autopilot --accept-adrs` are both set, auto-select option 2. The argument-hint frontmatter line includes `[--accept-adrs]`. `skills/map/SKILL.md` step 11 plan-header schema adds `Accept-ADRs: <true|false>` field; `skills/implement/SKILL.md` reads it on `--resume` consistently with `Autopilot:`. README "Additional flags" subsection documents `--accept-adrs` (covered by T-3.5 extension).

- [ ] **T-2.11**: Hoist branch-creation + auto-create draft PR in `/brains:brains` step 9
  - Depends on: T-2.10
  - Acceptance: `skills/brains/SKILL.md` step 9 (BEFORE the commit+push subprocess) checks if the user is on a base branch (`main`/`master`/`develop` or any branch in `settings.local.json` `brains.baseBranches`); if so, in interactive mode prompts to create `brains/<slug>` and switch, in `--autopilot` mode auto-creates and switches without prompting. The branch-creation block in `skills/map/SKILL.md` step 3 becomes a no-op fallback that fires only when the current branch is still a base branch (covering standalone `/brains:map` invocation). AFTER the ADR commit+push, IF `command -v gh` succeeds AND `git remote get-url origin` matches `github.com`, the skill auto-runs `gh pr create --draft --title "<ADR title>" --body-file <ADR path>`; suppresses `already exists` errors with a one-line log; surfaces the PR URL. Skipped silently when `gh` missing or no GitHub remote.

- [ ] **T-2.13**: Add `gh pr ready` transition to `/brains:implement` wrap-up
  - Depends on: T-2.11
  - Acceptance: `skills/implement/SKILL.md` step 7 (wrap-up) adds a final block: when wrap-up has `Paused: false` AND no `brains:needs-human` outstanding AND `command -v gh` succeeds AND a PR exists for the current branch (`gh pr view --head $(git branch --show-current) --json number -q .number`), run `gh pr ready <number>`. Failures (already-ready, no PR) logged not blocking. Skipped silently when `gh` missing or no GitHub remote.

- [ ] **T-2.12**: Add CI status check to grooming (T2) in `skills/implement/teammate.md`
  - Depends on: T-2.6 (teammate.md already touched in phase 2)
  - Acceptance: `skills/implement/teammate.md` T2 grooming subagent prompt is extended to include a final post-grooming step: AFTER swapping `brains:ready-for-grooming` for `brains:groomed`, IF `git remote get-url origin` matches `github.com` AND `command -v gh` succeeds, run `gh run list --limit 10 --branch $(git branch --show-current) --json status,conclusion,name,databaseId,createdAt`. For each failed run (`conclusion in [failure, timed_out, action_required, cancelled]`), check whether the same workflow was failing on `git rev-parse HEAD~1`; if NOT pre-existing, file `bd create --title "Investigate CI failure: <workflow>" --type=bug --priority=2 --label brains:topic:<slug> --label brains:phase-<N+1> --label ci-failure` (or `brains:cleanup` if N is the final phase). MUST NOT wait for in-flight runs. MUST NOT block grooming. Skipped silently when `gh` missing or no GitHub remote.

- [ ] **T-2.8** (Nurture): `Nurture: phase 2`
  - Depends on: T-2.1, T-2.2, T-2.3, T-2.4, T-2.5, T-2.6, T-2.7, T-2.10, T-2.11, T-2.12, T-2.13
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-2-nurture.md` exists with `Issues Fixed` section. All argument-hint frontmatter lines updated; README flag list updated for skills plumbing; CHANGELOG entry added.

- [ ] **T-2.9** (Secure): `Secure: phase 2`
  - Depends on: T-2.8
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-2-secure.md` exists. Reviewed: bash invocation of `npx skills find` (command-injection risk on derived query); MCP tool error handling (no leaked stack traces); query derivation (no PII / secrets pulled from prompts).

## Phase 3: Doc-update strengthening + finalization

- [ ] **T-3.1**: Strengthen `nurture` Step 2 completeness checklist
  - Depends on: T-2.9 (phase-2 nurture+secure must finish before mutating the nurture skill itself — otherwise the phase-2 nurture run reads a partially-rewritten reviewer)
  - Acceptance: `skills/nurture/SKILL.md` Step 2 includes a bullet "Are user-facing docs (README, CHANGELOG, ADRs) updated to reflect the changes in this scope?"

- [ ] **T-3.2**: Add `P1 Missing docs` to nurture issue-priority table
  - Depends on: T-3.1
  - Acceptance: `skills/nurture/SKILL.md` issue-priority table contains a row `P1 | Missing docs` at the same tier as `P1 | Missing test`.

- [ ] **T-3.3**: Extend nurture Step 5 P1 fix block
  - Depends on: T-3.2
  - Acceptance: `skills/nurture/SKILL.md` Step 5 P1 description reads "Missing features/tests/docs" and includes README/CHANGELOG updates in the fix scope.

- [ ] **T-3.4**: Add proactive doc-update bullet to `teammate.md` T4
  - Depends on: T-2.6 (teammate file already touched in phase 2)
  - Acceptance: `skills/implement/teammate.md` T4 contains a bullet: "When implementing tasks that change user-facing behavior or add new options, update README and CHANGELOG entries in the SAME commit as the code change. Docs land with the code, not as trailing cleanup. If no `CHANGELOG.md` exists at the repo root, file a `bd create` follow-up task rather than creating one unilaterally."

- [ ] **T-3.5**: Add `--skills` and `--accept-adrs` flag prose to `README.md`
  - Depends on: T-2.1, T-2.10, T-2.11
  - Acceptance: `README.md` "Additional flags" subsection documents `--skills` (orthogonal to mode flags; per-session probing; safe under `--autopilot`) AND `--accept-adrs` (default OFF; `--autopilot` no longer auto-accepts ADRs without it). Examples block adds 2-3 entries showing `--skills` use AND 1-2 entries showing `--autopilot --accept-adrs` for full hands-off. Branch-creation behavior in phase 1 (when on a base branch) is documented under the "Workflow" or "Modes" section.

- [ ] **T-3.6**: Add `Configuration` section to `README.md`
  - Depends on: T-1.2, T-1.3, T-1.4
  - Acceptance: `README.md` contains a new top-level `## Configuration` section documenting (i) `~/.config/brains/defaults.json` schema v0.3.0, (ii) `.claude/brains.local.md` Flags table, (iii) the 4-layer precedence (CLI > local > global > built-in), (iv) examples of enabling `--skills` and `--grill` by default.

- [ ] **T-3.7**: Create / update `CHANGELOG.md`
  - Depends on: T-3.5, T-3.6
  - Acceptance: `CHANGELOG.md` exists at repo root with a v0.5.0 entry describing: `--skills` flag, `--accept-adrs` flag (and the autopilot ADR-gate behavior change), config-default support, nurture doc-update strengthening, research-path migration to `docs/research/`, branch-creation hoisting into phase 1, and CI-status check in grooming. Entry follows Keep-a-Changelog conventions. Breaking-change subsection notes the `--autopilot` semantic change (no longer auto-accepts ADRs without `--accept-adrs`).

- [ ] **T-3.8**: Add E2E coverage for detection-and-fallback paths
  - Depends on: T-2.4, T-2.5
  - Acceptance: Test scripts placed under `scripts/test/` (verify path with `ls scripts/test/` before authoring; if directory doesn't exist, the teammate creates it AND files a `bd create` follow-up to wire it into the project's standard test harness). Tests cover: (i) tool-name absent → fallback fires + `npx skills find` invoked, (ii) `hotskills.list` throws → fallback + warning logged, (iii) `--skills --autopilot` with `gate_status=allow` → activation, no `force_whitelist`, (iv) `--skills --autopilot` with no allow-status → log + skip, (v) `npx` absent → clear error + continue, (vi) config migration v0.1.0 → v0.3.0 preserves prior values. Each test is executable from the repo root and exits 0 on success. The teammate documents the exact invocation command in the test file's header comment.

- [ ] **T-3.9** (Nurture): `Nurture: phase 3`
  - Depends on: T-3.1, T-3.2, T-3.3, T-3.4, T-3.5, T-3.6, T-3.7, T-3.8
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-3-nurture.md` exists with `Issues Fixed` section. Final README/CHANGELOG state is consistent with shipped behavior; all tests pass.

- [ ] **T-3.10** (Secure): `Secure: phase 3`
  - Depends on: T-3.9
  - Acceptance: `docs/plans/2026-04-28-brains-skills-integration-phase-3-secure.md` exists. Reviewed: README examples for misleading flag combinations, CHANGELOG for accidentally leaked secrets, test harness for hardcoded credentials.

- [ ] **T-3.11** (Cleanup): `Cleanup: topic brains-skills-integration`
  - Depends on: T-3.10
  - Acceptance: All `brains:topic:brains-skills-integration` `brains:cleanup`-labeled tasks resolved or filed as standalone follow-ups outside this topic. Final wrap-up document at `docs/plans/2026-04-28-brains-skills-integration-wrap-up.md` summarizes what shipped, what was deferred, and links to follow-up tickets including `brains-b8g` (grill convergence prompt fix).
