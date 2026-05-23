# Changelog

All notable changes to the BRAINS plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2026-05-23

### Added

- **Document mode** — an abbreviated, document-only fast path for changes that only edit prose (markdown and friends, not code). Introduced as a new user-invocable skill `/brains:document` (`skills/document/SKILL.md`). The spine is: eligibility gate → lightweight research → full 2–4 question questionnaire → slim ADR → inline document edits → direct council review → inline commit. It skips `/brains:map`, teammate orchestration, `/brains:nurture`, and `/brains:secure`, **reviewing the final document(s) directly with the star-chamber council** (`uvx star-chamber review` on the document paths, in full; under `--single` it degrades to a lower-assurance local self-review). The slim ADR retains Context, Decision, Requirements (RFC 2119), and Consequences and omits Assumed Versions and Diagram; the questionnaire is not shortened. Document mode owns its own atomic `docs:`-prefixed commit and `.gitignore` updates via the shared commit procedure that nurture also cites.
- `--document-mode` / `--no-document-mode` flag for `/brains:brains`. At the top of phase 1, `/brains:brains` runs an eligibility probe and **delegates** to `/brains:document` (forwarding the mode, `--autopilot`, and `--lean`) when EITHER `--document-mode` resolves true OR the change is auto-detected as document-only AND eligible; it does not continue its own pipeline afterward. The flag does not propagate to `/brains:map` or `/brains:implement`. Resolved via the same 4-layer precedence chain as `--skills` (`flags.document_mode` in `~/.config/brains/defaults.json`, default `false`).
- Hybrid eligibility detection: deterministic bash classifies and counts the canonical changed file set (unstaged ∪ staged ∪ untracked-not-ignored) against a versioned document allow-list (`.md`, `.markdown`, `.mdx`, `.rst`, `.txt`, `.adoc`); the main LLM resolves in-scope documents from the prompt for greenfield work. Eligibility ceiling: ≤ 4 target documents, with zero non-document files. Over-ceiling behavior is mode-sensitive — warn-and-ask interactively, detect-then-fallback with a loud notice under `--autopilot`. Manual `--document-mode` override is asymmetric: oversized-but-document-only scopes warn-and-confirm, but actual code **files** hard-refuse (fenced/example code inside a document never triggers refusal).
- `flags.document_mode` boolean (default `false`) in `~/.config/brains/defaults.json`, documented in `skills/setup/references/settings-format.md`, written by `/brains:setup`, and representable as a row in the `.claude/brains.local.md` Flags table.
- `manifests/document.md` (role `document`) declaring the document skill, its references, and ADR-006 with `whole-always`; `document` added to `ALLOWED_ROLES` in `scripts/manifest-lint.sh`.

### Changed

- `/brains:suggest` refines its "Documentation updates" heuristic to point users toward `/brains:document` for document-only work.
- `references/multi-llm-protocol.md` documents the document-review variant of `star-chamber review` (final documents reviewed in full).

## [0.5.0] - 2026-04-28

### Breaking Changes

- `--autopilot` no longer auto-accepts ADRs at the phase-1 gate by default. ADRs encode architectural commitments too consequential to skip blindly, so human-in-the-loop is preserved on those even under autopilot. To restore the previous full hands-off behavior (autopilot + auto-accept ADRs), use `--autopilot --accept-adrs`. The plan gate (`/brains:map` step 7) and per-phase implementation gates remain skipped under bare `--autopilot` as before.

### Added

