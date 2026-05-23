# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Vendored documentation maintenance

This plugin vendors external instruction documents under `references/` so the BRAINS skills can fall back to a local copy when the external source is unavailable. Vendored docs MUST be refreshed periodically from upstream.

| File | Upstream | Refresh policy |
|---|---|---|
| `references/find-skills.md` | `https://raw.githubusercontent.com/vercel-labs/skills/main/skills/find-skills/SKILL.md` | Auto-refreshed weekly by `.github/workflows/refresh-vendored-find-skills.yml` (opens a PR when upstream SHA drifts). Manual refresh SHOULD also happen on each BRAINS minor release; nurture MAY file `brains:nurture:vendored-docs-refresh` ticket if older than 90 days. |

**Automated refresh:** The weekly workflow at `.github/workflows/refresh-vendored-find-skills.yml` runs every Monday 09:00 UTC (and on `workflow_dispatch`). It compares the vendored `Vendor SHA` against the latest upstream commit on `vercel-labs/skills`'s `skills/find-skills/SKILL.md`; on drift it rebuilds the file and opens a PR labelled `vendored-refresh` for review.

**Manual refresh procedure** (if running locally):
1. `curl -sSL <upstream URL> > /tmp/find-skills-upstream.md`
2. Get current SHA: `curl -sSL "https://api.github.com/repos/<owner>/<repo>/commits?path=<file>&per_page=1" | jq -r '.[0].sha'`
3. Replace the body of the vendored file (everything after the maintenance header `---` separator) with the upstream content.
4. Update the maintenance header: `Vendor SHA`, `Vendor date`.
5. Commit with `docs(refs): refresh vendored find-skills.md`.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work atomically
bd close <id>         # Complete work
bd dolt push          # Push beads data to remote
```

## Non-Interactive Shell Commands

**ALWAYS use non-interactive flags** with file operations to avoid hanging on confirmation prompts.

Shell commands like `cp`, `mv`, and `rm` may be aliased to include `-i` (interactive) mode on some systems, causing the agent to hang indefinitely waiting for y/n input.

**Use these forms instead:**
```bash
# Force overwrite without prompting
cp -f source dest           # NOT: cp source dest
mv -f source dest           # NOT: mv source dest
rm -f file                  # NOT: rm file

# For recursive operations
rm -rf directory            # NOT: rm -r directory
cp -rf source dest          # NOT: cp -r source dest
```

**Other commands that may prompt:**
- `scp` - use `-o BatchMode=yes` for non-interactive
- `ssh` - use `-o BatchMode=yes` to fail instead of prompting
- `apt-get` - use `-y` flag
- `brew` - use `HOMEBREW_NO_AUTO_UPDATE=1` env var

## Releasing a new version

The plugin version lives in **two** files that MUST be bumped together — they drift easily:

1. `.claude-plugin/plugin.json` → `version`
2. `.claude-plugin/marketplace.json` → `plugins[0].version` (this is the version the Claude Code marketplace lists/installs)

> ⚠️ `marketplace.json` historically lagged at `0.1.0` while `plugin.json` advanced through 0.2–0.5. Always confirm BOTH read the same version before tagging. A quick check:
> ```bash
> grep '"version"' .claude-plugin/plugin.json
> grep -A2 '"name": "brains"' .claude-plugin/marketplace.json | grep version
> ```

**Release steps** (run from `main` after the feature PR is merged and CI is green):

```bash
# 1. Both version fields agree (see above); CHANGELOG has a [X.Y.Z] section + release-link line.
# 2. Verify the tree:
bash scripts/manifest-lint.sh            # MUST be OK
# 3. Annotated tag on the merge commit, then push it:
git tag -a vX.Y.Z -m "vX.Y.Z — <headline>"
git push origin vX.Y.Z
# 4. GitHub release (title matches prior releases: "vX.Y.Z — <headline>"):
gh release create vX.Y.Z --title "vX.Y.Z — <headline>" --notes "<summary, link the ADR + CHANGELOG>"
```

The CHANGELOG uses Keep-a-Changelog format with a `[X.Y.Z]:` release-link line at the bottom pointing at `releases/tag/vX.Y.Z`. (A CI check that fails when the two version fields disagree would prevent the recurring drift, if added later.)

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
