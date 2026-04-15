# Settings File Formats

## Global Defaults (`~/.config/brains/defaults.json`)

JSON file read by skills at invocation time via the Read tool. Contains system-wide defaults.

```json
{
  "version": "0.2.0",
  "defaults": {
    "brains": "parallel",
    "map": "parallel",
    "implement": "parallel",
    "nurture": "single",
    "secure": "single"
  },
  "debate_rounds": 2
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Plugin version this config was created with |
| `defaults` | object | Default mode per skill (`single`, `parallel`, or `debate`) |
| `debate_rounds` | number | Default number of debate rounds when `--rounds` is not specified |

### How Skills Use Global Defaults

When a skill is invoked without an explicit `--single`, `--parallel`, or `--debate` flag:

1. Check for local settings (`.claude/brains.local.md`) — auto-loaded by Claude Code
2. If no local override, read `~/.config/brains/defaults.json` via Read tool
3. If no global defaults, use the skill's built-in default

## Local Settings (`.claude/brains.local.md`)

Markdown file with YAML frontmatter, auto-loaded by Claude Code as project context. All BRAINS skills see these settings without needing to read the file explicitly.

```markdown
---
type: settings
plugin: brains
---

# BRAINS Plugin Settings

These settings are automatically loaded by Claude Code and apply to all BRAINS skills in this project. They override global defaults from `~/.config/brains/defaults.json`.

## Default Modes

When a BRAINS skill is invoked without an explicit mode flag, use these defaults:

| Skill | Default Mode |
|-------|:------------:|
| brains | parallel |
| map | parallel |
| implement | debate |
| nurture | parallel |
| secure | debate |

## Debate Rounds

Default number of debate rounds: 3

## Star-Chamber Providers

Override provider selection for this project (leave blank to use all configured providers):

Providers: openai, anthropic

## Notes

- These settings are gitignored by default (user-specific preferences)
- Override any setting by passing explicit flags: `/brains:brains --single` always wins
- Re-run `/brains:setup --local` to change these settings
```

### Why Markdown?

The local settings file uses markdown (not JSON) because Claude Code auto-loads `.claude/*.local.md` files as project context. This means:

- Skills do NOT need to explicitly read the file — it's already in context
- Settings are human-readable and editable with any text editor
- YAML frontmatter enables structured metadata if needed later
- The markdown body serves as both documentation and configuration

### Precedence Order

Settings are resolved in this order (highest priority first):

1. **Explicit flags** — `/brains:brains --debate` always wins
2. **Local settings** — `.claude/brains.local.md` (auto-loaded by Claude Code)
3. **Global defaults** — `~/.config/brains/defaults.json` (read by skills via Read tool)
4. **Built-in defaults** — hardcoded in each SKILL.md

### Creating Local Settings

The setup skill generates this file. To create manually:

```bash
mkdir -p .claude
cat > .claude/brains.local.md << 'EOF'
---
type: settings
plugin: brains
---

# BRAINS Plugin Settings

## Default Modes

| Skill | Default Mode |
|-------|:------------:|
| brains | parallel |
| map | parallel |
| implement | parallel |
| nurture | single |
| secure | single |

## Debate Rounds

Default number of debate rounds: 2
EOF
```

Then ensure it's gitignored:
```bash
echo '.claude/brains.local.md' >> .gitignore
```

## BRAINS Runtime Settings

All BRAINS runtime settings live under the `brains` key in `settings.local.json`. Example:

```json
{
  "brains": {
    "baseBranches": ["main", "master", "develop"],
    "pollingIntervalSeconds": 15,
    "teammateIdleTimeoutSeconds": 3600,
    "userResponseTimeoutSeconds": 14400,
    "researchStalenessSeconds": 3600,
    "completionMarkerDir": "docs/plans/.state"
  }
}
```

### Fields

| Key | Default | Purpose |
|---|---|---|
| `baseBranches` | `["main", "master", "develop"]` | Triggers phase 2's branch-creation offer when the user is on one of these |
| `pollingIntervalSeconds` | `15` | How often master polls beads state and completion markers |
| `teammateIdleTimeoutSeconds` | `3600` (1h) | Treat a teammate as crashed if no beads state change or marker update after this long |
| `userResponseTimeoutSeconds` | `14400` (4h) | Pause the run and write paused.md if the user doesn't answer a needs-human questionnaire |
| `researchStalenessSeconds` | `3600` (1h) | Phase 2 re-explores the codebase if the research document is older than this (or if any commits landed since) |
| `completionMarkerDir` | `docs/plans/.state` | Where teammates write completion markers. Must be in `.gitignore`. |
