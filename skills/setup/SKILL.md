---
name: setup
description: This skill should be used when the user asks to "set up brains", "configure brains", "install brains dependencies", "set up multi-LLM", "configure star-chamber for brains", "change brains defaults", or invokes "/brains:setup". Guides the user through installing dependencies, configuring LLM providers, and setting default modes for each BRAINS skill.
user-invocable: true
argument-hint: "[--global|--local]"
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Setup: Configure BRAINS

Interactive setup wizard that installs dependencies, configures multi-LLM providers, and sets default modes for each BRAINS skill. Supports global (system-wide) and local (project-specific) configuration.

Set the plugin base path:
```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Scope

Parse the `--global` or `--local` flag from arguments. If neither is provided, ask:

> "Should this setup apply globally (all projects) or locally (this project only)?
>
> - **Global** — installs tools, configures star-chamber providers, sets system-wide BRAINS defaults
> - **Local** — creates project-level BRAINS settings, output directories, and gitignore entries
>
> Most users should run global first, then local per-project for overrides."

| Scope | What it does |
|-------|-------------|
| Global | Install uv, configure star-chamber providers, write `~/.config/brains/defaults.json` |
| Local | Create `.claude/brains.local.md`, create `docs/plans/` and `docs/adr/`, update `.gitignore` |

Both scopes can be run — global sets the baseline, local overrides per-project.

## Global Setup

### Step 1: Check and Install Dependencies

Check each prerequisite and offer to install missing ones:

```bash
echo "=== BRAINS Dependency Check ==="
command -v uv >/dev/null 2>&1 && echo "uv: installed" || echo "uv: MISSING (required for multi-LLM)"
command -v node >/dev/null 2>&1 && echo "node: installed" || echo "node: MISSING (optional, for visual companion)"
command -v tmux >/dev/null 2>&1 && echo "tmux: installed" || echo "tmux: MISSING (optional, for implement handoff)"
uvx star-chamber --version 2>/dev/null && echo "star-chamber: installed" || echo "star-chamber: MISSING (required for multi-LLM)"
```

For each missing dependency, present installation options:

**uv (required for multi-LLM modes):**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**star-chamber (required for multi-LLM modes):**
Star-chamber installs automatically on first `uvx star-chamber` invocation. Verify:
```bash
uvx star-chamber list-providers
```

**Node.js (optional — visual companion):**
Do NOT install automatically. Inform the user:
> "Node.js is optional — it powers the visual companion in the storm phase. Install from https://nodejs.org/ if you want browser-based brainstorming."

**tmux (optional — implement handoff):**
Do NOT install automatically. Inform the user:
> "tmux is optional — it lets the implement phase launch a separate Claude Code session in a new pane. Install via your package manager (`apt install tmux`, `brew install tmux`) if you want this feature."

**beads plugin (optional — task management):**
```bash
ls ~/.claude/plugins/*/skills/beads 2>/dev/null || ls ~/.claude/plugins/cache/*/skills/beads 2>/dev/null
```
If not found:
> "The beads plugin is optional — it provides task management for the implement phase. Install it separately if you want cross-session task tracking."

### Step 2: Configure Star-Chamber Providers

Check for existing configuration:
```bash
CONFIG_PATH="${STAR_CHAMBER_CONFIG:-$HOME/.config/star-chamber/providers.json}"
[[ -f "$CONFIG_PATH" ]] && echo "config:exists" || echo "config:missing"
```

**If config exists**, show current providers:
```bash
uvx star-chamber list-providers
```

Ask: "Providers are already configured. Reconfigure, or keep current setup?"

**If config is missing**, present options:

> "Star-chamber needs LLM provider configuration for multi-LLM modes.
>
> How would you like to manage API keys?
>
> 1. **any-llm.ai platform** — single key, centralized management, usage tracking
> 2. **Direct provider keys** — set OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY individually
> 3. **Skip** — configure manually later"

**Option 1 — Platform mode:**
```bash
mkdir -p ~/.config/star-chamber
cat > ~/.config/star-chamber/providers.json << 'CONF'
{
  "platform": "any-llm",
  "timeout_seconds": 60,
  "providers": [
    {"provider": "openai", "model": "gpt-4o"},
    {"provider": "anthropic", "model": "claude-sonnet-4-20250514"},
    {"provider": "google", "model": "gemini-2.5-pro"}
  ]
}
CONF
```

Then show:
> "Set your platform key: `export ANY_LLM_KEY=\"ANY.v1....\"`
> Create an account at https://any-llm.ai if you don't have one."
> If you're using an openai compatible backend like FUELIX, then
> you need to specify the api_base.

**Option 2 — Direct keys:**
```bash
mkdir -p ~/.config/star-chamber
cat > ~/.config/star-chamber/providers.json << 'CONF'
{
  "timeout_seconds": 60,
  "providers": [
    {"provider": "openai",
      "model": "gpt-4o",
      "api_key": "${OPENAI_API_KEY}"
    },
    {"provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "api_key": "${ANTHROPIC_API_KEY}"
    },
    {"provider": "google",
      "model": "gemini-2.5-pro",
      "api_key": "${GEMINI_API_KEY}"
    },
    {
      "provider": "openai",
      "model": "gpt-4o",
      "api_key": "${FUELIX_API_KEY}",
      "api_base": "https://api.fuelix.ai"
    }
  ]
}
CONF
```