- `--skills` / `--no-skills` flag for `/brains:brains`, `/brains:map`, and `/brains:implement`. Probes for the [hotskills](https://github.com/anthropics/hotskills) MCP server (preferred) and falls back to the vendored `references/find-skills.md` (`npx skills find …`) when hotskills is unavailable. Composes safely with `--autopilot` — `force_whitelist` is never passed, and `npx skills add` is never invoked under autopilot.
- `--accept-adrs` / `--no-accept-adrs` flag for `/brains:brains`. Gates the autopilot ADR auto-accept; default `false`. Persisted in the plan header as `Accept-ADRs:` so `/brains:implement --resume` honors the setting.
- `--bullets` / `--no-bullets` flag for `/brains:map`. Switches to "serial sweep mode": a single plan-phase with 3–6 coarse beads tasks (markdown bullet checklist bodies) executed inline in the orchestrator session. Useful for changes that have many tasks but zero parallelism need. Auto-detected when the ADR introduces no new external deps/services, all work is topologically serial, and no `risk:high` markers or architectural unknowns surface from grooming. Persisted in the plan header as `Bullets:`.
- Auto-create draft PR after the phase-1 ADR push, when `gh` is on PATH and the origin remote is GitHub. Surfaces the PR URL at the gate; suppresses duplicate-PR errors with a one-line note; skipped silently when prerequisites are absent.
- Auto-transition the draft PR to ready at `/brains:implement` wrap-up on success (all plan-phases closed, no outstanding `brains:needs-human`, `Paused: false` in wrap-up). Skipped silently when `gh` is missing, no GitHub remote, or no PR exists for the current branch.
- ADR + draft-PR + plan-doc clickable GitHub URLs surfaced at the user gates (phase-1 ADR gate and phase-2 plan gate, plus any out-of-band plan-review request). URL format: `https://<host>/<owner>/<repo>/blob/<branch>/<path>`. Skipped silently when no GitHub remote exists.
- GitHub Actions CI status check at the END of grooming (T2 in `teammate.md`). Read-only `gh run list` against the current branch; for each new failure (one not present on `HEAD~1`), files a `bd create --type=bug --priority=2` task labelled `ci-failure` plus the topic and next-phase (or `brains:cleanup`) labels. Pre-existing failures and in-flight runs are ignored. Never blocks grooming completion. Skipped silently when `gh` is missing or no GitHub remote exists.
- `flags` object in `~/.config/brains/defaults.json` (schema v0.3.0) — per-flag boolean defaults for `skills`, `grill`, `bullets`, `accept_adrs`. Missing keys default to `false`.
- `## Flags` table in `.claude/brains.local.md` for project-level boolean overrides. Empty rows fall through to the global default.
- Vendored `references/find-skills.md` (a copy of `find-skills` v1.5.x from `vercel-labs/skills`, with a maintenance header documenting source URL, vendor SHA, refresh policy, and paired hotskills MCP API version) for offline fallback when hotskills is unavailable.

### Changed

- Research documents are now written to `docs/research/YYYY-MM-DD-<slug>-research.md` (was `docs/plans/`). `docs/plans/` is reserved for in-flight planning artifacts (map, phase reports, wrap-up, paused state); `docs/research/` is the immutable archive of phase-1 exploration. Pre-v0.5 ADRs that reference research under `docs/plans/` continue to resolve via a legacy fallback. Existing research documents are NOT migrated automatically.
- Branch creation is hoisted from `/brains:map` step 3 into `/brains:brains` step 9, so newly authored ADRs land on a topic branch reviewable as a PR. `/brains:map` step 3 becomes a no-op when phase 1 already moved the user to a topic branch (the common case under the new flow); it still applies in the standalone `/brains:map` invocation path.
- `~/.config/brains/defaults.json` schema bumped from v0.2.0 to v0.3.0. `/brains:setup --global` performs a non-destructive merge: existing user values for `version`, `defaults`, `debate_rounds` are preserved; the `flags` object is added with all keys defaulting to `false` only if absent; missing individual flag keys are added without overwriting existing ones; `version` is bumped to `"0.3.0"`. No fields are removed.
- `nurture` skill adds a `P1 | Missing docs` priority row alongside missing tests, plus a "Documentation" subsection in the Step-2 completeness review checklist. The Step-5 fix block extends the P1 description from "Missing features/tests" to "Missing features/tests/docs" and includes README/CHANGELOG updates in the fix scope.
- `teammate.md` T4 block now requires proactive README/CHANGELOG updates in the SAME commit as the code change when implementing tasks that change user-facing behavior or add new options. Docs land with the code, not as trailing cleanup. When no `CHANGELOG.md` exists at the repo root, the teammate files a `bd create` follow-up task instead of creating one unilaterally.

[0.6.0]: https://github.com/Epiphytic/brains/releases/tag/v0.6.0
[0.5.0]: https://github.com/Epiphytic/brains/releases/tag/v0.5.0
