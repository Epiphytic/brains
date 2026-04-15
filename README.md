# BRAINS

**B**rainstorm **R**esearch **A**rchitect **I**mplement **N**urture **S**ecure

![BRAINS: Agentic Coding Lifecycle](assets/brains-lifecycle.jpeg)

A structured, multi-LLM development workflow plugin for Claude Code. Guides complex tasks through a three-phase pipeline, with optional multi-model debate and review at each stage.

## How It Works

BRAINS encodes a three-phase methodology for tackling complex software tasks:

1. **brains** — Phase 1: interactive research, question-driven questionnaire, and RFC 2119 ADR production. Default mode: `--parallel` with star-chamber review.
2. **map** — Phase 2: high-level plan generation (stub-level, not implementation-specific), with beads-based task tracking using `brains:`-prefixed labels.
3. **implement** — Phase 3: launches a fresh Claude Code teammate per plan-phase via agent-teams (preferred) or tmux. Each teammate grooms its tasks, executes them with fresh subagents, then runs nurture and secure reviews.

Each phase chains into the next via a user-approval gate. The `nurture` and `secure` skills remain user-invocable for standalone use on any codebase.

## Prerequisites

**Required:**
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — the plugin host

**Required for multi-LLM modes (parallel, debate):**
- [uv](https://docs.astral.sh/uv/) — Python package manager
- [star-chamber](https://pypi.org/project/star-chamber/) — multi-LLM council (PyPI, invoked via `uvx star-chamber`)
- Provider configuration at `~/.config/star-chamber/providers.json`

**Required for phase 3 (`/brains:implement`):** either
- [tmux](https://github.com/tmux/tmux) installed, OR
- Claude Code agent-teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings; Claude Code v2.1.32+)

**Strongly recommended:**
- [beads](https://github.com/anthropics/claude-code) plugin — authoritative task tracker. Falls back to `TaskCreate` / `TaskUpdate` (tmux mode) or agent-teams' built-in task list (agent-teams mode) with degraded functionality.

**Optional:**
- [Node.js](https://nodejs.org/) — for the visual companion browser tool in phase 1

## Installation

```bash
# Load directly
claude --plugin-dir /path/to/brains

# Or add to a project's plugin config
echo '{ "plugins": ["/path/to/brains"] }' > .claude/plugins.json
```

After installing, run `/brains:setup --global` to install dependencies and configure LLM providers, then `/brains:setup --local` in each project for project-specific settings.

## Skills

| Skill | Command | Default Mode | Description |
|-------|---------|:---:|-------------|
| setup | `/brains:setup` | — | Install dependencies, configure LLM providers, set defaults |
| suggest | *(auto)* | — | Detects complex tasks and recommends BRAINS |
| brains | `/brains:brains` | parallel | Phase 1: research + questionnaire + ADR |
| map | `/brains:map` | parallel | Phase 2: high-level plan + beads tasks |
| implement | `/brains:implement` | parallel | Phase 3: teammate-per-plan-phase execution |
| nurture | `/brains:nurture` | single | Review and refine (standalone or subagent) |
| secure | `/brains:secure` | single | Security review (standalone or subagent) |

## Modes

Most skills support three modes for LLM involvement:

| Mode | Flag | Behavior |
|------|------|----------|
| Single | `--single` | Local LLM only, no star-chamber |
| Parallel | `--parallel` | Work locally, then send to council for review |
| Debate | `--debate` | Multi-round deliberation across LLMs |

Additional flag: `--rounds N` sets the number of debate rounds (default: 2, requires `--debate`).

```bash
# Examples
/brains:brains "design a caching layer"                       # Uses default (parallel)
/brains:brains --single "design a caching layer"              # Local only
/brains:brains --debate --rounds 3 "design a caching layer"   # 3-round debate
/brains:map --parallel                                         # Phase 2 with parallel review
/brains:implement --parallel                                   # Phase 3 with parallel review
```

## Phase Outputs

| Phase | Output File | Additional |
|-------|-------------|------------|
| brains | `docs/plans/YYYY-MM-DD-<slug>-research.md` | ADRs in `docs/adr/` |
| map | `docs/plans/YYYY-MM-DD-<slug>-map.md` | beads tasks with `brains:` labels |
| implement | `docs/plans/YYYY-MM-DD-<slug>-phase-N-nurture.md`, `-phase-N-secure.md` per plan-phase | `docs/plans/<slug>-wrap-up.md` (or `-paused.md`) |

## Plugin Structure

```
brains/
├── .claude-plugin/plugin.json
├── skills/
│   ├── setup/
│   ├── suggest/
│   ├── brains/            (phase 1)
│   │   ├── references/
│   │   │   └── visual-companion.md
│   │   └── scripts/       (visual companion server)
│   ├── map/               (phase 2)
│   │   └── references/plan-format.md
│   ├── implement/         (phase 3)
│   ├── nurture/
│   └── secure/
├── references/
│   ├── multi-llm-protocol.md
│   ├── teammate-protocol.md
│   ├── beads-integration.md
│   └── failure-recovery.md
├── docs/
│   ├── testing-humans.md
│   ├── testing-llm.md
│   └── plans/
├── LICENSE
└── README.md
```

## Testing

- **Humans**: See [docs/testing-humans.md](docs/testing-humans.md) for a manual walkthrough
- **LLMs**: See [docs/testing-llm.md](docs/testing-llm.md) for a structured test protocol with pass/fail criteria

## License

[MIT](LICENSE)
