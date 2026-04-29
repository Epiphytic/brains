---
name: setup
description: This skill should be used when the user asks to "set up brains", "configure brains", "install brains dependencies", "set up multi-LLM", "configure star-chamber for brains", "change brains defaults", "set up kroki", "enable diagram rendering", or invokes "/brains:setup". Guides the user through installing dependencies, configuring LLM providers, setting default modes for each BRAINS skill, and optionally starting a local Kroki container for diagram rendering.
user-invocable: true
argument-hint: "[--global|--local] [--with-kroki [--port N]] [--without-kroki]"
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Setup: Configure BRAINS

Interactive setup wizard that installs dependencies, configures multi-LLM providers, and sets default modes for each BRAINS skill. Supports global (system-wide) and local (project-specific) configuration.

An optional Kroki step (`--with-kroki`) pulls and runs the `yuzutech/kroki` container locally via podman or docker, making it the primary diagram renderer. This means `brains:diagram` renders SVGs locally without sending source to any external service — `mmdc` remains the fallback. Undo with `--without-kroki`. The `--kroki-cloud` opt-in for the public kroki.io service is a separate per-invocation flag on `brains:diagram` and is never an automatic fallback.

Set the plugin base path:
```bash
BRAINS_PATH="<base directory from header>/../.."
```

## Scope

The `--with-kroki` and `--without-kroki` flags are orthogonal to `--global`/`--local` — they may be run independently (e.g., `/brains:setup --with-kroki` without any global/local flag) or combined in one invocation (e.g., `/brains:setup --global --with-kroki`). When combined, run global/local setup first, then the Kroki step. **If only `--with-kroki` or `--without-kroki` is present (no `--global`/`--local`), skip the global/local scope prompt and go directly to the Kroki section.**

Parse the `--global` or `--local` flag from arguments. If neither is provided AND no Kroki flag was given, ask:

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

## Version Floor Checks

The setup skill validates minimum tool versions at install time. Pinned floors:

| Tool | Floor | Command | Remedy if missing |
|---|---|---|---|
| Claude Code | 2.1.109 | `claude --version` | https://docs.anthropic.com/en/docs/claude-code |
| uv | 0.1.0 | `uv --version` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| beads (optional but recommended) | 0.63.3 | `bd --version` | https://github.com/anthropics/claude-code (beads plugin) |
| tmux (required unless agent-teams enabled) | any | `tmux -V` | `apt/brew/pkg install tmux` |

At implementation time, replace `<VERSION>` with the version installed on the developer's machine (run the command, read the output). Pin it literally.

If any required tool is missing or below the floor, stop setup and emit the remedy. Record the detected versions to `~/.claude/plugins/state/brains/setup-log.json` for audit.

## Teammate Spawn Mode Detection

Phase 3 requires either Claude Code agent-teams enabled or tmux installed. Setup checks both:

```bash
# Agent-teams check
if [[ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}" == "1" ]]; then
  echo "agent-teams: enabled"
else
  echo "agent-teams: disabled (set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings to enable)"
fi

# tmux check
command -v tmux >/dev/null 2>&1 && echo "tmux: available" || echo "tmux: missing"
```

If neither is available, advise the user to enable one before running `/brains:implement`. `/brains:brains` and `/brains:map` work without either.

## Beads Initialization

If beads is installed but the current repository hasn't been initialized, setup initializes it on the user's behalf:

```bash
if command -v bd >/dev/null 2>&1; then
  if ! bd status >/dev/null 2>&1; then
    bd init --local
    echo "Initialized beads for this repository (local mode)."
  fi
fi
```

