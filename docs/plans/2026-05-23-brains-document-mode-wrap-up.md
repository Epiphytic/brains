# Wrap-up: BRAINS document mode

**Slug:** brains-document-mode
**Paused:** true

## Status

Phases 1 (ADR) and 2 (plan + tasks) complete and pushed. **Phase 3 (implementation) paused before any teammate spawn**, by user choice: this session is not inside a tmux session and agent-teams is disabled, so the documented `tmux split-window` teammate spawn mechanism is unavailable here.

## Completed

- **ADR-006** — `docs/adr/2026-05-23-006-brains-document-mode.md` (accepted; committed + pushed; draft PR #5).
- **Research** — `docs/research/2026-05-23-brains-document-mode-research.md`.
- **Plan** — `docs/plans/2026-05-23-brains-document-mode-map.md` (12 implementation tasks across 3 plan-phases; committed + pushed).
- **Task graph** — 12 implementation + 3 nurture + 3 secure + 1 cleanup tasks created in the harness task list (beads not installed; session-bound). The plan document is the authoritative source for re-deriving phases on resume.

## Outstanding Work (not started)

- **Phase 1:** T-1.1 eligibility-detection reference, T-1.2 shared commit procedure, T-1.3 slim-adr-template, T-1.4 `skills/document/SKILL.md`, T-1.5 lint invariant.
- **Phase 2:** T-2.1 `/brains:brains` `--document-mode` + delegation guard, T-2.2 suggest pointer + multi-llm note, T-2.3 `flags.document_mode` config, T-2.4 `manifests/document.md` + `ALLOWED_ROLES`.
- **Phase 3:** T-3.1 README, T-3.2 CHANGELOG + version bump to 0.6.0, T-3.3 final lint.
- Per-phase nurture + secure, and final cleanup.

## How to Resume

Run implementation from an environment that supports the spawn backend:

- **Inside a tmux session:** `tmux new -s brains` then `/brains:implement --resume --autopilot --teammate-model opus`, OR
- **Enable agent-teams:** set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (Claude Code v2.1.32+), then `/brains:implement --resume --autopilot --teammate-model opus`.

`--resume` reads the plan header (mode `--parallel`, autopilot `true`, teammate-model `opus`) and re-derives the open phases from the committed plan document.

## Known Gaps and Limitations

- Beads is not installed; cross-session task recovery is degraded. The committed plan document is authoritative for resume.
- Draft PR #5 remains in **draft** (not transitioned to ready — phase 3 did not complete).
