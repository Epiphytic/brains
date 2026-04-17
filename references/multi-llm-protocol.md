# Multi-LLM Protocol

Shared protocol for multi-LLM operations across all BRAINS skills. Each skill references this document for mode detection, star-chamber invocation, and result handling.

## Prerequisites

Before any multi-LLM operation, verify star-chamber availability:

```bash
command -v uv >/dev/null 2>&1 && echo "uv:ok" || echo "uv:missing"
CONFIG_PATH="${STAR_CHAMBER_CONFIG:-$HOME/.config/star-chamber/providers.json}"
[[ -f "$CONFIG_PATH" ]] && echo "config:exists:$CONFIG_PATH" || echo "config:missing"
```

**If uv is missing**, stop and show:
```
uv is required for multi-LLM modes.
Install: curl -LsSf https://astral.sh/uv/install.sh | sh
```

**If config is missing**, direct the user to configure providers:
```
Star-chamber provider configuration is required for multi-LLM modes.
Set up: uvx star-chamber list-providers
Config: ~/.config/star-chamber/providers.json
```

If prerequisites fail and the mode is `--single`, proceed without star-chamber. For `--parallel` or `--debate`, stop and show the error.

## Mode Detection

Parse mode from skill arguments:

| Flag | Behavior |
|------|----------|
| `--single` | Local LLM only, no star-chamber |
| `--parallel` | Work locally first, then send to star-chamber for review |
| `--debate` | Multi-round deliberation via star-chamber |
| `--rounds N` | Number of debate rounds (default: 2, requires `--debate`) |

Each skill defines its own default mode. If no mode flag is provided, use the skill's default.

## Single Mode

No star-chamber involvement. The local LLM completes all work independently. Skip the prerequisites check entirely.

## Parallel Mode

1. **Local phase**: Complete the primary work (brainstorming, research, design, etc.)
2. **Prepare context**: Write project context to a temp file
3. **Format review question**: Construct a specific question for the council based on the skill's output
4. **Create temp directory**:
   ```bash
   SC_TMPDIR="$(mktemp -d)"; echo "$SC_TMPDIR"
   ```
5. **Gather context** into `$SC_TMPDIR/context.txt`:
   ```bash
   SC_TMPDIR="<literal path>"; CONTEXT_FILE="$SC_TMPDIR/context.txt"; : > "$CONTEXT_FILE"
   [[ -f ARCHITECTURE.md ]] && cat ARCHITECTURE.md >> "$CONTEXT_FILE"
   ```
6. **Invoke star-chamber**:
   ```bash
   SC_TMPDIR="<literal path>"; uvx star-chamber ask --context-file "$SC_TMPDIR/context.txt" --format json "Review question here"
   ```
   For code-focused reviews (nurture, secure), use `review` instead of `ask`:
   ```bash
   SC_TMPDIR="<literal path>"; uvx star-chamber review --context-file "$SC_TMPDIR/context.txt" --format json file1.py file2.py
   ```
7. **Parse results**: Extract approaches, recommendations, and consensus from JSON
8. **Present council feedback** to the user
9. **Integrate**: Revise work based on council feedback (with user approval)
10. **Clean up**: `rm -rf "$SC_TMPDIR"`

## Debate Mode

Multi-round deliberation where each LLM sees others' anonymized responses between rounds.

### Setup

Create a per-run temp directory with a fixed parent for blanket permission:

```bash
_tmpbase="${TMPDIR:-/tmp}"; SC_PARENT="${_tmpbase%/}/brains-council"; mkdir -p "$SC_PARENT"; chmod 700 "$SC_PARENT"; SC_TMPDIR=$(mktemp -d "$SC_PARENT/run-XXXXXX"); echo "$SC_TMPDIR"
```

Inform the user: _"Debate mode will read and write round results in `<SC_PARENT path>`. Approve access to this directory to avoid repeated prompts."_

### Gather Context

Write project context to `$SC_TMPDIR/context.txt` using the same approach as parallel mode.

### Debate Flow

