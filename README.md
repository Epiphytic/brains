# BRAINS

**B**rainstorm **R**esearch **A**rchitect **I**mplement **N**urture **S**ecure

![BRAINS: Agentic Coding Lifecycle](assets/brains-lifecycle.jpeg)

A structured, multi-LLM development workflow plugin for Claude Code. Guides complex tasks through six disciplined phases, with optional multi-model debate and review at each stage.

## How It Works

BRAINS encodes a six-phase methodology for tackling complex software tasks:

1. **Storm** -- Brainstorm ideas into designs through collaborative dialogue, optionally amplified by a multi-LLM council
2. **Research** -- Investigate the codebase, dependencies, documentation, and prior art
3. **Architect** -- Make architectural decisions, record ADRs, produce technical designs
4. **Implement** -- Create a detailed plan, then hand off execution to a fresh Claude Code instance via tmux
5. **Nurture** -- Review the implementation for bugs, missing features, and test gaps, then fix them
6. **Secure** -- Security review covering OWASP Top 10, secrets scanning, dependency auditing, and threat modeling

Each phase can be invoked independently or chained together with `/brains:brains` for the full pipeline.

## Prerequisites

**Required:**
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) -- the plugin host

**Required for multi-LLM modes (parallel, debate):**
- [uv](https://docs.astral.sh/uv/) -- Python package manager
- [star-chamber](https://pypi.org/project/star-chamber/) -- multi-LLM council (PyPI package, invoked via `uvx star-chamber`)
- Provider configuration at `~/.config/star-chamber/providers.json`

**Optional:**
- [beads](https://github.com/anthropics/claude-code) plugin -- for task management in the implement phase (falls back to TaskCreate/TaskUpdate)
- [tmux](https://github.com/tmux/tmux) -- for launching the implementation session in a separate pane
- [Node.js](https://nodejs.org/) -- for the visual companion browser tool in the storm phase

## Installation

**From GitHub:**

```bash
# 1. Register the marketplace (one-time)
claude plugin marketplace add --github Epiphytic/brains

# 2. Install the plugin
claude plugin install brains@brains-marketplace
```

**From a local clone:**

```bash
# 1. Register the marketplace (one-time)
claude plugin marketplace add /path/to/brains

# 2. Install the plugin
claude plugin install brains@brains-marketplace
```

After installing, run `/brains:setup --global` to install dependencies and configure LLM providers, then `/brains:setup --local` in each project for project-specific settings.

## Skills

| Skill | Command | Default Mode | Description |
|-------|---------|:------------:|-------------|
| setup | `/brains:setup` | -- | Install dependencies, configure LLM providers, set defaults |
| suggest | *(auto)* | -- | Detects complex tasks and recommends BRAINS |
| storm | `/brains:storm` | parallel | Multi-LLM brainstorming with visual companion |
| research | `/brains:research` | single | Codebase, dependency, and documentation investigation |
| architect | `/brains:architect` | single | Design plans, ADRs, architectural decisions |
| implement | `/brains:implement` | single | Plan and execute in a separate Claude Code instance |
| nurture | `/brains:nurture` | single | Review, test, and refine the implementation |
| secure | `/brains:secure` | single | Security review and vulnerability assessment |
| brains | `/brains:brains` | *(per-phase)* | Full pipeline: all six phases in succession |

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
/brains:storm "design a caching layer"              # Uses default (parallel)
/brains:storm --single "design a caching layer"      # Local only
/brains:storm --debate --rounds 3 "design a caching layer"  # 3-round debate
/brains:brains --parallel "build a REST API"         # All phases use parallel
```

## Phase Outputs

Each phase writes its output to `docs/plans/`:

| Phase | Output File | Additional |
|-------|-------------|------------|
| Storm | `YYYY-MM-DD-<topic>-storm.md` | |
| Research | `YYYY-MM-DD-<topic>-research.md` | |
| Architect | `YYYY-MM-DD-<topic>-architect.md` | ADRs in `docs/adr/` |
| Implement | `YYYY-MM-DD-<topic>-implement.md` | |
| Nurture | `YYYY-MM-DD-<topic>-nurture.md` | |
| Secure | `YYYY-MM-DD-<topic>-secure.md` | |

## Plugin Structure

```
brains/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── skills/
│   ├── setup/
│   │   ├── SKILL.md             # Setup wizard
│   │   └── references/
│   │       └── settings-format.md
│   ├── suggest/SKILL.md         # Auto-triggered complexity detection
│   ├── storm/
│   │   ├── SKILL.md             # Brainstorming skill
│   │   ├── references/
│   │   │   └── visual-companion.md
│   │   └── scripts/             # Visual companion server
│   ├── research/SKILL.md
│   ├── architect/SKILL.md
│   ├── implement/SKILL.md
│   ├── nurture/SKILL.md
│   ├── secure/SKILL.md
│   └── brains/SKILL.md          # Full pipeline orchestrator
├── references/
│   └── multi-llm-protocol.md   # Shared multi-LLM invocation protocol
├── docs/
│   ├── testing-humans.md        # Manual testing guide
│   └── testing-llm.md          # LLM testing protocol
├── LICENSE
└── README.md
```

## Testing

- **Humans**: See [docs/testing-humans.md](docs/testing-humans.md) for a manual walkthrough
- **LLMs**: See [docs/testing-llm.md](docs/testing-llm.md) for a structured test protocol with pass/fail criteria

## License

[MIT](LICENSE)
