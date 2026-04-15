# Plan Document Format

The canonical plan document structure produced by `/brains:map`. The plan document is the tracker — it is overwritten every time phase 2 runs. ADRs, research notes, and per-phase reports are archival by contrast and must not be overwritten.

## Template

```markdown
# Plan: <topic>

**Slug:** <topic-slug>
**ADRs:** <list of paths, comma-separated>
**Research:** <research doc path>
**Mode:** <--single | --parallel | --debate>   <!-- persisted for --resume -->
**Branch:** <branch name>

## Overview
<one-paragraph summary of what this plan accomplishes>

## Tasks (if ≤12) / Phases (if >12)

### Phase 1: <theme>
- [ ] **T-1.1**: <title>
  - Depends on: <none | T-X.Y, ...>
  - Acceptance: <one-line verifiable check>
- [ ] **T-1.2**: ...

### Phase 2: <theme>
...
```

## Header Fields

| Field | Purpose | Read by |
|---|---|---|
| Slug | Topic identifier used in task labels (brains:topic:<slug>) | /brains:map, /brains:implement, all teammates |
| ADRs | Immutable source of architectural truth | All phases |
| Research | Snapshot of codebase/ecosystem understanding | /brains:map (for re-exploration decision), teammates (grooming input) |
| Mode | Default mode for /brains:implement --resume | /brains:implement |
| Branch | Branch the tasks were created on | /brains:implement (sanity check) |

## Task ID Format

`T-<phase>.<index>` — e.g., `T-3.2` is the second task in plan-phase 3. Indexes start at 1.

## Acceptance Criteria

Each task acceptance criterion MUST be a single line, verifiable by reading either a file, a command output, or a test result. Avoid vague criteria like "works well" or "is clean."

Good: *"docs/plans/<slug>-phase-2-nurture.md exists and contains a section titled 'Issues Fixed'."*

Bad: *"nurture phase is complete."*

## Plan-Phase Boundaries

Each plan-phase is independently testable — the end of plan-phase N produces a working, verifiable state. This is critical because the teammate for phase N runs nurture and secure at the end of its work; if plan-phase N's output isn't testable, nurture can't do its job.