```
Round 1: uvx star-chamber ask --context-file $SC_TMPDIR/context.txt --format json "question" > $SC_TMPDIR/round-1.json
         |
         Read round-1.json with Read tool, create anonymous synthesis
         |
For each subsequent round (2 to N):
         |
    Write synthesis to $SC_TMPDIR/council-context.txt via Bash heredoc
         |
    uvx star-chamber ask --context-file $SC_TMPDIR/context.txt --council-context $SC_TMPDIR/council-context.txt --format json "question" > $SC_TMPDIR/round-N.json
         |
Final: Read last round's JSON with Read tool, present results
```

For code-focused debate (nurture, secure), substitute `review` for `ask` and pass file paths instead of a question string.

### Anonymous Synthesis

Between rounds, synthesize feedback by content themes WITHOUT attributing to individual providers:

```text
## Council feedback (round N):

**Key points raised:**
- Point 1
- Point 2

**Areas of agreement:**
- Agreement 1

**Areas of disagreement:**
- Disagreement 1

Please provide your perspective on these points. Note where you agree, disagree, or have additional insights.
```

Write via Bash heredoc to the temp directory (not Write tool — avoids permission prompts):

```bash
SC_TMPDIR="<literal path>"; cat > "$SC_TMPDIR/council-context.txt" << 'SYNTHESIS'
<anonymous synthesis content>
SYNTHESIS
```

### Convergence

If responses in round N are substantively identical to round N-1 (providers agree with no new points), stop early. Otherwise complete all requested rounds.

### Error Handling

If a provider fails during a round, continue with remaining providers. Note failed providers in the final output but do not block the debate.

## Result Presentation

### Design Question Results (from `star-chamber ask`)

```markdown
## Council Advisory

**Question:** {prompt}
**Providers:** {providers_used}

### Consensus Recommendation
{consensus_recommendation, if present}

### Approaches Considered
**{name}** — Recommended by {recommended_by} provider(s)
- **Pros:** {pros}
- **Cons:** {cons}
- **Risk:** {risk_level}

### Summary
{summary}
```

### Code Review Results (from `star-chamber review`)

```markdown
## Council Review

**Files:** {files reviewed}
**Providers:** {providers_used}

### Consensus Issues
1. `{location}` **[{severity}]** - {description}
   - **Suggestion:** {suggestion}

### Majority Issues
1. `{location}` **[{severity}]** — flagged by {flagged_by}

### Summary
{summary}
```

If `failed_providers` is non-empty in the JSON, note which providers failed and why.

## Context Gathering

Standard context for star-chamber invocations:

1. **Architecture docs**: Include `ARCHITECTURE.md` if it exists
2. **Project rules**: Include relevant `.claude/rules/*.md` files
3. **Recent changes**: `git diff HEAD~3 --stat` for implementation context
4. **Skill-specific context**: Each skill adds its own (design docs, test results, research findings, etc.)

### Under `--lean`

When the invoking skill was passed `--lean`, scope the context assembly as follows:

- **`star-chamber ask` (design-question) calls:** OMIT `git diff HEAD~3 --stat`. The diff is low-signal noise for design questions where no implementation yet exists.
- **`star-chamber review` (code-review) calls:** RETAIN `git diff HEAD~3 --stat`. The diff is the review subject.
- **Project rules:** include a `.claude/rules/*.md` file ONLY when its frontmatter contains a tag `architectural` or `security-relevant`. Unmarked rules files (CI conventions, commit-message style, etc.) are omitted — they are not relevant to external LLMs evaluating architecture or code.
- **Architecture docs:** unchanged; include `ARCHITECTURE.md` if present.

These scoping rules do not apply under the default (non-lean) path, which preserves v0.2.x context assembly verbatim.

## Runtime Constraints

Inherited from star-chamber:

- Each Bash invocation runs in a separate subprocess — variables do not persist
- Use `;` (not `&&`) to chain variable assignments with subsequent commands
- Avoid pipelines (`|`) when shell variables are involved — use temp files instead
- Use the **Read tool** for cross-invocation file access (reading result JSON)
- Use **Bash** for writing to temp directories (avoids Write tool permission prompts)
- Keep `uvx` commands on a **single line** — no `\` line continuations
- **Never** redirect stderr into output files (no `2>&1`) — uv prints install messages to stderr