This matches the behavior of `/brains:map` — if the user skips setup entirely, phase 2 will initialize beads on first run.

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
> "Node.js is optional — it powers the visual companion in phase 1 (`/brains:brains`). Install from https://nodejs.org/ if you want browser-based brainstorming."

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
      "model": "gemini-3.1-pro",
      "api_key": "${GEMINI_API_KEY}"
    },
    {
      "provider": "openai",
      "model": "gpt-5.4",
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
| brains | parallel | ? |
| map | parallel | ? |
| implement | parallel | ? |
| nurture | single | ? |
| secure | single | ? |

> "Would you like to change any defaults? Enter the skill name and mode (e.g., `map parallel`), or press enter to keep all defaults."

Also ask for default debate rounds:
> "Default debate rounds (currently 2):"

Write the global defaults:
```bash
mkdir -p ~/.config/brains
```

**Migration logic (non-destructive merge):**
1. If `~/.config/brains/defaults.json` does NOT exist, write the full v0.3.0 default below.
2. If it exists, read it via the Read tool and parse the JSON.
3. Build the merged result starting from the existing object:
   - Set `version` to `"0.3.0"`.
   - Preserve all existing `defaults.*` keys; add any missing skill keys with their built-in defaults (`brains: "parallel"`, `map: "parallel"`, `implement: "parallel"`, `nurture: "single"`, `secure: "single"`).
   - Preserve `debate_rounds` if present; default to `2` if absent.
   - If `flags` is missing entirely, add `{ "skills": false, "grill": false, "bullets": false, "accept_adrs": false }`.
   - If `flags` exists, add only the missing keys (do NOT overwrite existing values for keys already set).
   - Preserve any unknown top-level keys verbatim (forward-compat).
4. Write the merged result back via the Write tool. NEVER overwrite without merging.

The full v0.3.0 default (used when no prior file exists):

```json
{
  "version": "0.3.0",
  "defaults": {
    "brains": "parallel",
    "map": "parallel",
    "implement": "parallel",
    "nurture": "single",
    "secure": "single"
  },
  "debate_rounds": 2,
  "flags": {
    "skills": false,
    "grill": false,
    "bullets": false,
    "accept_adrs": false
  }
}
```

After the write, surface a one-line note: `"defaults.json migrated to v0.3.0 (preserved your existing values)"` if the prior file existed; `"defaults.json initialized at v0.3.0"` if it did not.

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

The local settings body MUST include a `## Flags` section with a markdown table for boolean per-project overrides. Empty/missing rows fall through to the global default in `~/.config/brains/defaults.json` `flags`.

```markdown
## Flags

| Flag | Project Default | Notes |
|---|:---:|---|
| `skills` |   | Enable skill discovery in brains/map/implement (CLI: `--skills` / `--no-skills`) |
| `grill` |   | Enable relentless-interview questionnaire in `/brains:brains` phase 1 (CLI: `--grill` / `--no-grill`) |
| `bullets` |   | Default `/brains:map` to serial-sweep mode (CLI: `--bullets` / `--no-bullets`) |
| `accept_adrs` |   | Auto-accept ADRs under `--autopilot` (CLI: `--accept-adrs` / `--no-accept-adrs`) |
```

Leave the "Project Default" cells empty for skills the project does not override; users fill in `true` or `false` to opt in/out per project.

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

## Kroki Container Setup

### `--with-kroki [--port N]`

Starts two local containers that work together: the Kroki gateway (`yuzutech/kroki`) and the Mermaid companion (`yuzutech/kroki-mermaid`). `brains:diagram` uses this pair as the primary renderer for all types — Mermaid (`flowchart`, `state`) is rendered by the companion; Structurizr DSL (`c4`) is rendered by PlantUML/Structurizr code bundled inside the gateway itself, so no separate Structurizr companion is required. `mmdc` remains a secondary fallback for Mermaid types only. No diagram source is sent to external services.

**Runtime detection:** `command -v podman` first; if absent, `command -v docker`. If neither is found, print an error to stderr and exit non-zero. Do NOT touch `~/.config/brains/renderer.json`.

**Network:** Both containers must share a user-defined network so the gateway can reach the companion by name. Create `brains-kroki-net` (idempotent — `<runtime> network create brains-kroki-net 2>/dev/null || true`).

**Idempotency:** Run `<runtime> ps --all` and check for two container names: `brains-kroki` (gateway) and `brains-kroki-mermaid` (companion). Treat them as a pair — if either is missing/stopped or the gateway's published port doesn't match the requested `--port`, stop/remove both and recreate the pair. Inspect the gateway port via `.NetworkSettings.Ports["8000/tcp"][0].HostPort` (more reliable across rootless modes than `.HostConfig.PortBindings`); if inspect returns empty, treat the port as unknown and recreate.

**Pull and run:** Parse `--port N` from arguments (default `8000`). **Validate PORT before use:** it must be a positive integer in the range 1–65535 (digits only, no shell metacharacters). If invalid, print an error and exit non-zero without touching containers or `renderer.json`.

Pull both images:
- `<runtime> pull yuzutech/kroki:latest`
- `<runtime> pull yuzutech/kroki-mermaid:latest`

Run the companion first (the gateway depends on it at resolve time):
- `<runtime> run -d --name brains-kroki-mermaid --network brains-kroki-net --restart=unless-stopped yuzutech/kroki-mermaid:latest`

Run the gateway, bound only to the loopback interface, and point it at the companion by name:
- `<runtime> run -d --name brains-kroki --network brains-kroki-net -e KROKI_MERMAID_HOST=brains-kroki-mermaid -p 127.0.0.1:<PORT>:8000 --restart=unless-stopped yuzutech/kroki:latest`

Bind to `127.0.0.1` explicitly so Kroki is only reachable on the local loopback interface, not exposed to the network. The companion is reachable only through the internal `brains-kroki-net` network and is never published to the host. `--restart=unless-stopped` is identical for both podman and docker.

**Write `~/.config/brains/renderer.json` atomically** — replace the file entirely with exactly these fields (no merge, no extra fields). Use Bash to write atomically: write to `~/.config/brains/renderer.json.tmp` first, then rename it into place with `mv ~/.config/brains/renderer.json.tmp ~/.config/brains/renderer.json`. Ensure `~/.config/brains/` exists first (`mkdir -p ~/.config/brains`).

```json
{
  "kroki_url": "http://localhost:<PORT>",
  "kroki_runtime": "podman",
  "kroki_started_at": "2026-04-23T14:30:00Z",
  "kroki_network": "brains-kroki-net",
  "kroki_companion": "brains-kroki-mermaid"
}
```

Substitute the actual PORT, RUNTIME (`podman` or `docker`), and current UTC timestamp in ISO-8601 format. The `kroki_network` and `kroki_companion` fields let `--without-kroki` clean up deterministically.

**Verify:**
- `<runtime> ps --filter name=brains-kroki` shows both `brains-kroki` and `brains-kroki-mermaid` running.
- `~/.config/brains/renderer.json` exists.
- Smoke-test both source languages:
  - `printf 'flowchart TD\nA-->B' | curl -sf -X POST -H 'Content-Type: text/plain' --data-binary @- http://localhost:<PORT>/mermaid/svg | head -c 5` prints `<svg` or `<?xml` / `<?pla`.
  - `printf 'workspace { model { s = softwareSystem "x" } views { systemContext s { include *; autoLayout } theme default } }' | curl -sf -X POST -H 'Content-Type: text/plain' --data-binary @- http://localhost:<PORT>/structurizr/svg | head -c 5` likewise.

### `--without-kroki`

No-op (exit 0) if `~/.config/brains/renderer.json` does not exist or contains no `kroki_*` keys.

Otherwise:
1. Read `kroki_runtime` from `renderer.json`. If missing or not `podman`/`docker`, probe both `podman` and `docker` for `brains-kroki` and `brains-kroki-mermaid`. If found in either runtime, clean up in that runtime.
2. Stop and remove both containers in order (ignore errors if already gone): `<runtime> stop brains-kroki brains-kroki-mermaid; <runtime> rm brains-kroki brains-kroki-mermaid`.
3. Remove the user-defined network (ignore errors): `<runtime> network rm brains-kroki-net`.
4. Remove all `kroki_*` keys (`kroki_url`, `kroki_runtime`, `kroki_started_at`, `kroki_network`, `kroki_companion`) from `renderer.json` using the Read and Write tools — do not shell out to `jq`. If no keys remain, delete the file using Bash (`rm -f ~/.config/brains/renderer.json`).
5. Verify: neither `podman` nor `docker` lists `brains-kroki` or `brains-kroki-mermaid`; `renderer.json` does not exist or contains no `kroki_url` key.

## Reconfiguration

The setup skill can be re-run at any time to change settings:

- `/brains:setup --global` — reconfigure providers, change global defaults
- `/brains:setup --local` — change project-level overrides
- `/brains:setup --with-kroki [--port N]` — start or restart local Kroki container
- `/brains:setup --without-kroki` — stop and remove local Kroki container

Existing settings are read and presented as current values. Only changed values are updated.

## Additional Resources

- **`references/settings-format.md`** — detailed settings file format and examples
