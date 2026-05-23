# BRAINS Document Mode — Phase 2 Secure Report

**Scope:** plan-phase 2. Light secrets / unsafe-shell scan over the phase-2 diff.
**Branch:** `brains/brains-document-mode`.

This phase edits only markdown skill/reference/manifest files plus one shell-script
allow-list addition. No application code, no network calls, no credential handling
were introduced.

## Secrets scan

Scanned the phase-2 diff for `api_key` / `secret` / `password` / `token` /
`BEGIN ... PRIVATE` patterns.

- **No hard-coded secrets.** The only matches are:
  - Documentation prose in `references/commit-procedure.md` (phase-1 artifact) listing
    secret-config filename patterns (`.env*`, `credentials.json`, `settings.local.json`)
    to add to `.gitignore` — guidance, not a secret.
  - Placeholder env-var interpolations in `skills/setup/SKILL.md`
    (`${OPENAI_API_KEY}`, `${ANTHROPIC_API_KEY}`, `${GEMINI_API_KEY}`,
    `${FUELIX_API_KEY}`) — these are unchanged pre-existing provider-config templates,
    not literal keys.

## Unsafe-shell scan

Scanned added lines for `eval`, bare `rm -rf /`, and `curl … | sh` patterns.

- **None introduced** in phase-2 changes.
- The `scripts/manifest-lint.sh` edits add two static array/list entries (`document` to
  `ALLOWED_ROLES` and a `check_skill_refs` call) — no new command execution, no user
  input flowing into a shell.
- The new `manifests/document.md` `Live context` entry (`git status --porcelain`) is a
  read-only git command.

## Out-of-repo state

Per task constraint, the live `~/.config/brains/defaults.json` (machine state) was NOT
modified — only the in-repo skill/docs that describe and generate it.

## Result

No security findings. Phase-2 surface is documentation + a static allow-list addition.