Then show:
> "Set your API keys:
> ```
> export OPENAI_API_KEY=\"sk-...\"
> export ANTHROPIC_API_KEY=\"sk-ant-...\"
> export GEMINI_API_KEY=\"...\"
> export FUELIX_API_KEY=\"...\"
> ```
> Remove providers from the config if you don't have keys for them."

Ask the user which providers they want to include. Adjust the config to only include selected providers. Ask about model preferences for each — offer the default but let them change it.

**Option 3 — Skip:**
> "Run `/brains:setup --global` again when you're ready. Multi-LLM modes (`--parallel`, `--debate`) won't work until providers are configured. Single mode (`--single`) works without configuration."

### Step 3: Set Global Default Modes

Present the built-in defaults and let the user customize:

> "Each BRAINS skill has a default mode when no flag is specified.
> Current defaults:"

| Skill | Built-in Default | Your Choice |
|-------|:----------------:|:-----------:|
| storm | parallel | ? |
| research | single | ? |
| architect | single | ? |
| implement | single | ? |
| nurture | single | ? |
| secure | single | ? |

> "Would you like to change any defaults? Enter the skill name and mode (e.g., `research parallel`), or press enter to keep all defaults."

Also ask for default debate rounds:
> "Default debate rounds (currently 2):"

Write the global defaults:
```bash
mkdir -p ~/.config/brains
```

Write `~/.config/brains/defaults.json` using the Write tool:

```json
{
  "version": "0.1.0",
  "defaults": {
    "storm": "parallel",
    "research": "single",
    "architect": "single",
    "implement": "single",
    "nurture": "single",
    "secure": "single"
  },
  "debate_rounds": 2
}
```

### Step 4: Verify

Run a quick verification:
```bash
echo "=== BRAINS Setup Verification ==="
command -v uv >/dev/null 2>&1 && echo "PASS: uv" || echo "FAIL: uv"
uvx star-chamber list-providers 2>/dev/null && echo "PASS: star-chamber" || echo "WARN: star-chamber (multi-LLM unavailable)"
[[ -f ~/.config/brains/defaults.json ]] && echo "PASS: global defaults" || echo "FAIL: global defaults"
echo "=== Done ==="
```

## Local Setup

### Step 1: Check Global Prerequisites

Verify global setup has been run:
```bash
command -v uv >/dev/null 2>&1 && echo "uv:ok" || echo "uv:missing"
[[ -f ~/.config/brains/defaults.json ]] && echo "globals:ok" || echo "globals:missing"
```

If global setup hasn't been run, suggest it:
> "Global setup hasn't been run yet. Run `/brains:setup --global` first to install dependencies and configure providers, then `/brains:setup --local` for project-specific settings."

Proceed with local setup regardless — it's still useful for project-level overrides.

### Step 2: Create Output Directories

```bash
mkdir -p docs/plans docs/adr
```

### Step 3: Configure Project Defaults

Read global defaults as a starting point:
```bash
[[ -f ~/.config/brains/defaults.json ]] && cat ~/.config/brains/defaults.json
```

Ask the user if they want project-specific overrides:

> "Project-level settings override global defaults for this repo.
> Global defaults are: [show current globals]
>
> Want to customize any modes for this project, or use global defaults?"

### Step 4: Write Local Settings

Create `.claude/brains.local.md` — this file is auto-loaded by Claude Code as project context, so all BRAINS skills will see these settings automatically.

Read the reference at `$BRAINS_PATH/skills/setup/references/settings-format.md` for the exact format to write.

### Step 5: Update .gitignore

Ensure `.claude/brains.local.md` is gitignored (it may contain user-specific preferences):

```bash
grep -q 'brains.local.md' .gitignore 2>/dev/null || echo '.claude/brains.local.md' >> .gitignore
```

### Step 6: Verify

```bash
echo "=== Local Setup Verification ==="
[[ -d docs/plans ]] && echo "PASS: docs/plans/" || echo "FAIL: docs/plans/"
[[ -d docs/adr ]] && echo "PASS: docs/adr/" || echo "FAIL: docs/adr/"
[[ -f .claude/brains.local.md ]] && echo "PASS: local settings" || echo "FAIL: local settings"
grep -q 'brains.local.md' .gitignore 2>/dev/null && echo "PASS: gitignore" || echo "WARN: gitignore"
echo "=== Done ==="
```

## Reconfiguration

The setup skill can be re-run at any time to change settings:

- `/brains:setup --global` — reconfigure providers, change global defaults
- `/brains:setup --local` — change project-level overrides

Existing settings are read and presented as current values. Only changed values are updated.

## Additional Resources

- **`references/settings-format.md`** — detailed settings file format and examples
