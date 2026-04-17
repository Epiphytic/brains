# Multi-LLM Protocol — Compact (--lean mode)

Compact reference for `--parallel` / `--debate` invocations under `--lean`. For debate-round synthesis edge cases, error handling details, or unusual prerequisite failures, read the full `references/multi-llm-protocol.md`.

## Prerequisites (short form)

```bash
command -v uv >/dev/null 2>&1 && echo "uv:ok" || echo "uv:missing"
CONFIG_PATH="${STAR_CHAMBER_CONFIG:-$HOME/.config/star-chamber/providers.json}"
[[ -f "$CONFIG_PATH" ]] && echo "config:exists:$CONFIG_PATH" || echo "config:missing"
```

If `uv` is missing: install via `curl -LsSf https://astral.sh/uv/install.sh | sh`. If config is missing: `uvx star-chamber list-providers`. For `--single`, proceed without star-chamber; for `--parallel`/`--debate`, stop and report.

## Mode matrix

| Flag | Behavior |
|------|----------|
| `--single` | Local only; no star-chamber |
| `--parallel` | Local phase, then star-chamber review |
| `--debate` | Multi-round deliberation (read full file for synthesis details) |
| `--rounds N` | Debate rounds (default 2) |

## Parallel-mode flow (happy path)

```bash
SC_TMPDIR="$(mktemp -d)"; echo "$SC_TMPDIR"
# Build context.txt (see Context-gathering below), then:
uvx star-chamber ask --context-file "$SC_TMPDIR/context.txt" --format json "Review question"
# For code reviews, substitute: review --context-file ... file1 file2
# Read the JSON with Read tool; parse approaches/consensus/summary
rm -rf "$SC_TMPDIR"
```

## Context-gathering (scoped under --lean)

- Architectural context: `ARCHITECTURE.md` if present.
- Project rules: only `.claude/rules/*.md` files whose frontmatter marks them `architectural` or `security-relevant`.
- Recent changes: include `git diff HEAD~3 --stat` ONLY for `star-chamber review` (code) calls. OMIT for `star-chamber ask` (design-question) calls.
- Skill-specific payload (research summary, ADR draft, plan, changed file list).

## Runtime constraints (inherited)

- Each Bash invocation is a separate subprocess; chain assignments with `;` not `&&`.
- Avoid pipelines with shell variables — use temp files.
- Read tool for cross-invocation JSON access.
- Bash for writing to temp dirs (avoids Write tool permission prompts).
- `uvx` commands single-line (no `\` continuations).
- Never redirect stderr into output files (no `2>&1`).

## When to fall back to the full file

Read `$BRAINS_PATH/references/multi-llm-protocol.md` when:
- Running debate mode and need the round-synthesis format.
- A provider fails mid-debate and error-handling guidance is needed.
- Result-presentation format for non-standard call types.
